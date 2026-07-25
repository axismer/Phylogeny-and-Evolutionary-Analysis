package com.phylo.platform.dto;

import org.springframework.web.multipart.MultipartFile;

/**
 * 创建分析任务请求（multipart 上传）。
 */
public record CreateAnalysisTaskRequest(
		String organismType,
		MultipartFile fasta,
		MultipartFile metadata
) {
}
