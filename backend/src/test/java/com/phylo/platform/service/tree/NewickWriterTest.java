package com.phylo.platform.service.tree;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

import com.phylo.platform.model.PhylogeneticTree;
import com.phylo.platform.model.TreeNode;

import java.util.List;

class NewickWriterTest {

	private final NewickWriter writer = new NewickWriter();

	@Test
	void writesRootWithoutBranchLength() {
		TreeNode a = TreeNode.leaf("A");
		TreeNode b = TreeNode.leaf("B");
		TreeNode ab = TreeNode.internal(a, b, 0.1);
		TreeNode c = TreeNode.leaf("C");
		TreeNode root = TreeNode.internal(ab, c, 0.3);

		PhylogeneticTree tree = new PhylogeneticTree(root, List.of("A", "B", "C"));
		assertEquals("((A:0.1,B:0.1):0.2,C:0.3);", writer.toNewick(tree));
	}

	@Test
	void quotesLabelsWithSpaces() {
		TreeNode a = TreeNode.leaf("Bacillus subtilis");
		TreeNode b = TreeNode.leaf("E.coli");
		TreeNode root = TreeNode.internal(a, b, 0.2);

		PhylogeneticTree tree = new PhylogeneticTree(root, List.of("Bacillus subtilis", "E.coli"));
		assertEquals("('Bacillus subtilis':0.2,E.coli:0.2);", writer.toNewick(tree));
	}
}
