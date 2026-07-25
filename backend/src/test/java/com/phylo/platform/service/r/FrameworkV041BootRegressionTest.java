package com.phylo.platform.service.r;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.concurrent.TimeUnit;

import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.MethodOrderer;
import org.junit.jupiter.api.Order;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestMethodOrder;
import org.junit.jupiter.api.Timeout;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.phylo.platform.config.PhyloRProperties;
import com.phylo.platform.dto.RAnalysisResponse;

/**
 * v0.4.1 Boot ↔ R Framework 协议回归（真实 Rscript）。
 * <p>
 * 工作目录约定：Gradle/IDE 从 {@code backend/} 启动；{@code phylo.r.root=../r-analysis}。
 */
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
@Timeout(value = 15, unit = TimeUnit.MINUTES)
class FrameworkV041BootRegressionTest {

	private static Path rRoot;
	private static Path fixtures;
	private static Path outRoot;
	private static ProcessBuilderRPhylogeneticAnalysisService service;

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
		outRoot = rRoot.resolve("output/tasks/boot_v041_regression");
		Files.createDirectories(outRoot);

		service = new ProcessBuilderRPhylogeneticAnalysisService(props, new ObjectMapper());
	}

	@Test
	@Order(1)
	void case1_virusValid() {
		Path fasta = fixtures.resolve("virus/valid/sequences.fasta");
		Path metadata = fixtures.resolve("virus/valid/metadata.csv");
		Path out = outRoot.resolve("case1_virus_valid");
		assumeTrue(Files.isRegularFile(fasta));
		assumeTrue(Files.isRegularFile(metadata));

		RAnalysisResponse result = service.analyze("virus", fasta, metadata, out);

		assertTrue(result.isOk(), () -> "expected success, got " + summarize(result));
		assertEquals("virus", result.organismType());
		assertFalse(result.tree() == null || result.tree().isBlank());
		assertTrue(Files.isRegularFile(out.resolve("analysis_result.json")));
		assertTrue(result.errorCode() == null || result.errorCode().isBlank());
	}

	@Test
	@Order(2)
	void case2_bacteriaValid() {
		Path fasta = fixtures.resolve("bacteria/valid/valid.fasta");
		Path metadata = fixtures.resolve("bacteria/valid/metadata.csv");
		Path out = outRoot.resolve("case2_bacteria_valid");
		assumeTrue(Files.isRegularFile(fasta));
		assumeTrue(Files.isRegularFile(metadata));

		RAnalysisResponse result = service.analyze("bacteria", fasta, metadata, out);

		assertTrue(result.isOk(), () -> "expected success, got " + summarize(result));
		assertEquals("bacteria", result.organismType());
		assertTrue(Files.isRegularFile(out.resolve("analysis_result.json")));
		assertTrue(result.errorCode() == null || result.errorCode().isBlank());
	}

	@Test
	@Order(3)
	void case3_fungiValid() {
		Path fasta = fixtures.resolve("fungi/valid/sequences.fasta");
		Path metadata = fixtures.resolve("fungi/valid/metadata.csv");
		Path out = outRoot.resolve("case3_fungi_valid");
		assumeTrue(Files.isRegularFile(fasta));
		assumeTrue(Files.isRegularFile(metadata));

		RAnalysisResponse result = service.analyze("fungi", fasta, metadata, out);

		assertTrue(result.isOk(), () -> "expected success, got " + summarize(result));
		assertEquals("fungi", result.organismType());
		assertTrue(Files.isRegularFile(out.resolve("analysis_result.json")));
		assertTrue(result.errorCode() == null || result.errorCode().isBlank());
	}

	@Test
	@Order(4)
	void case4_unknownOrganism() {
		Path fasta = fixtures.resolve("virus/valid/sequences.fasta");
		Path out = outRoot.resolve("case4_unknown_organism");
		assumeTrue(Files.isRegularFile(fasta));

		RAnalysisResponse result = service.analyze("unknown_organism_xyz", fasta, null, out);

		assertEquals("not_implemented", result.status(), () -> summarize(result));
		assertEquals("UNSUPPORTED_ORGANISM", result.errorCode());
		assertNotNull(result.errorMessage());
		assertFalse(result.errorMessage().isBlank());
	}

	@Test
	@Order(5)
	void case5_invalidFasta() {
		Path fasta = fixtures.resolve("virus/invalid_fasta/bad.fasta");
		Path out = outRoot.resolve("case5_invalid_fasta");
		assumeTrue(Files.isRegularFile(fasta));

		RAnalysisResponse result = service.analyze("virus", fasta, null, out);

		assertEquals("error", result.status(), () -> summarize(result));
		assertFalse(result.errorCode() == null || result.errorCode().isBlank());
		assertTrue(
				result.errorCode().equals("EMPTY_FASTA") || result.errorCode().equals("INVALID_DNA"),
				() -> "unexpected error_code: " + summarize(result)
		);
		assertFalse(result.errorMessage() == null || result.errorMessage().isBlank());
	}

	@Test
	@Order(6)
	void case6_missingMetadata() {
		Path fasta = fixtures.resolve("bacteria/valid/valid.fasta");
		Path out = outRoot.resolve("case6_missing_metadata");
		assumeTrue(Files.isRegularFile(fasta));

		RAnalysisResponse result = service.analyze("bacteria", fasta, null, out);

		assertEquals("error", result.status(), () -> summarize(result));
		assertEquals("MISSING_METADATA_ARGUMENT", result.errorCode(), () -> summarize(result));
		assertFalse(result.errorMessage() == null || result.errorMessage().isBlank());
	}

	private static String summarize(RAnalysisResponse result) {
		return "status=" + result.status()
				+ " error_code=" + result.errorCode()
				+ " error_message=" + result.errorMessage()
				+ " organism_type=" + result.organismType();
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
