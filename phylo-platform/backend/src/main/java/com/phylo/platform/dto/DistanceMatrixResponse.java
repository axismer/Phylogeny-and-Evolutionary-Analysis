package com.phylo.platform.dto;

import java.util.List;

public record DistanceMatrixResponse(
		List<String> labels,
		double[][] values
) {
}
