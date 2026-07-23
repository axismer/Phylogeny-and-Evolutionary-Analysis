package com.phylo.controller;

import com.phylo.model.AnalysisResult;
import com.phylo.service.PhyloService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.Map;

/**
 * 系统发育分析 API 控制器
 * 
 * POST /api/analyze - 上传FASTA文件，返回分析结果
 * POST /api/analyze-text - 直接提交FASTA文本，返回分析结果
 * GET  /api/health - 健康检查
 */
@RestController
@RequestMapping("/api")
@CrossOrigin(origins = "*")
public class PhyloController {

    private final PhyloService phyloService;

    public PhyloController(PhyloService phyloService) {
        this.phyloService = phyloService;
    }

    /**
     * 接收FASTA文件，执行系统发育分析
     *
     * @param file   上传的FASTA文件
     * @param method 建树方法（upgma 或 nj，默认 upgma）
     * @return JSON格式的分析结果
     */
    @PostMapping("/analyze")
    public ResponseEntity<?> analyze(
            @RequestParam("file") MultipartFile file,
            @RequestParam(value = "method", defaultValue = "upgma") String method) {

        // 验证文件
        if (file.isEmpty()) {
            return ResponseEntity.badRequest()
                .body(Map.of("error", "上传文件为空"));
        }

        String filename = file.getOriginalFilename();
        if (filename != null && !filename.toLowerCase().endsWith(".fasta") 
            && !filename.toLowerCase().endsWith(".fa")
            && !filename.toLowerCase().endsWith(".fas")
            && !filename.toLowerCase().endsWith(".txt")) {
            return ResponseEntity.badRequest()
                .body(Map.of("error", "请上传FASTA格式文件（.fasta, .fa, .fas, .txt）"));
        }

        try {
            String fastaContent = new String(file.getBytes(), StandardCharsets.UTF_8);
            AnalysisResult result = phyloService.analyze(fastaContent, method);
            return ResponseEntity.ok(result);

        } catch (IOException e) {
            return ResponseEntity.internalServerError()
                .body(Map.of("error", "文件读取失败: " + e.getMessage()));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest()
                .body(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.internalServerError()
                .body(Map.of("error", "分析过程出错: " + e.getMessage()));
        }
    }

    /**
     * 接收FASTA文本内容，执行系统发育分析
     *
     * @param body 请求体，包含 fasta 和 method 字段
     * @return JSON格式的分析结果
     */
    @PostMapping("/analyze-text")
    public ResponseEntity<?> analyzeText(@RequestBody Map<String, String> body) {
        String fasta = body.get("fasta");
        String method = body.getOrDefault("method", "upgma");

        if (fasta == null || fasta.isBlank()) {
            return ResponseEntity.badRequest()
                .body(Map.of("error", "请输入FASTA格式的序列内容"));
        }

        try {
            AnalysisResult result = phyloService.analyze(fasta, method);
            return ResponseEntity.ok(result);

        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest()
                .body(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.internalServerError()
                .body(Map.of("error", "分析过程出错: " + e.getMessage()));
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
