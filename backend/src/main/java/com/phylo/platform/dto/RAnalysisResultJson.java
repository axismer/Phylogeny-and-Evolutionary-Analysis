package com.phylo.platform.dto;

import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * 对应 R Framework 写出的 analysis_result.json（v0.1 契约 + legacy fallback）。
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record RAnalysisResultJson(
		String status,
		@JsonProperty("organism_type") String organismType,
		String input,
		String tree,
		String visualization,
		String metadata,
		Map<String, Object> statistics,
		@JsonProperty("error_message") String errorMessage,
		@JsonProperty("error_code") String errorCode,
		@JsonProperty("tree_file") String treeFile,
		@JsonProperty("image_file") String imageFile,
		@JsonProperty("matrix_file") String matrixFile,
		@JsonProperty("sequence_count") Integer sequenceCount,
		String method,
		String model
) {

	public String resolveTree() {
		if (tree != null && !tree.isBlank()) {
			return tree.trim();
		}
		if (treeFile != null && !treeFile.isBlank()) {
			return treeFile.trim();
		}
		return "";
	}

	public String resolveVisualization() {
		if (visualization != null && !visualization.isBlank()) {
			return visualization.trim();
		}
		if (imageFile != null && !imageFile.isBlank()) {
			return imageFile.trim();
		}
		return "";
	}

	public Map<String, Object> resolveStatistics() {
		if (statistics != null && !statistics.isEmpty()) {
			return statistics;
		}
		Map<String, Object> legacy = new LinkedHashMap<>();
		if (sequenceCount != null) {
			legacy.put("sequence_count", sequenceCount);
		}
		if (method != null && !method.isBlank()) {
			legacy.put("method", method);
		}
		if (model != null && !model.isBlank()) {
			legacy.put("model", model);
		}
		return legacy.isEmpty() ? Collections.emptyMap() : legacy;
	}

	public Integer resolveSequenceCount() {
		Object fromStats = statistics == null ? null : statistics.get("sequence_count");
		if (fromStats instanceof Number number) {
			return number.intValue();
		}
		if (fromStats instanceof String text && !text.isBlank()) {
			try {
				return Integer.parseInt(text.trim());
			} catch (NumberFormatException ignored) {
				// fall through to legacy
			}
		}
		return sequenceCount;
	}

	public String resolveMethod() {
		Object fromStats = statistics == null ? null : statistics.get("method");
		if (fromStats != null && !String.valueOf(fromStats).isBlank()) {
			return String.valueOf(fromStats);
		}
		return method != null && !method.isBlank() ? method : null;
	}

	public String resolveModel() {
		Object fromStats = statistics == null ? null : statistics.get("model");
		if (fromStats != null && !String.valueOf(fromStats).isBlank()) {
			return String.valueOf(fromStats);
		}
		return model != null && !model.isBlank() ? model : null;
	}
}
