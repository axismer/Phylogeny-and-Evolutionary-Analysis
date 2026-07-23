package com.phylo.platform.model;

import java.util.List;
import java.util.Objects;

/**
 * UPGMA 生成的有根系统发育树。
 */
public record PhylogeneticTree(
		TreeNode root,
		List<String> taxonLabels
) {
	public PhylogeneticTree {
		Objects.requireNonNull(root, "root");
		Objects.requireNonNull(taxonLabels, "taxonLabels");
		taxonLabels = List.copyOf(taxonLabels);
	}

	public int leafCount() {
		return taxonLabels.size();
	}
}
