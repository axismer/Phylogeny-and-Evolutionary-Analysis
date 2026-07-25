package com.phylo.platform.service.r;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.phylo.platform.dto.RAnalysisResultJson;

class RAnalysisResultJsonTest {

	private final ObjectMapper mapper = new ObjectMapper();

	@Test
	void parsesLegacyAnalysisResultJson() throws Exception {
		String json = """
				{
				  "input": "H3N2_NA_20_test.fasta",
				  "sequence_count": 19,
				  "method": "Maximum Likelihood",
				  "model": "JC69",
				  "tree_file": "tree.nwk",
				  "matrix_file": "distance_matrix.csv",
				  "image_file": "tree.png",
				  "status": "success"
				}
				""";
		RAnalysisResultJson parsed = mapper.readValue(json, RAnalysisResultJson.class);
		assertEquals("success", parsed.status());
		assertEquals(19, parsed.sequenceCount());
		assertEquals("Maximum Likelihood", parsed.method());
		assertEquals("JC69", parsed.model());
		assertEquals("tree.nwk", parsed.resolveTree());
		assertEquals("tree.png", parsed.resolveVisualization());
		assertEquals(19, parsed.resolveSequenceCount());
		assertEquals("Maximum Likelihood", parsed.resolveMethod());
		assertEquals("JC69", parsed.resolveModel());
	}

	@Test
	void prefersContractFieldsOverLegacyFallbacks() throws Exception {
		String json = """
				{
				  "status": "success",
				  "organism_type": "bacteria",
				  "input": "valid.fasta",
				  "tree": "tree.nwk",
				  "tree_file": "legacy_tree.nwk",
				  "visualization": "circular_tree_final.png",
				  "image_file": "legacy.png",
				  "metadata": "metadata.csv",
				  "statistics": {
				    "sequence_count": 6,
				    "method": "NJ",
				    "model": "K80"
				  },
				  "sequence_count": 99,
				  "method": "legacy-method",
				  "model": "legacy-model",
				  "error_message": "",
				  "error_code": null
				}
				""";
		RAnalysisResultJson parsed = mapper.readValue(json, RAnalysisResultJson.class);
		assertEquals("bacteria", parsed.organismType());
		assertEquals("tree.nwk", parsed.resolveTree());
		assertEquals("circular_tree_final.png", parsed.resolveVisualization());
		assertEquals(6, parsed.resolveStatistics().get("sequence_count"));
		// statistics 优先于 legacy sequence_count / method / model
		assertEquals(6, parsed.resolveSequenceCount());
		assertEquals("NJ", parsed.resolveMethod());
		assertEquals("K80", parsed.resolveModel());
	}

	@Test
	void resolvesStatisticsFromLegacyWhenStatisticsMissing() throws Exception {
		String json = """
				{
				  "status": "error",
				  "organism_type": "virus",
				  "error_code": "INVALID_DNA",
				  "error_message": "illegal base",
				  "sequence_count": 3,
				  "method": "ML",
				  "model": "JC69"
				}
				""";
		RAnalysisResultJson parsed = mapper.readValue(json, RAnalysisResultJson.class);
		assertEquals("INVALID_DNA", parsed.errorCode());
		assertEquals("illegal base", parsed.errorMessage());
		assertNull(parsed.statistics());
		assertTrue(parsed.resolveStatistics().containsKey("sequence_count"));
		assertEquals(3, parsed.resolveStatistics().get("sequence_count"));
		assertEquals("ML", parsed.resolveStatistics().get("method"));
		assertEquals("JC69", parsed.resolveStatistics().get("model"));
	}
}
