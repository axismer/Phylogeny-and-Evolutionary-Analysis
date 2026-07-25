package com.phylo.platform.service.task;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.FileAlreadyExistsException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.phylo.platform.config.PhyloRProperties;
import com.phylo.platform.dto.AnalysisTaskResponse;
import com.phylo.platform.dto.RAnalysisResponse;
import com.phylo.platform.dto.RAnalysisResultJson;
import com.phylo.platform.service.r.RPhylogeneticAnalysisService;

/**
 * 同步任务服务：UUID 目录隔离 + 固定文件名落盘 + 委托 {@link RPhylogeneticAnalysisService}。
 */
@Service
public class DefaultAnalysisTaskService implements AnalysisTaskService {

	private static final Logger log = LoggerFactory.getLogger(DefaultAnalysisTaskService.class);

	private final PhyloRProperties rProperties;
	private final RPhylogeneticAnalysisService rAnalysisService;
	private final ObjectMapper objectMapper;

	public DefaultAnalysisTaskService(
			PhyloRProperties rProperties,
			RPhylogeneticAnalysisService rAnalysisService,
			ObjectMapper objectMapper
	) {
		this.rProperties = rProperties;
		this.rAnalysisService = rAnalysisService;
		this.objectMapper = objectMapper;
	}

	@Override
	public AnalysisTaskResponse createAndRun(String organismType, MultipartFile fasta, MultipartFile metadata) {
		String type = organismType == null ? "" : organismType.trim();
		if (type.isBlank()) {
			return AnalysisTaskResponse.error("", "", "INVALID_REQUEST", "type（organismType）不能为空");
		}

		AnalysisTaskResponse fastaCheck = validateFastaUpload(fasta);
		if (fastaCheck != null) {
			return fastaCheck;
		}
		AnalysisTaskResponse metaCheck = validateMetadataUpload(metadata);
		if (metaCheck != null) {
			return metaCheck;
		}

		String taskId = TaskPathSecurity.newTaskId();
		Path inputRoot = inputTasksRoot();
		Path outputRoot = outputTasksRoot();
		Path inputDir = TaskPathSecurity.resolveTaskDir(inputRoot, taskId);
		Path outputDir = TaskPathSecurity.resolveTaskDir(outputRoot, taskId);
		if (inputDir == null || outputDir == null) {
			return AnalysisTaskResponse.error(taskId, type, "PATH_SECURITY_VIOLATION", "非法 taskId");
		}

		try {
			createExclusiveDirectory(inputDir);
			createExclusiveDirectory(outputDir);
		} catch (FileAlreadyExistsException e) {
			return AnalysisTaskResponse.error(taskId, type, "TASK_DIR_CONFLICT", "任务目录已存在，拒绝覆盖: " + taskId);
		} catch (IOException e) {
			return AnalysisTaskResponse.error(taskId, type, "BOOT_PROCESS_FAILED", "无法创建任务目录: " + e.getMessage());
		}

		Path fastaPath = inputDir.resolve(TaskPathSecurity.SEQUENCES_FASTA);
		Path metadataPath = null;
		try {
			TaskPathSecurity.requireUnder(inputDir, fastaPath);
			storeUpload(fasta, fastaPath);
			if (metadata != null && !metadata.isEmpty()) {
				metadataPath = inputDir.resolve(TaskPathSecurity.METADATA_CSV);
				TaskPathSecurity.requireUnder(inputDir, metadataPath);
				storeUpload(metadata, metadataPath);
			}
		} catch (SecurityException e) {
			return AnalysisTaskResponse.error(taskId, type, "PATH_SECURITY_VIOLATION", e.getMessage());
		} catch (IOException e) {
			String msg = e.getMessage() == null ? "" : e.getMessage();
			if (msg.contains("内容为空")) {
				return AnalysisTaskResponse.error(taskId, type, "EMPTY_FASTA", msg);
			}
			return AnalysisTaskResponse.error(taskId, type, "BOOT_PROCESS_FAILED", "保存上传文件失败: " + msg);
		}

		AnalysisTaskResponse created = AnalysisTaskResponse.created(taskId, type);
		persistState(outputDir, created);

		log.info("任务 {} 开始同步分析 organismType={}", taskId, type);
		RAnalysisResponse rResult = rAnalysisService.analyze(type, fastaPath, metadataPath, outputDir);
		AnalysisTaskResponse response = AnalysisTaskResponse.fromR(taskId, type, rResult);
		persistState(outputDir, response);
		return response;
	}

	@Override
	public AnalysisTaskResponse getTask(String taskId) {
		if (!TaskPathSecurity.isValidTaskId(taskId)) {
			return AnalysisTaskResponse.error("", "", "INVALID_REQUEST", "taskId 必须为 UUID");
		}

		Path outputDir = TaskPathSecurity.resolveTaskDir(outputTasksRoot(), taskId);
		Path inputDir = TaskPathSecurity.resolveTaskDir(inputTasksRoot(), taskId);
		if (outputDir == null || inputDir == null) {
			return AnalysisTaskResponse.error(taskId, "", "PATH_SECURITY_VIOLATION", "非法 taskId");
		}

		if (!Files.isDirectory(outputDir) && !Files.isDirectory(inputDir)) {
			return AnalysisTaskResponse.error(taskId, "", "TASK_NOT_FOUND", "任务目录不存在: " + taskId);
		}

		Path stateFile = outputDir.resolve(TaskPathSecurity.TASK_STATE_JSON);
		if (Files.isRegularFile(stateFile)) {
			try {
				return objectMapper.readValue(stateFile.toFile(), AnalysisTaskResponse.class);
			} catch (IOException e) {
				return AnalysisTaskResponse.error(taskId, "", "BOOT_RESULT_MISSING",
						"无法读取 task_state.json: " + e.getMessage());
			}
		}

		Path resultJson = outputDir.resolve("analysis_result.json");
		if (Files.isRegularFile(resultJson)) {
			try {
				RAnalysisResultJson parsed =
						objectMapper.readValue(resultJson.toFile(), RAnalysisResultJson.class);
				RAnalysisResponse adapted = new RAnalysisResponse(
						parsed.status(),
						parsed.organismType() == null ? "" : parsed.organismType(),
						parsed.input() == null ? "" : parsed.input(),
						parsed.resolveTree(),
						parsed.resolveVisualization(),
						parsed.metadata() == null ? "" : parsed.metadata(),
						parsed.resolveStatistics(),
						parsed.errorMessage() == null ? "" : parsed.errorMessage(),
						parsed.errorCode() == null ? "" : parsed.errorCode(),
						outputDir.resolve(parsed.resolveTree().isBlank() ? "tree.nwk" : parsed.resolveTree())
								.toAbsolutePath().normalize().toString(),
						outputDir.resolve(parsed.resolveVisualization().isBlank() ? "tree.png" : parsed.resolveVisualization())
								.toAbsolutePath().normalize().toString(),
						parsed.resolveSequenceCount(),
						parsed.resolveMethod(),
						parsed.resolveModel()
				);
				return AnalysisTaskResponse.fromR(taskId, adapted.organismType(), adapted);
			} catch (IOException e) {
				return AnalysisTaskResponse.error(taskId, "", "BOOT_RESULT_MISSING",
						"无法解析 analysis_result.json: " + e.getMessage());
			}
		}

		if (!Files.isDirectory(outputDir)) {
			return AnalysisTaskResponse.error(taskId, "", "TASK_NOT_FOUND", "输出任务目录不存在: " + taskId);
		}
		return AnalysisTaskResponse.error(taskId, "", "BOOT_RESULT_MISSING", "任务结果尚未生成");
	}

	private Path inputTasksRoot() {
		return rProperties.rootPath().resolve("input").resolve("tasks").toAbsolutePath().normalize();
	}

	private Path outputTasksRoot() {
		return rProperties.rootPath().resolve("output").resolve("tasks").toAbsolutePath().normalize();
	}

	private static AnalysisTaskResponse validateFastaUpload(MultipartFile fasta) {
		if (fasta == null || fasta.isEmpty()) {
			return AnalysisTaskResponse.error("", "", "EMPTY_FASTA", "fasta 文件不能为空");
		}
		String original = fasta.getOriginalFilename();
		if (original != null && !original.isBlank()) {
			if (original.contains("..")) {
				return AnalysisTaskResponse.error("", "", "PATH_SECURITY_VIOLATION", "非法 fasta 文件名");
			}
			String sanitized = TaskPathSecurity.sanitizeOriginalFilename(original);
			if (sanitized.isBlank()) {
				return AnalysisTaskResponse.error("", "", "PATH_SECURITY_VIOLATION", "非法 fasta 文件名");
			}
			if (!TaskPathSecurity.isAllowedFastaExtension(original)
					&& !looksLikeFastaContentType(fasta.getContentType())) {
				return AnalysisTaskResponse.error("", "", "INVALID_FILE_TYPE",
						"fasta 文件类型不支持（期望 .fasta/.fa/.fna/.fas）: " + sanitized);
			}
		}
		return null;
	}

	private static AnalysisTaskResponse validateMetadataUpload(MultipartFile metadata) {
		if (metadata == null || metadata.isEmpty()) {
			return null;
		}
		String original = metadata.getOriginalFilename();
		if (original != null && !original.isBlank()) {
			if (original.contains("..")) {
				return AnalysisTaskResponse.error("", "", "PATH_SECURITY_VIOLATION", "非法 metadata 文件名");
			}
			if (!TaskPathSecurity.isAllowedMetadataExtension(original)
					&& !looksLikeCsvContentType(metadata.getContentType())) {
				return AnalysisTaskResponse.error("", "", "INVALID_FILE_TYPE",
						"metadata 文件类型不支持（期望 .csv）: " + original);
			}
		}
		return null;
	}

	private static boolean looksLikeFastaContentType(String contentType) {
		if (contentType == null || contentType.isBlank()) {
			return false;
		}
		String ct = contentType.toLowerCase();
		return ct.contains("fasta") || ct.startsWith("text/") || ct.equals("application/octet-stream");
	}

	private static boolean looksLikeCsvContentType(String contentType) {
		if (contentType == null || contentType.isBlank()) {
			return false;
		}
		String ct = contentType.toLowerCase();
		return ct.contains("csv") || ct.startsWith("text/") || ct.equals("application/octet-stream");
	}

	private static void createExclusiveDirectory(Path dir) throws IOException {
		Files.createDirectories(dir.getParent());
		try {
			Files.createDirectory(dir);
		} catch (FileAlreadyExistsException e) {
			throw e;
		}
	}

	private static void storeUpload(MultipartFile file, Path target) throws IOException {
		try (InputStream in = file.getInputStream()) {
			Files.copy(in, target, StandardCopyOption.REPLACE_EXISTING);
		}
		if (Files.size(target) == 0L) {
			Files.deleteIfExists(target);
			throw new IOException("上传文件内容为空: " + target.getFileName());
		}
	}

	private void persistState(Path outputDir, AnalysisTaskResponse response) {
		try {
			Files.createDirectories(outputDir);
			Path state = outputDir.resolve(TaskPathSecurity.TASK_STATE_JSON);
			TaskPathSecurity.requireUnder(outputDir, state);
			objectMapper.writerWithDefaultPrettyPrinter().writeValue(state.toFile(), response);
		} catch (Exception e) {
			log.warn("无法写入 task_state.json ({}): {}", outputDir, e.getMessage());
		}
	}
}
