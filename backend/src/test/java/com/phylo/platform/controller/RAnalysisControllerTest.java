package com.phylo.platform.controller;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.nio.file.Path;
import java.util.Map;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import com.phylo.platform.dto.RAnalysisResponse;
import com.phylo.platform.service.r.RPhylogeneticAnalysisService;

@WebMvcTest(RAnalysisController.class)
class RAnalysisControllerTest {

	@Autowired
	private MockMvc mockMvc;

	@MockitoBean
	private RPhylogeneticAnalysisService rAnalysisService;

	@Test
	void run_success_returnsOkWithContractFields() throws Exception {
		when(rAnalysisService.analyze(eq("virus"), any(Path.class), isNull(), any(Path.class)))
				.thenReturn(new RAnalysisResponse(
						"success",
						"virus",
						"sequences.fasta",
						"tree.nwk",
						"circular_tree_final.png",
						"metadata.csv",
						Map.of("sequence_count", 5),
						"",
						"",
						"/tmp/tree.nwk",
						"/tmp/circular_tree_final.png",
						5,
						"ML",
						"JC69"
				));

		mockMvc.perform(post("/api/r-analysis/run")
						.contentType(MediaType.APPLICATION_JSON)
						.content("""
								{
								  "fastaPath": "D:/data/sequences.fasta",
								  "outputDir": "D:/out/demo"
								}
								"""))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.status").value("success"))
				.andExpect(jsonPath("$.organism_type").value("virus"))
				.andExpect(jsonPath("$.tree").value("tree.nwk"))
				.andExpect(jsonPath("$.treeFile").value("/tmp/tree.nwk"));

		verify(rAnalysisService).analyze(eq("virus"), any(Path.class), isNull(), any(Path.class));
	}

	@Test
	void run_businessError_returns422WithErrorCode() throws Exception {
		when(rAnalysisService.analyze(eq("bacteria"), any(Path.class), isNull(), any(Path.class)))
				.thenReturn(RAnalysisResponse.error("bacteria", "MISSING_METADATA_ARGUMENT", "需要 --metadata"));

		mockMvc.perform(post("/api/r-analysis/run")
						.contentType(MediaType.APPLICATION_JSON)
						.content("""
								{
								  "organismType": "bacteria",
								  "fastaPath": "D:/data/valid.fasta",
								  "outputDir": "D:/out/demo"
								}
								"""))
				.andExpect(status().isUnprocessableEntity())
				.andExpect(jsonPath("$.status").value("error"))
				.andExpect(jsonPath("$.error_code").value("MISSING_METADATA_ARGUMENT"))
				.andExpect(jsonPath("$.error_message").value("需要 --metadata"));
	}

	@Test
	void run_notImplemented_returns501() throws Exception {
		when(rAnalysisService.analyze(eq("archaea"), any(Path.class), isNull(), any(Path.class)))
				.thenReturn(RAnalysisResponse.notImplemented("archaea", "UNSUPPORTED_ORGANISM", "not implemented"));

		mockMvc.perform(post("/api/r-analysis/run")
						.contentType(MediaType.APPLICATION_JSON)
						.content("""
								{
								  "organism_type": "archaea",
								  "fasta_path": "D:/data/x.fasta",
								  "output_dir": "D:/out/demo"
								}
								"""))
				.andExpect(status().isNotImplemented())
				.andExpect(jsonPath("$.status").value("not_implemented"))
				.andExpect(jsonPath("$.error_code").value("UNSUPPORTED_ORGANISM"));
	}

	@Test
	void run_missingBody_returns400WithErrorCode() throws Exception {
		mockMvc.perform(post("/api/r-analysis/run")
						.contentType(MediaType.APPLICATION_JSON))
				.andExpect(status().isBadRequest())
				.andExpect(jsonPath("$.status").value("error"))
				.andExpect(jsonPath("$.error_code").value("INVALID_REQUEST"));
	}
}
