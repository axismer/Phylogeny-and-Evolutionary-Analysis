package com.phylo.platform.controller;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.multipart.MaxUploadSizeExceededException;
import org.springframework.web.multipart.MultipartException;

import com.phylo.platform.dto.AnalysisTaskResponse;

/**
 * 将 /api/tasks 未捕获异常统一映射为契约错误体，禁止裸 500。
 */
@RestControllerAdvice(assignableTypes = AnalysisTaskController.class)
public class AnalysisTaskExceptionHandler {

	private static final Logger log = LoggerFactory.getLogger(AnalysisTaskExceptionHandler.class);

	@ExceptionHandler(MaxUploadSizeExceededException.class)
	public ResponseEntity<AnalysisTaskResponse> handleMaxUpload(MaxUploadSizeExceededException ex) {
		return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(
				AnalysisTaskResponse.error("", "", "INVALID_REQUEST", "上传文件过大: " + safeMessage(ex))
		);
	}

	@ExceptionHandler(MultipartException.class)
	public ResponseEntity<AnalysisTaskResponse> handleMultipart(MultipartException ex) {
		return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(
				AnalysisTaskResponse.error("", "", "INVALID_REQUEST", "multipart 解析失败: " + safeMessage(ex))
		);
	}

	@ExceptionHandler(Exception.class)
	public ResponseEntity<AnalysisTaskResponse> handleUnexpected(Exception ex) {
		log.error("Unexpected error in AnalysisTaskController", ex);
		return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY).body(
				AnalysisTaskResponse.error("", "", "BOOT_PROCESS_FAILED", "任务处理失败: " + safeMessage(ex))
		);
	}

	private static String safeMessage(Throwable ex) {
		String msg = ex.getMessage();
		return msg == null || msg.isBlank() ? ex.getClass().getSimpleName() : msg;
	}
}
