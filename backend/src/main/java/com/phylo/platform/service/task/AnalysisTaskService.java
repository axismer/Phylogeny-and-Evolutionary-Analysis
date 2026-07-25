package com.phylo.platform.service.task;

import org.springframework.web.multipart.MultipartFile;

import com.phylo.platform.dto.AnalysisTaskResponse;

/**
 * 分析任务生命周期（同步）：创建目录 → 落盘 → 调用 R Framework → 读结果。
 */
public interface AnalysisTaskService {

	/**
	 * 创建任务并同步执行分析。
	 *
	 * @param organismType 生物类型（multipart {@code type}）
	 * @param fasta FASTA 上传（必填）
	 * @param metadata metadata CSV（可选；部分类型 R 侧强制要求）
	 */
	AnalysisTaskResponse createAndRun(String organismType, MultipartFile fasta, MultipartFile metadata);

	/**
	 * 按 taskId 读取已持久化的任务状态与结果。
	 */
	AnalysisTaskResponse getTask(String taskId);
}
