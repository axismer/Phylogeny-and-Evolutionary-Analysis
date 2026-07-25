package com.phylo.platform.dto;

import java.util.Collections;
import java.util.Map;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * R 分析完成后返回给调用方的摘要（含业务错误，统一 status / error_code / error_message）。
 * <p>
 * 契约字段使用 snake_case；legacy 字段保留 camelCase（treeFile / imageFile / sequenceCount）。
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record RAnalysisResponse(
		String status,
		@JsonProperty("organism_type") String organismType,
		String input,
		String tree,
		String visualization,
		String metadata,
		Map<String, Object> statistics,
		@JsonProperty("error_message") String errorMessage,
		@JsonProperty("error_code") String errorCode,
		String treeFile,
		String imageFile,
		Integer sequenceCount,
		String method,
		String model
) {

	public static RAnalysisResponse error(String errorCode, String errorMessage) {
		return error("", errorCode, errorMessage);
	}

	public static RAnalysisResponse error(String organismType, String errorCode, String errorMessage) {
		return new RAnalysisResponse(
				"error",
				organismType == null ? "" : organismType,
				"",
				"",
				"",
				"",
				Collections.emptyMap(),
				errorMessage == null ? "" : errorMessage,
				errorCode == null ? "" : errorCode,
				"",
				"",
				null,
				null,
				null
		);
	}

	public static RAnalysisResponse notImplemented(String organismType, String errorCode, String errorMessage) {
		return new RAnalysisResponse(
				"not_implemented",
				organismType == null ? "" : organismType,
				"",
				"",
				"",
				"",
				Collections.emptyMap(),
				errorMessage == null ? "" : errorMessage,
				errorCode == null ? "UNSUPPORTED_ORGANISM" : errorCode,
				"",
				"",
				null,
				null,
				null
		);
	}

	@JsonIgnore
	public boolean isOk() {
		return "success".equalsIgnoreCase(status) || "partial".equalsIgnoreCase(status);
	}
}
