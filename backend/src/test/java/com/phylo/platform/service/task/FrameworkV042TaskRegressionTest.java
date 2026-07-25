package com.phylo.platform.service.task;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;

import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.MethodOrderer;
import org.junit.jupiter.api.Order;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestMethodOrder;
import org.junit.jupiter.api.Timeout;
import org.springframework.mock.web.MockMultipartFile;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.phylo.platform.config.PhyloRProperties;
import com.phylo.platform.dto.AnalysisTaskResponse;
import com.phylo.platform.service.r.ProcessBuilderRPhylogeneticAnalysisService;

/**
 * v0.4.2-A Task Service 回归（真实 Rscript + multipart 落盘生命周期）。
 * <p>
 * 工作目录约定：Gradle/IDE 从 {@code backend/} 启动；{@code phylo.r.root=../r-analysis}。
 */
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
@Timeout(value = 20, unit = TimeUnit.MINUTES)
class FrameworkV042TaskRegressionTest {

	private static Path rRoot;
	private static Path fixtures;
	private static DefaultAnalysisTaskService taskService;

	@BeforeAll
	static void setUp() throws Exception {
		rRoot = Paths.get("..", "r-analysis").toAbsolutePath().normalize();
		assumeTrue(Files.isDirectory(rRoot), () -> "r-analysis root missing: " + rRoot);

		Path script = rRoot.resolve("runners/run_analysis.R");
		assumeTrue(Files.isRegularFile(script), () -> "run_analysis.R missing: " + script);

		PhyloRProperties props = new PhyloRProperties();
		props.setRoot(rRoot.toString());
		props.setScript("runners/run_analysis.R");
		props.setTimeoutSeconds(600);
		props.setRscript(resolveRscript());
		assumeTrue(canLaunch(props.getRscript()), () -> "Rscript not runnable: " + props.getRscript());

		fixtures = rRoot.resolve("test-data");
		ObjectMapper mapper = new ObjectMapper();
		ProcessBuilderRPhylogeneticAnalysisService rService =
				new ProcessBuilderRPhylogeneticAnalysisService(props, mapper);
		taskService = new DefaultAnalysisTaskService(props, rService, mapper);

		Files.createDirectories(rRoot.resolve("input/tasks"));
		Files.createDirectories(rRoot.resolve("output/tasks"));
	}

	@Test
	@Order(1)
	void case1_virusUploadSuccess() throws Exception {
		Path fasta = fixtures.resolve("virus/valid/sequences.fasta");
		Path metadata = fixtures.resolve("virus/valid/metadata.csv");
		assumeTrue(Files.isRegularFile(fasta));
		assumeTrue(Files.isRegularFile(metadata));

		AnalysisTaskResponse response = taskService.createAndRun(
				"virus",
				multipart("fasta", "sequences.fasta", "text/plain", fasta),
				multipart("metadata", "metadata.csv", "text/csv", metadata)
		);

		assertTrue(response.isOk(), () -> summarize(response));
		assertNotNull(response.taskId());
		assertTrue(TaskPathSecurity.isValidTaskId(response.taskId()));
		assertEquals("virus", response.organismType());
		assertTrue(response.errorCode() == null || response.errorCode().isBlank());

		Path inputDir = rRoot.resolve("input/tasks").resolve(response.taskId());
		Path outputDir = rRoot.resolve("output/tasks").resolve(response.taskId());
		assertTrue(Files.isRegularFile(inputDir.resolve("sequences.fasta")));
		assertTrue(Files.isRegularFile(inputDir.resolve("metadata.csv")));
		assertTrue(Files.isRegularFile(outputDir.resolve("analysis_result.json")));
		assertTrue(Files.isRegularFile(outputDir.resolve("task_state.json")));

		AnalysisTaskResponse fetched = taskService.getTask(response.taskId());
		assertTrue(fetched.isOk(), () -> summarize(fetched));
		assertEquals(response.taskId(), fetched.taskId());
	}

	@Test
	@Order(2)
	void case2_fungiUploadSuccess() throws Exception {
		Path fasta = fixtures.resolve("fungi/valid/sequences.fasta");
		Path metadata = fixtures.resolve("fungi/valid/metadata.csv");
		assumeTrue(Files.isRegularFile(fasta));
		assumeTrue(Files.isRegularFile(metadata));

		AnalysisTaskResponse response = taskService.createAndRun(
				"fungi",
				multipart("fasta", "sequences.fasta", "text/plain", fasta),
				multipart("metadata", "metadata.csv", "text/csv", metadata)
		);

		assertTrue(response.isOk(), () -> summarize(response));
		assertEquals("fungi", response.organismType());
		assertTrue(Files.isRegularFile(
				rRoot.resolve("output/tasks").resolve(response.taskId()).resolve("analysis_result.json")));
	}

	@Test
	@Order(3)
	void case3_missingFasta() {
		AnalysisTaskResponse response = taskService.createAndRun("virus", null, null);

		assertEquals("error", response.status());
		assertEquals("EMPTY_FASTA", response.errorCode());
		assertFalse(response.errorMessage() == null || response.errorMessage().isBlank());
	}

	@Test
	@Order(4)
	void case4_missingMetadata() throws Exception {
		Path fasta = fixtures.resolve("bacteria/valid/valid.fasta");
		assumeTrue(Files.isRegularFile(fasta));

		AnalysisTaskResponse response = taskService.createAndRun(
				"bacteria",
				multipart("fasta", "valid.fasta", "text/plain", fasta),
				null
		);

		assertEquals("error", response.status(), () -> summarize(response));
		assertEquals("MISSING_METADATA_ARGUMENT", response.errorCode(), () -> summarize(response));
		assertFalse(response.errorMessage() == null || response.errorMessage().isBlank());
		assertTrue(TaskPathSecurity.isValidTaskId(response.taskId()));
		assertTrue(Files.isDirectory(rRoot.resolve("output/tasks").resolve(response.taskId())));
	}

	@Test
	@Order(5)
	void case5_unknownOrganism() throws Exception {
		Path fasta = fixtures.resolve("virus/valid/sequences.fasta");
		assumeTrue(Files.isRegularFile(fasta));

		AnalysisTaskResponse response = taskService.createAndRun(
				"unknown_organism_xyz",
				multipart("fasta", "sequences.fasta", "text/plain", fasta),
				null
		);

		assertEquals("not_implemented", response.status(), () -> summarize(response));
		assertEquals("UNSUPPORTED_ORGANISM", response.errorCode(), () -> summarize(response));
		assertFalse(response.errorMessage() == null || response.errorMessage().isBlank());
	}

	@Test
	@Order(6)
	void case6_concurrentTasksDirectoryIsolation() throws Exception {
		Path fasta = fixtures.resolve("virus/valid/sequences.fasta");
		Path metadata = fixtures.resolve("virus/valid/metadata.csv");
		assumeTrue(Files.isRegularFile(fasta));
		assumeTrue(Files.isRegularFile(metadata));

		byte[] fastaBytes = Files.readAllBytes(fasta);
		byte[] metaBytes = Files.readAllBytes(metadata);

		CompletableFuture<AnalysisTaskResponse> f1 = CompletableFuture.supplyAsync(() ->
				taskService.createAndRun(
						"virus",
						new MockMultipartFile("fasta", "sequences.fasta", "text/plain", fastaBytes),
						new MockMultipartFile("metadata", "metadata.csv", "text/csv", metaBytes)
				));
		CompletableFuture<AnalysisTaskResponse> f2 = CompletableFuture.supplyAsync(() ->
				taskService.createAndRun(
						"virus",
						new MockMultipartFile("fasta", "sequences.fasta", "text/plain", fastaBytes),
						new MockMultipartFile("metadata", "metadata.csv", "text/csv", metaBytes)
				));

		AnalysisTaskResponse r1 = f1.get(15, TimeUnit.MINUTES);
		AnalysisTaskResponse r2 = f2.get(15, TimeUnit.MINUTES);

		assertTrue(r1.isOk(), () -> "task1: " + summarize(r1));
		assertTrue(r2.isOk(), () -> "task2: " + summarize(r2));
		assertNotEquals(r1.taskId(), r2.taskId());

		Path in1 = rRoot.resolve("input/tasks").resolve(r1.taskId());
		Path in2 = rRoot.resolve("input/tasks").resolve(r2.taskId());
		Path out1 = rRoot.resolve("output/tasks").resolve(r1.taskId());
		Path out2 = rRoot.resolve("output/tasks").resolve(r2.taskId());

		assertNotEquals(in1, in2);
		assertNotEquals(out1, out2);
		assertTrue(Files.isRegularFile(in1.resolve("sequences.fasta")));
		assertTrue(Files.isRegularFile(in2.resolve("sequences.fasta")));
		assertTrue(Files.isRegularFile(out1.resolve("analysis_result.json")));
		assertTrue(Files.isRegularFile(out2.resolve("analysis_result.json")));
		assertFalse(out1.startsWith(out2) || out2.startsWith(out1));
	}

	private static MockMultipartFile multipart(String name, String filename, String contentType, Path file)
			throws Exception {
		return new MockMultipartFile(name, filename, contentType, Files.readAllBytes(file));
	}

	private static String summarize(AnalysisTaskResponse response) {
		return "taskId=" + response.taskId()
				+ " status=" + response.status()
				+ " error_code=" + response.errorCode()
				+ " error_message=" + response.errorMessage()
				+ " organism_type=" + response.organismType();
	}

	private static String resolveRscript() {
		String fromEnv = System.getenv("PHYLO_RSCRIPT");
		if (fromEnv != null && !fromEnv.isBlank()) {
			return fromEnv.trim();
		}
		Path local = Paths.get("D:/R-4.4.2/bin/Rscript.exe");
		if (Files.isRegularFile(local)) {
			return local.toString();
		}
		return "Rscript";
	}

	private static boolean canLaunch(String rscript) {
		try {
			Process process = new ProcessBuilder(rscript, "--version")
					.redirectErrorStream(true)
					.start();
			boolean finished = process.waitFor(30, TimeUnit.SECONDS);
			if (!finished) {
				process.destroyForcibly();
				return false;
			}
			return process.exitValue() == 0;
		} catch (Exception e) {
			return false;
		}
	}
}
