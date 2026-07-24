package com.phylo.algorithm;

import com.phylo.model.DistanceMatrix;
import com.phylo.model.Sequence;

import java.util.List;
import java.util.stream.Collectors;

/**
 * p-distance 距离计算
 * 
 * p-distance = 不同位点数 / 总位点数
 * 
 * 例如：
 * A: ATCG
 * B: ATGG
 * 第3位不同 → 距离 = 1/4 = 0.25
 */
public class PDistance {

    /**
     * 计算两条序列之间的 p-distance
     *
     * @param seq1 序列1
     * @param seq2 序列2
     * @return p-distance 值 (0.0 ~ 1.0)
     */
    public double calculate(String seq1, String seq2) {
        if (seq1 == null || seq2 == null) {
            throw new IllegalArgumentException("序列不能为空");
        }
        if (seq1.length() != seq2.length()) {
            throw new IllegalArgumentException(
                "序列长度不一致: " + seq1.length() + " vs " + seq2.length());
        }
        if (seq1.isEmpty()) {
            return 0.0;
        }

        int differences = 0;
        for (int i = 0; i < seq1.length(); i++) {
            if (Character.toUpperCase(seq1.charAt(i)) != Character.toUpperCase(seq2.charAt(i))) {
                differences++;
            }
        }

        return (double) differences / seq1.length();
    }

    /**
     * 计算所有序列之间的距离矩阵
     *
     * @param sequences 序列列表
     * @return 距离矩阵
     */
    public DistanceMatrix calculateMatrix(List<Sequence> sequences) {
        int n = sequences.size();
        double[][] matrix = new double[n][n];

        for (int i = 0; i < n; i++) {
            for (int j = i + 1; j < n; j++) {
                double dist = calculate(
                    sequences.get(i).getSequence(),
                    sequences.get(j).getSequence()
                );
                matrix[i][j] = dist;
                matrix[j][i] = dist;
            }
            // 对角线为0
            matrix[i][i] = 0.0;
        }

        List<String> names = sequences.stream()
            .map(Sequence::getName)
            .collect(Collectors.toList());

        return new DistanceMatrix(names, matrix);
    }
}
