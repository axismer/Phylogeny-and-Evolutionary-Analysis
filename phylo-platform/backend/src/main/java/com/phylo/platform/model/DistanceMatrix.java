package com.phylo.platform.model;

import java.util.List;
import java.util.Objects;

/**
 * p-distance 距离矩阵结果。
 * <p>
 * 对角线为 0，且矩阵对称（{@code values[i][j] == values[j][i]}）。
 */
public record DistanceMatrix(
		List<String> labels,
		double[][] values
) {
	public DistanceMatrix {
		Objects.requireNonNull(labels, "labels");
		Objects.requireNonNull(values, "values");
		if (labels.size() != values.length) {
			throw new IllegalArgumentException(
					"labels 数量与矩阵行数不一致: " + labels.size() + " vs " + values.length);
		}
		for (int i = 0; i < values.length; i++) {
			if (values[i] == null || values[i].length != values.length) {
				throw new IllegalArgumentException("距离矩阵必须为方阵");
			}
		}
		labels = List.copyOf(labels);
	}

	public int size() {
		return labels.size();
	}
}
