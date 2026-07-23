package com.phylo.platform.service.matrix;

import java.util.List;
import java.util.Objects;

import org.springframework.stereotype.Component;

import com.phylo.platform.model.DistanceMatrix;

/**
 * 计算两条（或多条）DNA 序列之间的 p-distance。
 * <p>
 * 公式：{@code distance = 不同碱基数量 / 可比较位置数量}。
 */
@Component
public class PDistanceCalculator {

	/**
	 * 计算两条等长序列的 p-distance。
	 * <ul>
	 *   <li>A/T/C/G 正常比较（忽略大小写）</li>
	 *   <li>遇到 N 或其它非 ATCG 字符时跳过该位点</li>
	 *   <li>无有效比较位点时抛出异常</li>
	 * </ul>
	 */
	public double pDistance(String seqA, String seqB) {
		Objects.requireNonNull(seqA, "seqA");
		Objects.requireNonNull(seqB, "seqB");
		if (seqA.length() != seqB.length()) {
			throw new IllegalArgumentException(
					"序列长度必须一致才能计算 p-distance: " + seqA.length() + " vs " + seqB.length());
		}

		int comparable = 0;
		int differences = 0;
		int n = seqA.length();
		for (int i = 0; i < n; i++) {
			char a = Character.toUpperCase(seqA.charAt(i));
			char b = Character.toUpperCase(seqB.charAt(i));
			if (!isComparableBase(a) || !isComparableBase(b)) {
				continue;
			}
			comparable++;
			if (a != b) {
				differences++;
			}
		}

		if (comparable == 0) {
			throw new IllegalArgumentException("无有效比较位置，无法计算 p-distance");
		}
		return (double) differences / comparable;
	}

	/**
	 * 根据多个等长序列生成对称距离矩阵（对角线为 0）。
	 */
	public DistanceMatrix buildMatrix(List<String> labels, List<String> sequences) {
		Objects.requireNonNull(labels, "labels");
		Objects.requireNonNull(sequences, "sequences");
		if (labels.size() != sequences.size()) {
			throw new IllegalArgumentException(
					"labels 与 sequences 数量不一致: " + labels.size() + " vs " + sequences.size());
		}
		if (labels.isEmpty()) {
			throw new IllegalArgumentException("至少需要一条序列才能构建距离矩阵");
		}

		int n = sequences.size();
		double[][] values = new double[n][n];
		for (int i = 0; i < n; i++) {
			values[i][i] = 0.0;
			for (int j = i + 1; j < n; j++) {
				double d = pDistance(sequences.get(i), sequences.get(j));
				values[i][j] = d;
				values[j][i] = d;
			}
		}
		return new DistanceMatrix(labels, values);
	}

	private static boolean isComparableBase(char c) {
		return c == 'A' || c == 'T' || c == 'C' || c == 'G';
	}
}
