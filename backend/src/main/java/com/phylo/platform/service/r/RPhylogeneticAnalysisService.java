package com.phylo.platform.service.r;

import java.nio.file.Path;

import com.phylo.platform.dto.RAnalysisResponse;

/**
 * 通过 Rscript 调用 r-analysis Framework（{@code runners/run_analysis.R}）。
 */
public interface RPhylogeneticAnalysisService {

	/**
	 * @param organismType organism type（virus / bacteria / fungi / …）
	 * @param fastaPath 输入 FASTA
	 * @param metadataPath 可选 metadata；null 表示不传 {@code --metadata}
	 * @param outputDir 任务输出目录（写入 analysis_result.json 等）
	 * @return 始终返回结构化结果（含 error / not_implemented），不抛业务异常
	 */
	RAnalysisResponse analyze(String organismType, Path fastaPath, Path metadataPath, Path outputDir);
}
