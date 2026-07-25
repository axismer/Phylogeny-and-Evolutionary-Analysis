package com.phylo.platform.service.tree;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;

import java.util.List;

import org.junit.jupiter.api.Test;

import com.phylo.platform.model.DistanceMatrix;
import com.phylo.platform.model.PhylogeneticTree;
import com.phylo.platform.model.TreeNode;

class UpgmaBuilderTest {

	private final UpgmaBuilder builder = new UpgmaBuilder();
	private final NewickWriter newickWriter = new NewickWriter();

	/**
	 * 手工矩阵：A-B=0.2，A-C=B-C=0.6。
	 * 先合并 A,B（height=0.1），再与 C 合并（height=0.3）。
	 */
	@Test
	void threeTaxaHandMatrix_upgmaTopologyAndHeights() {
		DistanceMatrix matrix = new DistanceMatrix(
				List.of("A", "B", "C"),
				new double[][] {
						{0.0, 0.2, 0.6},
						{0.2, 0.0, 0.6},
						{0.6, 0.6, 0.0}
				}
		);

		PhylogeneticTree tree = builder.build(matrix);
		TreeNode root = tree.root();

		assertFalse(root.isLeaf());
		assertEquals(0.3, root.getHeight(), 1e-12);

		TreeNode ab = root.getLeft();
		TreeNode c = root.getRight();
		assertEquals("C", c.getLabel());
		assertEquals(0.3, c.getBranchLength(), 1e-12);

		assertFalse(ab.isLeaf());
		assertEquals(0.1, ab.getHeight(), 1e-12);
		assertEquals(0.2, ab.getBranchLength(), 1e-12);

		assertEquals("A", ab.getLeft().getLabel());
		assertEquals("B", ab.getRight().getLabel());
		assertEquals(0.1, ab.getLeft().getBranchLength(), 1e-12);
		assertEquals(0.1, ab.getRight().getBranchLength(), 1e-12);

		assertEquals(0.1, ab.getHeight() - ab.getLeft().getHeight(), 1e-12);
		assertEquals(0.2, root.getHeight() - ab.getHeight(), 1e-12);
	}

	@Test
	void threeTaxa_newickOutput() {
		DistanceMatrix matrix = new DistanceMatrix(
				List.of("A", "B", "C"),
				new double[][] {
						{0.0, 0.2, 0.6},
						{0.2, 0.0, 0.6},
						{0.6, 0.6, 0.0}
				}
		);
		PhylogeneticTree tree = builder.build(matrix);
		assertEquals("((A:0.1,B:0.1):0.2,C:0.3);", newickWriter.toNewick(tree));
	}
}
