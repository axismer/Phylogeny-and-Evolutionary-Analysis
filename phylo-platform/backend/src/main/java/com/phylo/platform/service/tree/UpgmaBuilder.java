package com.phylo.platform.service.tree;

import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

import org.springframework.stereotype.Component;

import com.phylo.platform.model.DistanceMatrix;
import com.phylo.platform.model.PhylogeneticTree;
import com.phylo.platform.model.TreeNode;

/**
 * UPGMA：反复合并最近簇，用算术平均更新距离，直到形成有根树。
 */
@Component
public class UpgmaBuilder {

	public PhylogeneticTree build(DistanceMatrix matrix) {
		Objects.requireNonNull(matrix, "matrix");
		int n = matrix.size();
		if (n < 2) {
			throw new IllegalArgumentException("至少需要 2 个物种才能建树，当前: " + n);
		}

		List<String> labels = matrix.labels();
		List<Cluster> active = new ArrayList<>(n);
		for (int i = 0; i < n; i++) {
			active.add(new Cluster(TreeNode.leaf(labels.get(i)), i));
		}

		// 可变距离表，按原始下标索引；合并后用新下标扩展
		List<List<Double>> dist = new ArrayList<>(n);
		for (int i = 0; i < n; i++) {
			List<Double> row = new ArrayList<>(n);
			for (int j = 0; j < n; j++) {
				row.add(matrix.values()[i][j]);
			}
			dist.add(row);
		}

		int nextId = n;
		while (active.size() > 1) {
			int bestI = -1;
			int bestJ = -1;
			double bestD = Double.POSITIVE_INFINITY;

			for (int a = 0; a < active.size(); a++) {
				for (int b = a + 1; b < active.size(); b++) {
					double d = distanceBetween(dist, active.get(a).id, active.get(b).id);
					if (d < bestD - 1e-15 || (almostEqual(d, bestD) && (bestI < 0
							|| active.get(a).id < active.get(bestI).id
							|| (active.get(a).id == active.get(bestI).id && active.get(b).id < active.get(bestJ).id)))) {
						bestD = d;
						bestI = a;
						bestJ = b;
					}
				}
			}

			Cluster ci = active.get(bestI);
			Cluster cj = active.get(bestJ);
			double height = bestD / 2.0;
			// 较大簇在左；同大小时较小 id 在左，保证输出可复现
			TreeNode leftChild;
			TreeNode rightChild;
			if (ci.node.getSize() > cj.node.getSize()
					|| (ci.node.getSize() == cj.node.getSize() && ci.id < cj.id)) {
				leftChild = ci.node;
				rightChild = cj.node;
			} else {
				leftChild = cj.node;
				rightChild = ci.node;
			}
			TreeNode parent = TreeNode.internal(leftChild, rightChild, height);
			Cluster merged = new Cluster(parent, nextId);

			// 扩展距离表
			ensureSize(dist, nextId + 1);
			for (int a = 0; a < active.size(); a++) {
				if (a == bestI || a == bestJ) {
					continue;
				}
				Cluster ck = active.get(a);
				double dik = distanceBetween(dist, ci.id, ck.id);
				double djk = distanceBetween(dist, cj.id, ck.id);
				double duk = (ci.node.getSize() * dik + cj.node.getSize() * djk)
						/ (double) (ci.node.getSize() + cj.node.getSize());
				setDistance(dist, merged.id, ck.id, duk);
			}
			setDistance(dist, merged.id, merged.id, 0.0);

			// 先移除较大下标，避免错位
			if (bestI > bestJ) {
				active.remove(bestI);
				active.remove(bestJ);
			} else {
				active.remove(bestJ);
				active.remove(bestI);
			}
			active.add(merged);
			nextId++;
		}

		return new PhylogeneticTree(active.get(0).node, labels);
	}

	private static double distanceBetween(List<List<Double>> dist, int i, int j) {
		return dist.get(i).get(j);
	}

	private static void setDistance(List<List<Double>> dist, int i, int j, double value) {
		dist.get(i).set(j, value);
		dist.get(j).set(i, value);
	}

	private static void ensureSize(List<List<Double>> dist, int size) {
		while (dist.size() < size) {
			List<Double> row = new ArrayList<>(size);
			for (int k = 0; k < size; k++) {
				row.add(0.0);
			}
			dist.add(row);
		}
		for (List<Double> row : dist) {
			while (row.size() < size) {
				row.add(0.0);
			}
		}
	}

	private static boolean almostEqual(double a, double b) {
		return Math.abs(a - b) <= 1e-15;
	}

	private static final class Cluster {
		final TreeNode node;
		final int id;

		Cluster(TreeNode node, int id) {
			this.node = node;
			this.id = id;
		}
	}
}
