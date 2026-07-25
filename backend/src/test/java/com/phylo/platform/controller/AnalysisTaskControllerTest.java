package com.phylo.platform.controller;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import com.phylo.platform.dto.AnalysisTaskResponse;
import com.phylo.platform.dto.RAnalysisResponse;
import com.phylo.platform.service.task.AnalysisTaskService;

@WebMvcTest(AnalysisTaskController.class)
class AnalysisTaskControllerTest {

	@Autowired
	private MockMvc mockMvc;

	@MockitoBean
	private AnalysisTaskService analysisTaskService;

	@Test
	void create_success_returnsOk() throws Exception {
		when(analysisTaskService.createAndRun(eq("virus"), any(), any()))
				.thenReturn(AnalysisTaskResponse.fromR(
						"11111111-1111-1111-1111-111111111111",
						"virus",
						new RAnalysisResponse(
								"success", "virus", "sequences.fasta", "tree.nwk",
								"circular_tree_final.png", "metadata.csv", null,
								"", "", "/tmp/tree.nwk", "/tmp/tree.png", 4, "ML", "JC69"
						)
				));

		MockMultipartFile fasta = new MockMultipartFile(
				"fasta", "sequences.fasta", "text/plain", ">a\nACGT\n".getBytes());
		MockMultipartFile metadata = new MockMultipartFile(
				"metadata", "metadata.csv", "text/csv", "id,group\na,g1\n".getBytes());

		mockMvc.perform(multipart("/api/tasks")
						.file(fasta)
						.file(metadata)
						.param("type", "virus"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.taskId").value("11111111-1111-1111-1111-111111111111"))
				.andExpect(jsonPath("$.status").value("success"))
				.andExpect(jsonPath("$.organism_type").value("virus"));

		verify(analysisTaskService).createAndRun(eq("virus"), any(), any());
	}

	@Test
	void create_emptyFasta_returns400() throws Exception {
		when(analysisTaskService.createAndRun(eq("virus"), isNull(), isNull()))
				.thenReturn(AnalysisTaskResponse.error("", "virus", "EMPTY_FASTA", "fasta 文件不能为空"));

		mockMvc.perform(multipart("/api/tasks").param("type", "virus"))
				.andExpect(status().isBadRequest())
				.andExpect(jsonPath("$.status").value("error"))
				.andExpect(jsonPath("$.error_code").value("EMPTY_FASTA"))
				.andExpect(jsonPath("$.error_message").isNotEmpty());
	}

	@Test
	void create_unknownOrganism_returns501() throws Exception {
		when(analysisTaskService.createAndRun(eq("alien"), any(), isNull()))
				.thenReturn(new AnalysisTaskResponse(
						"22222222-2222-2222-2222-222222222222",
						"not_implemented",
						null,
						"UNSUPPORTED_ORGANISM",
						"unsupported organism type: alien",
						"alien"
				));

		MockMultipartFile fasta = new MockMultipartFile(
				"fasta", "sequences.fasta", "text/plain", ">a\nACGT\n".getBytes());

		mockMvc.perform(multipart("/api/tasks")
						.file(fasta)
						.param("type", "alien"))
				.andExpect(status().isNotImplemented())
				.andExpect(jsonPath("$.status").value("not_implemented"))
				.andExpect(jsonPath("$.error_code").value("UNSUPPORTED_ORGANISM"));
	}

	@Test
	void get_notFound_returns404() throws Exception {
		when(analysisTaskService.getTask("33333333-3333-3333-3333-333333333333"))
				.thenReturn(AnalysisTaskResponse.error(
						"33333333-3333-3333-3333-333333333333",
						"",
						"TASK_NOT_FOUND",
						"任务目录不存在"
				));

		mockMvc.perform(get("/api/tasks/33333333-3333-3333-3333-333333333333"))
				.andExpect(status().isNotFound())
				.andExpect(jsonPath("$.status").value("error"))
				.andExpect(jsonPath("$.error_code").value("TASK_NOT_FOUND"));
	}
}
