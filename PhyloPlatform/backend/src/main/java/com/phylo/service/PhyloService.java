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

import java.util.List;
import java.util.stream.Collectors;

/**
 * 系统发育分析服务 - 业务流程控制
 * 
 * 流程：
 * 1. 解析FASTA文件
 * 2. 校验序列（等长检查）
 * 3. 计算p-distance距离矩阵
 * 4. 建树（UPGMA 或 NJ）
 * 5. 组装返回结果
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
     *
     * @param fastaContent FASTA文件的文本内容
     * @return 分析结果（包含序列信息、距离矩阵、Newick树）
     */
    public AnalysisResult analyze(String fastaContent) {
        return analyze(fastaContent, "upgma");
    }

    /**
     * 执行完整的系统发育分析
     *
     * @param fastaContent FASTA文件的文本内容
     * @param method       建树方法："upgma" 或 "nj"
     * @return 分析结果（包含序列信息、距离矩阵、Newick树）
     */
    public AnalysisResult analyze(String fastaContent, String method) {
        // Step 1: 解析FASTA
        List<Sequence> sequences = fastaParser.parse(fastaContent);

        if (sequences.isEmpty()) {
            throw new IllegalArgumentException("未能从文件中解析到任何序列，请检查FASTA格式");
        }
        if (sequences.size() < 2) {
            throw new IllegalArgumentException("至少需要2条序列才能进行系统发育分析");
        }

        // Step 2: 判断序列是否等长，选择距离算法
        boolean equalLength = checkEqualLength(sequences);
        DistanceMatrix distanceMatrix;
        String distanceMethod;

        if (equalLength) {
            // 等长序列：使用 p-distance（逐位比较）
            distanceMatrix = pDistance.calculateMatrix(sequences);
            distanceMethod = "p-distance";
        } else {
            // 不等长序列：使用 k-mer 频率距离
            distanceMatrix = kmerDistance.calculateMatrix(sequences);
            distanceMethod = "k-mer distance (k=3)";
        }

        // Step 3: 建树
        String newickTree;
        String usedMethod;
        if ("nj".equalsIgnoreCase(method)) {
            newickTree = nj.buildTree(distanceMatrix);
            usedMethod = "Neighbor-Joining (NJ) + " + distanceMethod;
        } else {
            newickTree = upgma.buildTree(distanceMatrix);
            usedMethod = "UPGMA + " + distanceMethod;
        }

        // Step 4: 组装结果
        List<AnalysisResult.SequenceInfo> seqInfos = sequences.stream()
            .map(seq -> new AnalysisResult.SequenceInfo(seq.getName(), seq.getLength()))
            .collect(Collectors.toList());

        return new AnalysisResult(seqInfos, distanceMatrix, newickTree, usedMethod);
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
