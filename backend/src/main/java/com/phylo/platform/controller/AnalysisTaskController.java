package com.phylo.platform.controller;

import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import com.phylo.platform.dto.AnalysisTaskResponse;
import com.phylo.platform.service.task.AnalysisTaskService;

/**
 * 分析任务 API（v0.4.2-A 同步模式）。
 * <p>
 * {@code POST /api/tasks}：multipart 上传 → 落盘 → 同步调用 R → 返回结果。<br>
 * {@code GET /api/tasks/{taskId}}：读取任务状态与结果。
 */
@RestController
@RequestMapping("/api/tasks")
public class AnalysisTaskController {

	private final AnalysisTaskService analysisTaskService;

	public AnalysisTaskController(AnalysisTaskService analysisTaskService) {
		this.analysisTaskService = analysisTaskService;
	}

	/**
	 * multipart 字段：{@code type}、{@code fasta}、可选 {@code metadata}。
	 */
	@PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
	public ResponseEntity<AnalysisTaskResponse> create(
			@RequestParam(value = "type", required = false) String type,
			@RequestParam(value = "fasta", required = false) MultipartFile fasta,
			@RequestParam(value = "metadata", required = false) MultipartFile metadata
	) {
		AnalysisTaskResponse response = analysisTaskService.createAndRun(type, fasta, metadata);
		return ResponseEntity.status(httpStatusFor(response)).body(response);
	}

	@GetMapping("/{taskId}")
	public ResponseEntity<AnalysisTaskResponse> get(@PathVariable("taskId") String taskId) {
		AnalysisTaskResponse response = analysisTaskService.getTask(taskId);
		return ResponseEntity.status(httpStatusFor(response)).body(response);
	}

	private static HttpStatus httpStatusFor(AnalysisTaskResponse response) {
		if (response == null) {
			return HttpStatus.UNPROCESSABLE_ENTITY;
		}
		if (response.isOk() || "CREATED".equalsIgnoreCase(response.status())) {
			return HttpStatus.OK;
		}
		if ("not_implemented".equalsIgnoreCase(response.status())) {
			return HttpStatus.NOT_IMPLEMENTED;
		}
		String code = response.errorCode() == null ? "" : response.errorCode();
		return switch (code) {
			case "INVALID_REQUEST", "EMPTY_FASTA", "INVALID_FILE_TYPE", "PATH_SECURITY_VIOLATION" ->
					HttpStatus.BAD_REQUEST;
			case "TASK_NOT_FOUND" -> HttpStatus.NOT_FOUND;
			case "TASK_DIR_CONFLICT" -> HttpStatus.CONFLICT;
			default -> HttpStatus.UNPROCESSABLE_ENTITY;
		};
	}
}
