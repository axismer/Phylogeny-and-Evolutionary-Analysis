package com.phylo.platform.dto;

public record FastaRecordSummary(
		String sourceFile,
		int index,
		String speciesName,
		String header,
		int length
) {
}
