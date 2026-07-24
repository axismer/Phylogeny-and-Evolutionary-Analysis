package com.phylo.algorithm;

import com.phylo.model.DistanceMatrix;
import com.phylo.model.Sequence;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * K-mer 频率距离计算（支持不等长序列）
 *
 * 原理：
 * 1. 将每条序列拆分为所有长度为 k 的子串（k-mer）
 * 2. 统计每条序列的 k-mer 频率向量
 * 3. 用欧氏距离或余弦距离衡量两条序列的相似性
 *
 * 适用场景：序列长度不一致，无法逐位比较时使用
 */
public class KmerDistance {

    /** 默认 k 值 */
    private static final int DEFAULT_K = 3;

    private final int k;

    public KmerDistance() {
        this.k = DEFAULT_K;
    }

    public KmerDistance(int k) {
        if (k < 1) {
            throw new IllegalArgumentException("k 值必须 >= 1");
        }
        this.k = k;
    }

    /**
     * 计算两条序列之间的 k-mer 频率距离（归一化欧氏距离）
     *
     * @param seq1 序列1
     * @param seq2 序列2
     * @return 距离值 (0.0 ~ 1.0)
     */
    public double calculate(String seq1, String seq2) {
        if (seq1 == null || seq2 == null) {
            throw new IllegalArgumentException("序列不能为空");
        }
        if (seq1.isEmpty() && seq2.isEmpty()) {
            return 0.0;
        }
        if (seq1.isEmpty() || seq2.isEmpty()) {
            return 1.0;
        }

        Map<String, Double> freq1 = getKmerFrequency(seq1);
        Map<String, Double> freq2 = getKmerFrequency(seq2);

        // 计算归一化欧氏距离
        return normalizedEuclideanDistance(freq1, freq2);
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

        // 预先计算所有序列的 k-mer 频率
        @SuppressWarnings("unchecked")
        Map<String, Double>[] frequencies = new HashMap[n];
        for (int i = 0; i < n; i++) {
            frequencies[i] = getKmerFrequency(sequences.get(i).getSequence());
        }

        for (int i = 0; i < n; i++) {
            for (int j = i + 1; j < n; j++) {
                double dist = normalizedEuclideanDistance(frequencies[i], frequencies[j]);
                matrix[i][j] = dist;
                matrix[j][i] = dist;
            }
            matrix[i][i] = 0.0;
        }

        List<String> names = sequences.stream()
            .map(Sequence::getName)
            .collect(Collectors.toList());

        return new DistanceMatrix(names, matrix);
    }

    /**
     * 统计序列中所有 k-mer 的频率（归一化）
     */
    private Map<String, Double> getKmerFrequency(String sequence) {
        Map<String, Integer> counts = new HashMap<>();
        String seq = sequence.toUpperCase();
        int totalKmers = seq.length() - k + 1;

        if (totalKmers <= 0) {
            // 序列长度小于 k，将整条序列作为一个 k-mer
            counts.put(seq, 1);
            totalKmers = 1;
        } else {
            for (int i = 0; i <= seq.length() - k; i++) {
                String kmer = seq.substring(i, i + k);
                counts.merge(kmer, 1, Integer::sum);
            }
        }

        // 归一化为频率
        Map<String, Double> frequency = new HashMap<>();
        for (Map.Entry<String, Integer> entry : counts.entrySet()) {
            frequency.put(entry.getKey(), (double) entry.getValue() / totalKmers);
        }
        return frequency;
    }

    /**
     * 计算两个频率向量之间的归一化欧氏距离
     * 结果范围 [0, 1]：0 表示完全相同，1 表示完全不同
     */
    private double normalizedEuclideanDistance(Map<String, Double> freq1, Map<String, Double> freq2) {
        // 收集所有出现过的 k-mer
        Map<String, Double> allKeys = new HashMap<>(freq1);
        allKeys.putAll(freq2);

        double sumSquaredDiff = 0.0;
        for (String key : allKeys.keySet()) {
            double v1 = freq1.getOrDefault(key, 0.0);
            double v2 = freq2.getOrDefault(key, 0.0);
            double diff = v1 - v2;
            sumSquaredDiff += diff * diff;
        }

        double euclidean = Math.sqrt(sumSquaredDiff);

        // 归一化：最大可能距离为 sqrt(2)（两个完全不同的频率向量）
        return Math.min(euclidean / Math.sqrt(2.0), 1.0);
    }

    public int getK() {
        return k;
    }
}
