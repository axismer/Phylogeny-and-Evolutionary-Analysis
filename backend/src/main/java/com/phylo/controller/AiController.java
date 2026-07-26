package com.phylo.controller;

import com.phylo.service.AiAnalysisService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

/**
 * AI 分析控制器 - 集成 DeepSeek 大语言模型
 */
@RestController
@RequestMapping("/api/ai")
@CrossOrigin(origins = "*")
public class AiController {

    private final AiAnalysisService aiAnalysisService;

    public AiController(AiAnalysisService aiAnalysisService) {
        this.aiAnalysisService = aiAnalysisService;
    }

    /**
     * 系统发育树智能解读
     * 
     * @param body { "tree": "Newick 格式树", "sequences": ["序列名 1", "序列名 2"], "method": "分析方法" }
     * @return AI 生成的进化关系解读报告
     */
    @PostMapping("/interpret-tree")
    public ResponseEntity<?> interpretTree(@RequestBody Map<String, Object> body) {
        try {
            String tree = (String) body.get("tree");
            @SuppressWarnings("unchecked")
            var seqList = (java.util.List<String>) body.get("sequences");
            String method = (String) body.getOrDefault("method", "UPGMA");
            
            if (tree == null || tree.isBlank()) {
                return ResponseEntity.badRequest()
                    .body(Map.of("error", "请提供 Newick 格式的进化树"));
            }
            if (seqList == null || seqList.isEmpty()) {
                return ResponseEntity.badRequest()
                    .body(Map.of("error", "请提供至少一条序列名称"));
            }

            String interpretation = aiAnalysisService.interpretPhylogeneticTree(tree, seqList, method);
            
            return ResponseEntity.ok(Map.of(
                "summary", extractSummary(interpretation),
                "fullContent", interpretation,
                "status", "success"
            ));
            
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest()
                .body(Map.of("error", "参数错误：" + e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.internalServerError()
                .body(Map.of("error", "AI 分析失败：" + e.getMessage()));
        }
    }

    /**
     * 距离矩阵智能分析
     * 
     * @param body { "matrix": [[0, 0.1, 0.2], [0.1, 0, 0.15]], "names": ["A", "B", "C"] }
     * @return 进化关系深度分析
     */
    @PostMapping("/analyze-matrix")
    public ResponseEntity<?> analyzeDistanceMatrix(@RequestBody Map<String, Object> body) {
        try {
            @SuppressWarnings("unchecked")
            var matrix = (java.util.List<List<Double>>) body.get("matrix");
            @SuppressWarnings("unchecked")
            var names = (java.util.List<String>) body.get("names");
            
            if (matrix == null || matrix.isEmpty()) {
                return ResponseEntity.badRequest()
                    .body(Map.of("error", "请提供距离矩阵数据"));
            }

            String analysis = aiAnalysisService.analyzeDistanceMatrix(matrix, names);
            
            return ResponseEntity.ok(Map.of(
                "highlights", extractKeyPoints(analysis),
                "fullContent", analysis,
                "status", "success"
            ));
            
        } catch (Exception e) {
            return ResponseEntity.internalServerError()
                .body(Map.of("error", "矩阵分析失败：" + e.getMessage()));
        }
    }

    /**
     * 通用序列分析报告生成
     * 
     * @param body { "sequences": [{"name": "A", "length": 100}], "stats": {...} }
     * @return 专业级的生物学分析报告
     */
    @PostMapping("/generate-report")
    public ResponseEntity<?> generateReport(@RequestBody Map<String, Object> body) {
        try {
            String report = aiAnalysisService.generateBiologicalReport(body);
            
            return ResponseEntity.ok(Map.of(
                "report", report,
                "status", "success"
            ));
            
        } catch (Exception e) {
            return ResponseEntity.internalServerError()
                .body(Map.of("error", "报告生成失败：" + e.getMessage()));
        }
    }

    /**
     * 健康检查 - 验证 DeepSeek 连接状态
     */
    @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> health() {
        boolean available = aiAnalysisService.isDeepSeekAvailable();
        return ResponseEntity.ok(Map.of(
            "status", available ? "UP" : "DOWN",
            "service", "DeepSeek-AI",
            "version", "1.0"
        ));
    }

    // 辅助方法：提取摘要（前 200 字符）
    private String extractSummary(String content) {
        if (content == null || content.length() <= 200) {
            return content;
        }
        int endIndex = content.indexOf('\n', 200);
        return content.substring(0, endIndex > 0 ? endIndex : 200) + "...";
    }

    // 辅助方法：提取关键点（假设每段第一句是重点）
    private String extractKeyPoints(String content) {
        String[] paragraphs = content.split("\n\n");
        StringBuilder summary = new StringBuilder();
        for (int i = 0; i < Math.min(paragraphs.length, 3); i++) {
            String[] sentences = paragraphs[i].split("\\.");
            if (sentences.length > 0) {
                summary.append(sentences[0]).append(".\n\n");
            }
        }
        return summary.toString();
    }
}
