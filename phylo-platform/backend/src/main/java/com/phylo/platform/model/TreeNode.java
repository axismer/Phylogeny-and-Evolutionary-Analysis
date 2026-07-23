package com.phylo.platform.model;

/**
 * UPGMA 二叉树节点（叶或内部合并节点）。
 * <p>
 * {@code branchLength} 表示到父节点的边长，应由 {@code parent.height - this.height} 计算并保持一致。
 */
public class TreeNode {

	private final String label;
	private final TreeNode left;
	private final TreeNode right;
	private final double height;
	private final int size;
	private double branchLength;

	private TreeNode(String label, TreeNode left, TreeNode right, double height, int size, double branchLength) {
		this.label = label;
		this.left = left;
		this.right = right;
		this.height = height;
		this.size = size;
		this.branchLength = branchLength;
	}

	public static TreeNode leaf(String label) {
		return new TreeNode(label, null, null, 0.0, 1, 0.0);
	}

	public static TreeNode internal(TreeNode left, TreeNode right, double height) {
		int size = left.size + right.size;
		TreeNode parent = new TreeNode(null, left, right, height, size, 0.0);
		left.setBranchLength(height - left.height);
		right.setBranchLength(height - right.height);
		return parent;
	}

	public boolean isLeaf() {
		return left == null && right == null;
	}

	public String getLabel() {
		return label;
	}

	public TreeNode getLeft() {
		return left;
	}

	public TreeNode getRight() {
		return right;
	}

	public double getHeight() {
		return height;
	}

	public int getSize() {
		return size;
	}

	public double getBranchLength() {
		return branchLength;
	}

	public void setBranchLength(double branchLength) {
		this.branchLength = branchLength;
	}
}
