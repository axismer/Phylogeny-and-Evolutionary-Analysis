package com.phylo.platform.dto;

import com.fasterxml.jackson.annotation.JsonAlias;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * 调用 R Framework 的请求。
 * <p>
 * 兼容旧字段 {@code fastaPath}/{@code outputDir}；新增 {@code organismType}/{@code metadataPath}。
 * 未传 {@code organismType} 时服务端默认 {@code virus}。
 */
public record RAnalysisRequest(
		@JsonProperty("organismType")
		@JsonAlias("organism_type")
		String organismType,
		@JsonProperty("fastaPath")
		@JsonAlias("fasta_path")
		String fastaPath,
		@JsonProperty("metadataPath")
		@JsonAlias("metadata_path")
		String metadataPath,
		@JsonProperty("outputDir")
		@JsonAlias("output_dir")
		String outputDir
) {
}
