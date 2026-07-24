package com.phylo.algorithm;

import com.phylo.model.DistanceMatrix;

import java.util.ArrayList;
import java.util.List;

/**
 * Neighbor-Joining (NJ) 邻接法建树算法
 *
 * 与UPGMA不同，NJ不假设分子钟（等速率进化），
 * 因此可以生成非等长的分支（非超度量树）。
 *
 * 算法步骤：
 * 1. 计算净散度 r_i = sum(d_ij)
 * 2. 构建 Q 矩阵: Q(i,j) = (n-2)*d(i,j) - r_i - r_j
 * 3. 找到 Q 矩阵中最小值对应的 (i,j) 对
 * 4. 计算新节点到 i, j 的分支长度
 * 5. 更新距离矩阵
 * 6. 重复直到只剩3个节点，最后用三叉树连接
 */
public class NeighborJoining {

    /**
     * 执行NJ建树，返回Newick格式字符串
     *
     * @param distanceMatrix 距离矩阵
     * @return Newick格式树
     */
    public String buildTree(DistanceMatrix distanceMatrix) {
        int n = distanceMatrix.getSize();
        if (n == 0) {
            return ";";
        }
        if (n == 1) {
            return distanceMatrix.getNames().get(0) + ";";
        }
        if (n == 2) {
            double d = distanceMatrix.getValues()[0][1];
            return "(" + distanceMatrix.getNames().get(0) + ":" + formatDouble(d / 2)
                + "," + distanceMatrix.getNames().get(1) + ":" + formatDouble(d / 2) + ");";
        }

        // 初始化标签和距离矩阵
        List<String> labels = new ArrayList<>(distanceMatrix.getNames());
        double[][] dist = new double[n][n];
        for (int i = 0; i < n; i++) {
            System.arraycopy(distanceMatrix.getValues()[i], 0, dist[i], 0, n);
        }

        List<Boolean> active = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            active.add(true);
        }
        int activeCount = n;

        while (activeCount > 3) {
            // 计算净散度 r_i
            double[] r = new double[n];
            for (int i = 0; i < n; i++) {
                if (!active.get(i)) continue;
                r[i] = 0;
                for (int j = 0; j < n; j++) {
                    if (!active.get(j) || i == j) continue;
                    r[i] += dist[i][j];
                }
            }

            // 找 Q 矩阵最小值对
            int minI = -1, minJ = -1;
            double minQ = Double.MAX_VALUE;

            for (int i = 0; i < n; i++) {
                if (!active.get(i)) continue;
                for (int j = i + 1; j < n; j++) {
                    if (!active.get(j)) continue;
                    double q = (activeCount - 2) * dist[i][j] - r[i] - r[j];
                    if (q < minQ) {
                        minQ = q;
                        minI = i;
                        minJ = j;
                    }
                }
            }

            // 计算分支长度
            double dIJ = dist[minI][minJ];
            double branchI = dIJ / 2.0 + (r[minI] - r[minJ]) / (2.0 * (activeCount - 2));
            double branchJ = dIJ - branchI;

            // 确保分支长度非负
            if (branchI < 0) branchI = 0;
            if (branchJ < 0) branchJ = 0;

            // 合并标签
            String newLabel = "(" + labels.get(minI) + ":" + formatDouble(branchI)
                + "," + labels.get(minJ) + ":" + formatDouble(branchJ) + ")";

            // 更新距离矩阵
            for (int k = 0; k < n; k++) {
                if (!active.get(k) || k == minI || k == minJ) continue;
                double newDist = (dist[minI][k] + dist[minJ][k] - dIJ) / 2.0;
                if (newDist < 0) newDist = 0;
                dist[minI][k] = newDist;
                dist[k][minI] = newDist;
            }

            // 更新状态
            labels.set(minI, newLabel);
            active.set(minJ, false);
            activeCount--;
        }

        // 最后3个节点：构建三叉树
        List<Integer> remaining = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            if (active.get(i)) remaining.add(i);
        }

        int a = remaining.get(0);
        int b = remaining.get(1);
        int c = remaining.get(2);

        double dAB = dist[a][b];
        double dAC = dist[a][c];
        double dBC = dist[b][c];

        // 计算三叉树各分支长度
        double branchA = (dAB + dAC - dBC) / 2.0;
        double branchB = (dAB + dBC - dAC) / 2.0;
        double branchC = (dAC + dBC - dAB) / 2.0;

        if (branchA < 0) branchA = 0;
        if (branchB < 0) branchB = 0;
        if (branchC < 0) branchC = 0;

        return "(" + labels.get(a) + ":" + formatDouble(branchA)
            + "," + labels.get(b) + ":" + formatDouble(branchB)
            + "," + labels.get(c) + ":" + formatDouble(branchC) + ");";
    }

    /**
     * 格式化距离数值（保留4位小数，去掉尾部0）
     */
    private String formatDouble(double value) {
        if (value == 0.0) return "0";
        String s = String.format("%.4f", value);
        s = s.replaceAll("0+$", "");
        if (s.endsWith(".")) {
            s = s.substring(0, s.length() - 1);
        }
        return s;
    }
}
