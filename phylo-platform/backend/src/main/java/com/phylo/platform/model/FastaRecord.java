package com.phylo.platform.model;

/**
 * 从单个 FASTA 记录解析出的序列信息。
 */
public record FastaRecord(
		String sourceFile,
		int index,
		String speciesName,
		String header,
		String sequence
) {
	public int length() {
		return sequence.length();
	}
}
