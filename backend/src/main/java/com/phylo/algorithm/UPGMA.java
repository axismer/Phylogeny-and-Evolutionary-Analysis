package com.phylo.algorithm;

import com.phylo.model.DistanceMatrix;

import java.util.ArrayList;
import java.util.List;

/**
 * UPGMA (Unweighted Pair Group Method with Arithmetic Mean) 算法
 * 
 * 输入：距离矩阵
 * 输出：Newick格式的系统发育树
 * 
 * 算法步骤：
 * 1. 找到距离矩阵中最小距离的一对
 * 2. 合并为一个新节点
 * 3. 更新距离矩阵（取算术平均）
 * 4. 重复直到只剩一个节点
 */
public class UPGMA {

    /**
     * 执行UPGMA建树，返回Newick格式字符串
     *
     * @param distanceMatrix 距离矩阵
     * @return Newick格式树，例如 "((A:0.1,B:0.1):0.15,C:0.25);"
     */
    public String buildTree(DistanceMatrix distanceMatrix) {
        int n = distanceMatrix.getSize();
        if (n == 0) {
            return ";";
        }
        if (n == 1) {
            return distanceMatrix.getNames().get(0) + ";";
        }

        // 初始化：每个物种是一个独立的簇
        List<String> labels = new ArrayList<>(distanceMatrix.getNames());
        List<Integer> clusterSizes = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            clusterSizes.add(1);
        }

        // 复制距离矩阵（可变）
        double[][] dist = new double[n][n];
        for (int i = 0; i < n; i++) {
            System.arraycopy(distanceMatrix.getValues()[i], 0, dist[i], 0, n);
        }

        // 记录每个节点的高度（到叶子的距离）
        double[] heights = new double[n];

        int activeCount = n;
        List<Boolean> active = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            active.add(true);
        }

        while (activeCount > 1) {
            // Step 1: 找到最小距离的一对
            int minI = -1, minJ = -1;
            double minDist = Double.MAX_VALUE;

            for (int i = 0; i < n; i++) {
                if (!active.get(i)) continue;
                for (int j = i + 1; j < n; j++) {
                    if (!active.get(j)) continue;
                    if (dist[i][j] < minDist) {
                        minDist = dist[i][j];
                        minI = i;
                        minJ = j;
                    }
                }
            }

            // Step 2: 计算新节点高度
            double newHeight = minDist / 2.0;

            // Step 3: 合并标签（Newick格式）
            String newLabel = "(" + labels.get(minI) + ":" 
                + formatDouble(newHeight - heights[minI]) + ","
                + labels.get(minJ) + ":" 
                + formatDouble(newHeight - heights[minJ]) + ")";

            // Step 4: 更新距离（加权平均）
            int sizeI = clusterSizes.get(minI);
            int sizeJ = clusterSizes.get(minJ);

            for (int k = 0; k < n; k++) {
                if (!active.get(k) || k == minI || k == minJ) continue;
                double newDist = (dist[minI][k] * sizeI + dist[minJ][k] * sizeJ) 
                                 / (sizeI + sizeJ);
                dist[minI][k] = newDist;
                dist[k][minI] = newDist;
            }

            // Step 5: 更新簇信息
            labels.set(minI, newLabel);
            clusterSizes.set(minI, sizeI + sizeJ);
            heights[minI] = newHeight;
            active.set(minJ, false);
            activeCount--;
        }

        // 找到最后活跃的节点
        for (int i = 0; i < n; i++) {
            if (active.get(i)) {
                return labels.get(i) + ";";
            }
        }

        return ";";
    }

    /**
     * 格式化距离数值（保留4位小数，去掉尾部0）
     */
    private String formatDouble(double value) {
        if (value == 0.0) return "0";
        String s = String.format("%.4f", value);
        // 去掉尾部多余的0
        s = s.replaceAll("0+$", "");
        if (s.endsWith(".")) {
            s = s.substring(0, s.length() - 1);
        }
        return s;
    }
}
