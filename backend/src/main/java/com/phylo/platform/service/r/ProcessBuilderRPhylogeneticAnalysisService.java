package com.phylo.platform.service.r;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.phylo.platform.config.PhyloRProperties;
import com.phylo.platform.dto.RAnalysisResponse;
import com.phylo.platform.dto.RAnalysisResultJson;

/**
 * ProcessBuilder 调用：
 * {@code Rscript runners/run_analysis.R --type … --fasta … [--metadata …] --output …}
 * <p>
 * 工作目录固定为 {@code phylo.r.root}（r-analysis 根），不依赖调用方 cwd。
 */
@Service
public class ProcessBuilderRPhylogeneticAnalysisService implements RPhylogeneticAnalysisService {

	private static final Logger log = LoggerFactory.getLogger(ProcessBuilderRPhylogeneticAnalysisService.class);

	private final PhyloRProperties rProperties;
	private final ObjectMapper objectMapper;

	public ProcessBuilderRPhylogeneticAnalysisService(PhyloRProperties rProperties, ObjectMapper objectMapper) {
		this.rProperties = rProperties;
		this.objectMapper = objectMapper;
	}

	@Override
	public RAnalysisResponse analyze(String organismType, Path fastaPath, Path metadataPath, Path outputDir) {
		String type = organismType == null || organismType.isBlank() ? "virus" : organismType.trim();
		Path fasta = fastaPath == null ? null : fastaPath.toAbsolutePath().normalize();
		Path metadata = metadataPath == null ? null : metadataPath.toAbsolutePath().normalize();
		Path out = outputDir == null ? null : outputDir.toAbsolutePath().normalize();
		Path root = rProperties.rootPath();
		Path script = rProperties.scriptPath();

		if (fasta == null) {
			return RAnalysisResponse.error(type, "INVALID_REQUEST", "fastaPath 不能为空");
		}
		if (out == null) {
			return RAnalysisResponse.error(type, "INVALID_REQUEST", "outputDir 不能为空");
		}
		if (!Files.isRegularFile(fasta)) {
			return RAnalysisResponse.error(type, "EMPTY_FASTA", "FASTA 不存在: " + fasta);
		}
		if (metadata != null && !Files.isRegularFile(metadata)) {
			return RAnalysisResponse.error(type, "METADATA_FILE_NOT_FOUND", "metadata 不存在: " + metadata);
		}
		if (!Files.isDirectory(root)) {
			return RAnalysisResponse.error(type, "BOOT_PROCESS_FAILED", "r-analysis 根目录不存在: " + root);
		}
		if (!Files.isRegularFile(script)) {
			return RAnalysisResponse.error(type, "BOOT_PROCESS_FAILED",
					"R Framework 入口不存在: " + script + "（请检查 phylo.r.root / phylo.r.script）");
		}

		try {
			Files.createDirectories(out);
		} catch (IOException e) {
			return RAnalysisResponse.error(type, "BOOT_PROCESS_FAILED", "无法创建输出目录: " + out);
		}

		List<String> command = buildCommand(type, fasta, metadata, out, script);
		log.info("启动 R Framework: cwd={} cmd={}", root, command);

		String stdout;
		String stderr;
		int exitCode;
		try {
			ProcessBuilder pb = new ProcessBuilder(command);
			pb.directory(root.toFile());
			pb.redirectErrorStream(false);

			Process process = pb.start();
			StreamGobbler outGobbler = new StreamGobbler(process.getInputStream());
			StreamGobbler errGobbler = new StreamGobbler(process.getErrorStream());
			Thread outThread = new Thread(outGobbler, "rscript-stdout");
			Thread errThread = new Thread(errGobbler, "rscript-stderr");
			outThread.start();
			errThread.start();

			boolean finished = process.waitFor(rProperties.getTimeoutSeconds(), TimeUnit.SECONDS);
			if (!finished) {
				process.destroyForcibly();
				outThread.join(2000);
				errThread.join(2000);
				writeProcessLogs(out, outGobbler.getText(), errGobbler.getText());
				return RAnalysisResponse.error(type, "BOOT_TIMEOUT",
						"Rscript 超时（>" + rProperties.getTimeoutSeconds() + "s）");
			}
			outThread.join();
			errThread.join();
			exitCode = process.exitValue();
			stdout = outGobbler.getText();
			stderr = errGobbler.getText();
		} catch (IOException e) {
			return RAnalysisResponse.error(type, "BOOT_PROCESS_FAILED",
					"无法启动 Rscript（请检查 phylo.r.rscript）: " + e.getMessage());
		} catch (InterruptedException e) {
			Thread.currentThread().interrupt();
			return RAnalysisResponse.error(type, "BOOT_PROCESS_FAILED", "等待 Rscript 时被中断");
		}

		writeProcessLogs(out, stdout, stderr);
		log.info("Rscript exitCode={}", exitCode);
		if (!stdout.isBlank()) {
			log.info("Rscript stdout:\n{}", stdout);
		}
		if (!stderr.isBlank()) {
			log.warn("Rscript stderr:\n{}", stderr);
		}

		Path resultJson = out.resolve("analysis_result.json");
		if (!Files.isRegularFile(resultJson)) {
			if (exitCode == 2) {
				return RAnalysisResponse.notImplemented(type, "UNSUPPORTED_ORGANISM",
						"R 未写出 analysis_result.json（exitCode=2）。stderr=" + truncate(stderr, 2000));
			}
			return RAnalysisResponse.error(type, "BOOT_RESULT_MISSING",
					"R 未写出 analysis_result.json（exitCode=" + exitCode + "）。stderr=" + truncate(stderr, 2000));
		}

		RAnalysisResultJson parsed;
		try {
			parsed = objectMapper.readValue(resultJson.toFile(), RAnalysisResultJson.class);
		} catch (IOException e) {
			return RAnalysisResponse.error(type, "BOOT_RESULT_MISSING",
					"无法解析 analysis_result.json: " + resultJson + " — " + e.getMessage());
		}

		return toResponse(type, out, exitCode, parsed, stderr);
	}

	private List<String> buildCommand(String type, Path fasta, Path metadata, Path out, Path script) {
		List<String> command = new ArrayList<>();
		command.add(rProperties.getRscript());
		// cwd = r-analysis 根时使用相对入口；绝对配置则原样传入
		Path configured = Path.of(rProperties.getScript());
		command.add(configured.isAbsolute() ? script.toString() : rProperties.getScript().replace('\\', '/'));
		command.add("--type");
		command.add(type);
		command.add("--fasta");
		command.add(fasta.toString());
		if (metadata != null) {
			command.add("--metadata");
			command.add(metadata.toString());
		}
		command.add("--output");
		command.add(out.toString());
		return command;
	}

	private RAnalysisResponse toResponse(
			String requestedType,
			Path out,
			int exitCode,
			RAnalysisResultJson parsed,
			String stderr
	) {
		String status = parsed.status() == null ? "" : parsed.status().trim();
		String organismType = parsed.organismType() == null || parsed.organismType().isBlank()
				? requestedType
				: parsed.organismType();
		String treeName = parsed.resolveTree();
		String vizName = parsed.resolveVisualization();
		Map<String, Object> statistics = parsed.resolveStatistics();
		Integer sequenceCount = parsed.resolveSequenceCount();
		String method = parsed.resolveMethod();
		String model = parsed.resolveModel();
		String errorMessage = parsed.errorMessage() == null ? "" : parsed.errorMessage();
		String errorCode = parsed.errorCode() == null ? "" : parsed.errorCode();

		Path treeAbs = treeName.isBlank() ? out.resolve("tree.nwk") : out.resolve(treeName);
		Path imageAbs = vizName.isBlank() ? out.resolve("tree.png") : out.resolve(vizName);

		if (exitCode == 0 && ("success".equalsIgnoreCase(status) || "partial".equalsIgnoreCase(status))) {
			return new RAnalysisResponse(
					status.toLowerCase(),
					organismType,
					nullToEmpty(parsed.input()),
					treeName,
					vizName,
					nullToEmpty(parsed.metadata()),
					statistics,
					"",
					"",
					treeAbs.toAbsolutePath().normalize().toString(),
					imageAbs.toAbsolutePath().normalize().toString(),
					sequenceCount,
					method,
					model
			);
		}

		if (exitCode == 2 || "not_implemented".equalsIgnoreCase(status)) {
			if (errorCode.isBlank()) {
				errorCode = "UNSUPPORTED_ORGANISM";
			}
			if (errorMessage.isBlank()) {
				errorMessage = "organism not implemented: " + organismType;
			}
			return new RAnalysisResponse(
					"not_implemented",
					organismType,
					nullToEmpty(parsed.input()),
					treeName,
					vizName,
					nullToEmpty(parsed.metadata()),
					statistics == null ? Collections.emptyMap() : statistics,
					errorMessage,
					errorCode,
					treeAbs.toAbsolutePath().normalize().toString(),
					imageAbs.toAbsolutePath().normalize().toString(),
					sequenceCount,
					method,
					model
			);
		}

		// exit 1 or unexpected status → business error
		if (errorCode.isBlank()) {
			errorCode = exitCode == 1 ? "TREE_BUILD_FAILED" : "BOOT_PROCESS_FAILED";
		}
		if (errorMessage.isBlank()) {
			errorMessage = "R 分析失败: status=" + status + ", exitCode=" + exitCode
					+ (stderr == null || stderr.isBlank() ? "" : ", stderr=" + truncate(stderr, 1000));
		}
		return new RAnalysisResponse(
				"error",
				organismType,
				nullToEmpty(parsed.input()),
				treeName,
				vizName,
				nullToEmpty(parsed.metadata()),
				statistics == null ? Collections.emptyMap() : statistics,
				errorMessage,
				errorCode,
				treeAbs.toAbsolutePath().normalize().toString(),
				imageAbs.toAbsolutePath().normalize().toString(),
				sequenceCount,
				method,
				model
		);
	}

	private void writeProcessLogs(Path out, String stdout, String stderr) {
		try {
			Files.writeString(out.resolve("run.log"), stdout == null ? "" : stdout, StandardCharsets.UTF_8);
			Files.writeString(out.resolve("run.err"), stderr == null ? "" : stderr, StandardCharsets.UTF_8);
		} catch (IOException e) {
			log.warn("无法写入 run.log/run.err: {}", e.getMessage());
		}
	}

	private static String nullToEmpty(String value) {
		return value == null ? "" : value;
	}

	private static String truncate(String text, int max) {
		if (text == null) {
			return "";
		}
		if (text.length() <= max) {
			return text;
		}
		return text.substring(0, max) + "...";
	}

	private static final class StreamGobbler implements Runnable {
		private final InputStream inputStream;
		private final StringBuilder buffer = new StringBuilder();

		StreamGobbler(InputStream inputStream) {
			this.inputStream = inputStream;
		}

		@Override
		public void run() {
			try (BufferedReader reader = new BufferedReader(
					new InputStreamReader(inputStream, StandardCharsets.UTF_8))) {
				String line;
				while ((line = reader.readLine()) != null) {
					synchronized (buffer) {
						buffer.append(line).append('\n');
					}
				}
			} catch (IOException ignored) {
				// process ended
			}
		}

		String getText() {
			synchronized (buffer) {
				return buffer.toString();
			}
		}
	}
}
