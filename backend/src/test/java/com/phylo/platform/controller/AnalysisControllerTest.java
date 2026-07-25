package com.phylo.platform.controller;

import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import com.phylo.platform.config.PhyloDataProperties;
import com.phylo.platform.model.DistanceMatrix;
import com.phylo.platform.service.matrix.DistanceMatrixCsvReader;
import com.phylo.platform.service.matrix.DistanceMatrixService;
import com.phylo.platform.service.tree.TreeService;

@WebMvcTest(AnalysisController.class)
class AnalysisControllerTest {

	@Autowired
	private MockMvc mockMvc;

	@MockitoBean
	private DistanceMatrixService distanceMatrixService;

	@MockitoBean
	private TreeService treeService;

	@MockitoBean
	private DistanceMatrixCsvReader csvReader;

	@MockitoBean
	private PhyloDataProperties dataProperties;

	@Test
	void postRun_returnsSuccess() throws Exception {
		when(distanceMatrixService.computeAndWriteFromRaw()).thenReturn(Path.of("matrix.csv"));
		when(treeService.buildAndWriteFromMatrixFile()).thenReturn(Path.of("tree.nwk"));

		mockMvc.perform(post("/api/analysis/run"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.status").value("success"))
				.andExpect(jsonPath("$.message").value("analysis completed"));

		verify(distanceMatrixService).computeAndWriteFromRaw();
		verify(treeService).buildAndWriteFromMatrixFile();
	}

	@Test
	void getMatrix_returnsLabelsAndValues(@TempDir Path tempDir) throws Exception {
		Path matrixFile = tempDir.resolve("distance_matrix.csv");
		Files.writeString(matrixFile, ",A,B\nA,0,0.2\nB,0.2,0\n");
		when(dataProperties.matrixDir()).thenReturn(tempDir);
		when(csvReader.read(matrixFile)).thenReturn(new DistanceMatrix(
				List.of("A", "B"),
				new double[][] {{0.0, 0.2}, {0.2, 0.0}}
		));

		mockMvc.perform(get("/api/analysis/matrix"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.labels[0]").value("A"))
				.andExpect(jsonPath("$.labels[1]").value("B"))
				.andExpect(jsonPath("$.values[0][1]").value(0.2));
	}

	@Test
	void getTree_returnsNewick(@TempDir Path tempDir) throws Exception {
		Path treeFile = tempDir.resolve("tree.nwk");
		Files.writeString(treeFile, "((A:0.1,B:0.1):0.2,C:0.3);");
		when(dataProperties.treeDir()).thenReturn(tempDir);

		mockMvc.perform(get("/api/analysis/tree"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.newick").value("((A:0.1,B:0.1):0.2,C:0.3);"));
	}
}
