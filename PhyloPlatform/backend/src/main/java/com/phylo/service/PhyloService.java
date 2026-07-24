package com.phylo.service;

import com.phylo.algorithm.FastaParser;
import com.phylo.algorithm.KmerDistance;
import com.phylo.algorithm.NeighborJoining;
import com.phylo.algorithm.PDistance;
import com.phylo.algorithm.UPGMA;
import com.phylo.model.AnalysisResult;
import com.phylo.model.DistanceMatrix;
import com.phylo.model.Sequence;
import org.springframework.stereotype.Service;

import java.util.*;
import java.util.stream.Collectors;

/**
 * 系统发育分析服务 - 业务流程控制
 * 
 * 支持：
 * 1. 单文件多序列分析
 * 2. 多文件比对（每个文件选最优序列）
 * 3. PCoA 坐标计算
 */
@Service
public class PhyloService {

    private final FastaParser fastaParser = new FastaParser();
    private final PDistance pDistance = new PDistance();
    private final KmerDistance kmerDistance = new KmerDistance();
    private final UPGMA upgma = new UPGMA();
    private final NeighborJoining nj = new NeighborJoining();

    /**
     * 执行完整的系统发育分析（默认UPGMA）
     */
    public AnalysisResult analyze(String fastaContent) {
        return analyze(fastaContent, "upgma");
    }

    /**
     * 执行完整的系统发育分析
     */
    public AnalysisResult analyze(String fastaContent, String method) {
        List<Sequence> sequences = fastaParser.parse(fastaContent);

        if (sequences.isEmpty()) {
            throw new IllegalArgumentException("未能从文件中解析到任何序列，请检查FASTA格式");
        }
        if (sequences.size() < 2) {
            throw new IllegalArgumentException("至少需要2条序列才能进行系统发育分析");
        }

        return doAnalysis(sequences, method);
    }

    /**
     * 多文件比对分析 - 每个文件（物种）选择最优序列进行比对
     * 
     * @param fileContents Map<物种名, FASTA内容>
     * @param method 建树方法
     * @return 分析结果
     */
    public AnalysisResult analyzeMultiFiles(Map<String, String> fileContents, String method) {
        if (fileContents == null || fileContents.size() < 2) {
            throw new IllegalArgumentException("至少需要2个物种文件才能进行系统发育分析");
        }

        List<Sequence> bestSequences = new ArrayList<>();
        List<String> selectionInfo = new ArrayList<>();

        for (Map.Entry<String, String> entry : fileContents.entrySet()) {
            String speciesName = entry.getKey();
            String fastaContent = entry.getValue();

            List<Sequence> sequences = fastaParser.parse(fastaContent);
            if (sequences.isEmpty()) {
                throw new IllegalArgumentException("物种 [" + speciesName + "] 文件中未解析到序列");
            }

            // 选择最优序列（最长且不含过多N的序列）
            Sequence best = selectBestSequence(sequences);
            // 重命名为物种名
            best.setName(speciesName);
            bestSequences.add(best);
            selectionInfo.add(speciesName + ": 选择了 " + best.getLength() + " bp 的序列");
        }

        AnalysisResult result = doAnalysis(bestSequences, method);
        result.setSelectionInfo(selectionInfo);
        return result;
    }

    /**
     * 执行核心分析流程
     */
    private AnalysisResult doAnalysis(List<Sequence> sequences, String method) {
        boolean equalLength = checkEqualLength(sequences);
        DistanceMatrix distanceMatrix;
        String distanceMethod;

        if (equalLength) {
            distanceMatrix = pDistance.calculateMatrix(sequences);
            distanceMethod = "p-distance";
        } else {
            distanceMatrix = kmerDistance.calculateMatrix(sequences);
            distanceMethod = "k-mer distance (k=3)";
        }

        String newickTree;
        String usedMethod;
        if ("nj".equalsIgnoreCase(method)) {
            newickTree = nj.buildTree(distanceMatrix);
            usedMethod = "Neighbor-Joining (NJ) + " + distanceMethod;
        } else {
            newickTree = upgma.buildTree(distanceMatrix);
            usedMethod = "UPGMA + " + distanceMethod;
        }

        // 计算PCoA坐标
        double[][] pcoaCoords = calculatePCoA(distanceMatrix.getValues(), 2);

        List<AnalysisResult.SequenceInfo> seqInfos = sequences.stream()
            .map(seq -> new AnalysisResult.SequenceInfo(seq.getName(), seq.getLength()))
            .collect(Collectors.toList());

        AnalysisResult result = new AnalysisResult(seqInfos, distanceMatrix, newickTree, usedMethod);
        result.setPcoaCoordinates(pcoaCoords);
        return result;
    }

    /**
     * 选择最优序列：优先选最长的、含N最少的序列
     */
    private Sequence selectBestSequence(List<Sequence> sequences) {
        if (sequences.size() == 1) return sequences.get(0);

        return sequences.stream()
            .max(Comparator.comparingInt((Sequence s) -> s.getLength())
                .thenComparing(Comparator.comparingLong((Sequence s) -> 
                    s.getSequence().chars().filter(c -> c == 'N' || c == 'n').count()).reversed()))
            .orElse(sequences.get(0));
    }

    /**
     * PCoA (Principal Coordinates Analysis) 计算
     * 使用经典多维缩放（Classical MDS）方法
     */
    private double[][] calculatePCoA(double[][] distMatrix, int dimensions) {
        int n = distMatrix.length;
        if (n <= dimensions) {
            dimensions = Math.max(1, n - 1);
        }

        // Step 1: 计算双中心化矩阵 B = -0.5 * J * D^2 * J
        double[][] dSquared = new double[n][n];
        for (int i = 0; i < n; i++) {
            for (int j = 0; j < n; j++) {
                dSquared[i][j] = distMatrix[i][j] * distMatrix[i][j];
            }
        }

        // 计算行均值和总均值
        double[] rowMeans = new double[n];
        double grandMean = 0;
        for (int i = 0; i < n; i++) {
            for (int j = 0; j < n; j++) {
                rowMeans[i] += dSquared[i][j];
            }
            rowMeans[i] /= n;
            grandMean += rowMeans[i];
        }
        grandMean /= n;

        double[] colMeans = new double[n];
        for (int j = 0; j < n; j++) {
            for (int i = 0; i < n; i++) {
                colMeans[j] += dSquared[i][j];
            }
            colMeans[j] /= n;
        }

        // 双中心化
        double[][] B = new double[n][n];
        for (int i = 0; i < n; i++) {
            for (int j = 0; j < n; j++) {
                B[i][j] = -0.5 * (dSquared[i][j] - rowMeans[i] - colMeans[j] + grandMean);
            }
        }

        // Step 2: 幂迭代法求前几个特征向量
        double[][] coords = new double[n][dimensions];
        double[][] Bwork = new double[n][n];
        for (int i = 0; i < n; i++) {
            System.arraycopy(B[i], 0, Bwork[i], 0, n);
        }

        for (int d = 0; d < dimensions; d++) {
            // 幂迭代求最大特征值对应的特征向量
            double[] vec = new double[n];
            Arrays.fill(vec, 1.0 / Math.sqrt(n));

            double eigenvalue = 0;
            for (int iter = 0; iter < 100; iter++) {
                double[] newVec = new double[n];
                for (int i = 0; i < n; i++) {
                    for (int j = 0; j < n; j++) {
                        newVec[i] += Bwork[i][j] * vec[j];
                    }
                }
                double norm = 0;
                for (int i = 0; i < n; i++) norm += newVec[i] * newVec[i];
                norm = Math.sqrt(norm);
                if (norm < 1e-10) break;
                eigenvalue = norm;
                for (int i = 0; i < n; i++) vec[i] = newVec[i] / norm;
            }

            // 坐标 = 特征向量 * sqrt(特征值)
            double scale = Math.sqrt(Math.max(eigenvalue, 0));
            for (int i = 0; i < n; i++) {
                coords[i][d] = vec[i] * scale;
            }

            // 去除已提取的成分 (deflation)
            for (int i = 0; i < n; i++) {
                for (int j = 0; j < n; j++) {
                    Bwork[i][j] -= eigenvalue * vec[i] * vec[j];
                }
            }
        }

        return coords;
    }

    /**
     * 检查所有序列是否等长
     */
    private boolean checkEqualLength(List<Sequence> sequences) {
        int expectedLength = sequences.get(0).getLength();
        for (int i = 1; i < sequences.size(); i++) {
            if (sequences.get(i).getLength() != expectedLength) {
                return false;
            }
        }
        return true;
    }
}
