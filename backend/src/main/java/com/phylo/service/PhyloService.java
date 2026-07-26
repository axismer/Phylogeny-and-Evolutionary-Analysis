package com.phylo.service;

import com.phylo.algorithm.FastaParser;
import com.phylo.algorithm.KmerDistance;
import com.phylo.algorithm.NeighborJoining;
import com.phylo.algorithm.PDistance;
import com.phylo.algorithm.UPGMA;
import com.phylo.model.AnalysisResult;
import com.phylo.model.DistanceMatrix;
import com.phylo.model.Sequence;
import com.phylo.model.SequenceData;
import com.phylo.repository.SequenceDataRepository;
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
    private final SequenceDataRepository sequenceDataRepository;
    private final NcbiSequenceDownloader ncbiDownloader;
    private final RAnalysisService rAnalysisService;

    public PhyloService(SequenceDataRepository sequenceDataRepository, 
                       NcbiSequenceDownloader ncbiDownloader,
                       RAnalysisService rAnalysisService) {
        this.sequenceDataRepository = sequenceDataRepository;
        this.ncbiDownloader = ncbiDownloader;
        this.rAnalysisService = rAnalysisService;
    }

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
        System.out.println("\n========== 开始系统发育分析 ==========");
        System.out.println("方法：" + method);
            
        // Step 1: 解析 FASTA
        List<Sequence> sequences = fastaParser.parse(fastaContent);
        System.out.println("Step 1 - 解析序列：" + sequences.size() + " 条");
    
        if (sequences.isEmpty()) {
            throw new IllegalArgumentException("未能从文件中解析到任何序列，请检查 FASTA 格式");
        }
        if (sequences.size() < 2) {
            throw new IllegalArgumentException("至少需要 2 条序列才能进行系统发育分析");
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
        System.out.println("Step 2 - 距离矩阵：" + distanceMethod + ", " + sequences.size() + "x" + sequences.size());

        // Step 3: 建树
        String newickTree;
        String usedMethod;
        if ("nj".equalsIgnoreCase(method)) {
            System.out.println("Step 3 - 使用 Neighbor-Joining 建树...");
            newickTree = nj.buildTree(distanceMatrix);
            usedMethod = "Neighbor-Joining (NJ) + " + distanceMethod;
        } else {
            System.out.println("Step 3 - 使用 UPGMA 建树...");
            newickTree = upgma.buildTree(distanceMatrix);
            usedMethod = "UPGMA + " + distanceMethod;
        }
        System.out.println("Step 3 - Newick 树：" + newickTree.substring(0, Math.min(80, newickTree.length())) + "...");

        // Step 4: 组装结果
        List<AnalysisResult.SequenceInfo> seqInfos = sequences.stream()
            .map(seq -> new AnalysisResult.SequenceInfo(seq.getName(), seq.getLength()))
            .collect(Collectors.toList());

        return new AnalysisResult(seqInfos, distanceMatrix, newickTree, usedMethod);
    }

    /**
     * 使用 R 语言可视化系统发育树
     * 
     * @param fastaContent FASTA 内容
     * @param method 建树方法
     * @return 包含 Newick 树和 PNG 图片的分析结果
     */
    public AnalysisResult analyzeWithRVisualization(String fastaContent, String method) {
        // 先执行常规分析
        AnalysisResult result = analyze(fastaContent, method);
        
        try {
            System.out.println("正在使用 R 语言绘制系统发育树...");
            
            // 提取序列名称
            List<String> seqNames = result.getSequences().stream()
                .map(AnalysisResult.SequenceInfo::getName)
                .collect(Collectors.toList());
            
            // 使用 R 语言绘制环状树
            String base64Image = rAnalysisService.drawCircularTree(result.getTree(), seqNames);
            
            // 将图片添加到结果中
            result.setCircularTreeImage(base64Image);
            System.out.println("✅ R 语言绘制的系统发育树已完成");
            
        } catch (Exception e) {
            System.err.println("R 语言绘图失败，继续使用 Newick 格式：" + e.getMessage());
            // 不抛出异常，继续返回基础分析结果
        }
        
        return result;
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

    // ===== 数据库序列数据相关方法 =====

    /**
     * 获取所有默认序列数据列表（不含FASTA内容，减少传输量）
     */
    public List<SequenceData> getDefaultSequences() {
        return sequenceDataRepository.findBySourceOrderByCreatedAtAsc("DEFAULT");
    }

    /**
     * 获取所有序列数据列表（默认 + 用户）
     */
    public List<SequenceData> getAllSequences() {
        return sequenceDataRepository.findAllByOrderByCreatedAtDesc();
    }

    /**
     * 根据ID获取序列数据
     */
    public SequenceData getSequenceById(Long id) {
        return sequenceDataRepository.findById(id)
            .orElseThrow(() -> new IllegalArgumentException("未找到ID为 " + id + " 的序列数据"));
    }

    /**
     * 使用数据库中的序列数据执行分析
     *
     * @param id     序列数据ID
     * @param method 建树方法
     * @return 分析结果
     */
    public AnalysisResult analyzeFromDatabase(Long id, String method) {
        SequenceData data = getSequenceById(id);
        return analyze(data.getFastaContent(), method);
    }

    /**
     * 使用多个数据库序列数据合并后执行分析
     *
     * @param ids    序列数据ID列表
     * @param method 建树方法
     * @return 分析结果
     */
    public AnalysisResult analyzeFromMultipleDatabase(List<Long> ids, String method) {
        StringBuilder combinedFasta = new StringBuilder();
        for (Long id : ids) {
            SequenceData data = getSequenceById(id);
            combinedFasta.append(data.getFastaContent()).append("\n");
        }
        return analyze(combinedFasta.toString(), method);
    }

    /**
     * 保存用户上传的序列数据到数据库
     */
    public SequenceData saveUserSequence(String name, String fastaContent, String fileName) {
        List<Sequence> sequences = fastaParser.parse(fastaContent);
        SequenceData data = new SequenceData(
            name,
            "用户上传 | 包含 " + sequences.size() + " 条序列",
            fastaContent,
            sequences.size(),
            "USER",
            fileName
        );
        return sequenceDataRepository.save(data);
    }

    /**
     * 保存用户序列并关联用户ID
     */
    public SequenceData saveUserSequence(String name, String fastaContent, String fileName, Long userId) {
        List<Sequence> sequences = fastaParser.parse(fastaContent);
        SequenceData data = new SequenceData(
            name,
            "用户上传 | 包含 " + sequences.size() + " 条序列",
            fastaContent,
            sequences.size(),
            "USER",
            fileName,
            userId
        );
        return sequenceDataRepository.save(data);
    }

    /**
     * 获取指定用户保存的序列数据列表
     */
    public List<SequenceData> getUserSequences(Long userId) {
        return sequenceDataRepository.findByUserIdOrderByCreatedAtDesc(userId);
    }

    // ===== NCBI 序列下载相关方法 =====

    /**
     * 从 NCBI 下载单个序列并执行分析
     *
     * @param accession Accession Number (如 "NM_001301717")
     * @param method    建树方法："upgma" 或 "nj"
     * @return 分析结果
     */
    public AnalysisResult analyzeFromNcbi(String accession, String method) {
        System.out.println("正在从 NCBI 下载序列：" + accession);
        String fastaContent = ncbiDownloader.downloadSingleSequence(accession);
        System.out.println("NCBI 下载完成，序列长度：" + fastaContent.length() + " 字符");
        return analyze(fastaContent, method);
    }

    /**
     * 从 NCBI 下载多个序列并合并执行分析
     *
     * @param accessions Accession Number 列表
     * @param method     建树方法："upgma" 或 "nj"
     * @return 分析结果
     */
    public AnalysisResult analyzeFromNcbiMulti(List<String> accessions, String method) {
        if (accessions == null || accessions.isEmpty()) {
            throw new IllegalArgumentException("Accession Number 列表不能为空");
        }
        
        System.out.println("正在从 NCBI 下载 " + accessions.size() + " 个序列...");
        String fastaContent = ncbiDownloader.downloadMultipleSequences(accessions);
        System.out.println("NCBI 批量下载完成，总字符数：" + fastaContent.length());
        return analyze(fastaContent, method);
    }

    /**
     * 验证 NCBI Accession Number 是否有效
     *
     * @param accession Accession Number
     * @return true 如果有效，false 如果无效
     */
    public boolean validateNcbiAccession(String accession) {
        try {
            ncbiDownloader.validateAccession(accession);
            return true;
        } catch (Exception e) {
            return false;
        }
    }
}
