package com.phylo.platform.dto;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * 分析任务生命周期响应。
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
@JsonIgnoreProperties(ignoreUnknown = true)
public record AnalysisTaskResponse(
		String taskId,
		String status,
		RAnalysisResponse result,
		@JsonProperty("error_code") String errorCode,
		@JsonProperty("error_message") String errorMessage,
		@JsonProperty("organism_type") String organismType
) {

	public static AnalysisTaskResponse created(String taskId, String organismType) {
		return new AnalysisTaskResponse(taskId, "CREATED", null, "", "", organismType);
	}

	public static AnalysisTaskResponse error(String taskId, String organismType, String errorCode, String errorMessage) {
		return new AnalysisTaskResponse(
				taskId == null ? "" : taskId,
				"error",
				null,
				errorCode == null ? "" : errorCode,
				errorMessage == null ? "" : errorMessage,
				organismType == null ? "" : organismType
		);
	}

	public static AnalysisTaskResponse fromR(String taskId, String organismType, RAnalysisResponse result) {
		if (result == null) {
			return error(taskId, organismType, "BOOT_RESULT_MISSING", "R 结果为空");
		}
		String status = result.status() == null ? "error" : result.status();
		String code = result.errorCode() == null ? "" : result.errorCode();
		String message = result.errorMessage() == null ? "" : result.errorMessage();
		return new AnalysisTaskResponse(taskId, status, result, code, message, organismType);
	}

	@JsonIgnore
	public boolean isOk() {
		return "success".equalsIgnoreCase(status) || "partial".equalsIgnoreCase(status);
	}
}
