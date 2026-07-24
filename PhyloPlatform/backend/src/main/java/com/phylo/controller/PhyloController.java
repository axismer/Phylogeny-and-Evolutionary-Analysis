package com.phylo.controller;

import com.phylo.model.AnalysisResult;
import com.phylo.model.entity.SequenceEntity;
import com.phylo.repository.SequenceRepository;
import com.phylo.service.FileStorageService;
import com.phylo.service.PhyloService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.*;

/**
 * 系统发育分析 API 控制器
 */
@RestController
@RequestMapping("/api")
public class PhyloController {

    private final PhyloService phyloService;
    private final FileStorageService fileStorageService;
    private final SequenceRepository sequenceRepository;

    public PhyloController(PhyloService phyloService, FileStorageService fileStorageService,
                           SequenceRepository sequenceRepository) {
        this.phyloService = phyloService;
        this.fileStorageService = fileStorageService;
        this.sequenceRepository = sequenceRepository;
    }

    /**
     * 接收FASTA文件，执行系统发育分析
     */
    @PostMapping("/analyze")
    public ResponseEntity<?> analyze(
            @RequestParam("file") MultipartFile file,
            @RequestParam(value = "method", defaultValue = "nj") String method) {

        if (file.isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("error", "上传文件为空"));
        }

        try {
            String fastaContent = new String(file.getBytes(), StandardCharsets.UTF_8);
            AnalysisResult result = phyloService.analyze(fastaContent, method);
            return ResponseEntity.ok(result);
        } catch (IOException e) {
            return ResponseEntity.internalServerError().body(Map.of("error", "文件读取失败: " + e.getMessage()));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.internalServerError().body(Map.of("error", "分析过程出错: " + e.getMessage()));
        }
    }

    /**
     * 接收FASTA文本内容，执行系统发育分析
     */
    @PostMapping("/analyze-text")
    public ResponseEntity<?> analyzeText(@RequestBody Map<String, String> body) {
        String fasta = body.get("fasta");
        String method = body.getOrDefault("method", "nj");

        if (fasta == null || fasta.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("error", "请输入FASTA格式的序列内容"));
        }

        try {
            AnalysisResult result = phyloService.analyze(fasta, method);
            return ResponseEntity.ok(result);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.internalServerError().body(Map.of("error", "分析过程出错: " + e.getMessage()));
        }
    }

    /**
     * 多文件比对分析 - 从数据集中读取多个物种文件，每个文件选最优序列进行比对
     */
    @PostMapping("/analyze-dataset")
    public ResponseEntity<?> analyzeDataset(Authentication auth, @RequestBody Map<String, Object> body) {
        Integer uid = (Integer) auth.getPrincipal();
        Integer did = (Integer) body.get("did");
        String method = (String) body.getOrDefault("method", "nj");

        if (did == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "缺少数据集ID"));
        }

        try {
            // 获取数据集中所有物种的序列文件
            List<Map<String, Object>> speciesList = fileStorageService.getDatasetSpecies(uid, did);

            if (speciesList.size() < 2) {
                return ResponseEntity.badRequest().body(Map.of("error", "数据集中至少需要2个物种才能进行分析"));
            }

            // 读取每个物种的文件内容
            Map<String, String> fileContents = new LinkedHashMap<>();
            for (Map<String, Object> species : speciesList) {
                String sname = (String) species.get("sname");
                @SuppressWarnings("unchecked")
                List<Map<String, Object>> seqs = (List<Map<String, Object>>) species.get("sequences");
                if (seqs != null && !seqs.isEmpty()) {
                    // 获取第一条序列的文件路径（同一物种的序列在同一文件中）
                    String seid = String.valueOf(seqs.get(0).get("seid"));
                    SequenceEntity seqEntity = sequenceRepository.findById(Integer.parseInt(seid)).orElse(null);
                    if (seqEntity != null && seqEntity.getFilePath() != null) {
                        String content = fileStorageService.readSequenceFile(seqEntity.getFilePath());
                        fileContents.put(sname, content);
                    }
                }
            }

            if (fileContents.size() < 2) {
                return ResponseEntity.badRequest().body(Map.of("error", "有效物种文件不足2个"));
            }

            AnalysisResult result = phyloService.analyzeMultiFiles(fileContents, method);
            return ResponseEntity.ok(result);

        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.internalServerError().body(Map.of("error", "分析过程出错: " + e.getMessage()));
        }
    }

    /**
     * 健康检查接口
     */
    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        return ResponseEntity.ok(Map.of("status", "UP", "service", "PhyloPlatform"));
    }
}
