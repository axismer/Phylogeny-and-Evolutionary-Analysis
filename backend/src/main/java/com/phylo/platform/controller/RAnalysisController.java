package com.phylo.platform.controller;

import java.nio.file.Path;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.phylo.platform.dto.RAnalysisRequest;
import com.phylo.platform.dto.RAnalysisResponse;
import com.phylo.platform.service.r.RPhylogeneticAnalysisService;

/**
 * Spring Boot → R Framework（{@code runners/run_analysis.R}）→ analysis_result.json。
 * <p>
 * 保留 {@code POST /api/r-analysis/run}；业务结果统一为
 * {@code status} / {@code error_code} / {@code error_message}，避免裸 500。
 */
@RestController
@RequestMapping("/api/r-analysis")
public class RAnalysisController {

	private final RPhylogeneticAnalysisService rAnalysisService;

	public RAnalysisController(RPhylogeneticAnalysisService rAnalysisService) {
		this.rAnalysisService = rAnalysisService;
	}

	/**
	 * 请求体示例：
	 * <pre>
	 * {
	 *   "organismType": "bacteria",
	 *   "fastaPath": ".../sequences.fasta",
	 *   "metadataPath": ".../metadata.csv",
	 *   "outputDir": ".../r-analysis/output/tasks/demo"
	 * }
	 * </pre>
	 * 旧调用仅传 {@code fastaPath}/{@code outputDir} 时，默认 {@code organismType=virus}。
	 */
	@PostMapping("/run")
	public ResponseEntity<RAnalysisResponse> run(@RequestBody(required = false) RAnalysisRequest request) {
		if (request == null) {
			return ResponseEntity.status(HttpStatus.BAD_REQUEST)
					.body(RAnalysisResponse.error("INVALID_REQUEST", "请求体不能为空"));
		}
		if (request.fastaPath() == null || request.fastaPath().isBlank()) {
			return ResponseEntity.status(HttpStatus.BAD_REQUEST)
					.body(RAnalysisResponse.error("INVALID_REQUEST", "fastaPath 不能为空"));
		}
		if (request.outputDir() == null || request.outputDir().isBlank()) {
			return ResponseEntity.status(HttpStatus.BAD_REQUEST)
					.body(RAnalysisResponse.error("INVALID_REQUEST", "outputDir 不能为空"));
		}

		String organismType = request.organismType() == null || request.organismType().isBlank()
				? "virus"
				: request.organismType().trim();
		Path metadata = request.metadataPath() == null || request.metadataPath().isBlank()
				? null
				: Path.of(request.metadataPath());

		RAnalysisResponse result = rAnalysisService.analyze(
				organismType,
				Path.of(request.fastaPath()),
				metadata,
				Path.of(request.outputDir())
		);
		return ResponseEntity.status(httpStatusFor(result)).body(result);
	}

	private static HttpStatus httpStatusFor(RAnalysisResponse result) {
		if (result == null) {
			return HttpStatus.UNPROCESSABLE_ENTITY;
		}
		if (result.isOk()) {
			return HttpStatus.OK;
		}
		if ("not_implemented".equalsIgnoreCase(result.status())) {
			return HttpStatus.NOT_IMPLEMENTED;
		}
		if ("INVALID_REQUEST".equals(result.errorCode())) {
			return HttpStatus.BAD_REQUEST;
		}
		// 业务错误（含 R exit=1、Boot 兜底）→ 422，带完整 error_code / error_message
		return HttpStatus.UNPROCESSABLE_ENTITY;
	}
}
