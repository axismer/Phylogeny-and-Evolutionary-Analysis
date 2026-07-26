package com.phylo.controller;

import com.phylo.model.AnalysisResult;
import com.phylo.model.SequenceData;
import com.phylo.model.User;
import com.phylo.repository.UserRepository;
import com.phylo.service.PhyloService;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

/**
 * 系统发育分析 API 控制器
 * 
 * POST /api/analyze - 上传 FASTA 文件，返回分析结果
 * POST /api/analyze-text - 直接提交 FASTA 文本，返回分析结果
 * GET  /api/sequences - 获取数据库中的序列数据列表
 * GET  /api/sequences/default - 获取默认序列数据
 * POST /api/analyze-db - 使用数据库中的序列数据分析
 * POST /api/analyze-db-multi - 使用多个数据库序列合并分析
 * POST /api/ncbi - 从 NCBI 获取序列并分析（单个）
 * POST /api/ncbi-multi - 从 NCBI 获取多个序列并分析
 * POST /api/ncbi-validate - 验证 NCBI Accession Number
 * GET  /api/health - 健康检查
 */
@RestController
@RequestMapping("/api")
@CrossOrigin(origins = "*")
public class PhyloController {

    private final PhyloService phyloService;
    private final UserRepository userRepository;

    public PhyloController(PhyloService phyloService, UserRepository userRepository) {
        this.phyloService = phyloService;
        this.userRepository = userRepository;
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
     * 接收 FASTA 文本内容，执行系统发育分析并使用 R 语言可视化
     *
     * @param fasta FASTA 序列内容（直接作为字符串参数）
     * @param method 建树方法（upgma 或 nj，默认 upgma）
     * @return JSON 格式的分析结果（包含 PNG 图片）
     */
    @PostMapping("/analyze-text-r")
    public ResponseEntity<?> analyzeTextWithR(
            @RequestParam("fasta") String fasta,
            @RequestParam(value = "method", defaultValue = "upgma") String method) {
        
        if (fasta == null || fasta.isBlank()) {
            return ResponseEntity.badRequest()
                .body(Map.of("error", "请输入 FASTA 格式的序列内容"));
        }

        try {
            AnalysisResult result = phyloService.analyzeWithRVisualization(fasta, method);
            return ResponseEntity.ok(result);

        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest()
                .body(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.internalServerError()
                .body(Map.of("error", "分析过程出错：" + e.getMessage(), "trace", e.getStackTrace()));
        }
    }
    
    /**
     * 简化版 - 接收纯文本 FATA 和参数
     */
    @PostMapping(value = "/analyze-text-r", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<?> analyzeTextWithRMultipart(
            MultipartFile fasta,
            @RequestParam(value = "method", defaultValue = "upgma") String method) throws IOException {
        
        if (fasta.isEmpty()) {
            return ResponseEntity.badRequest()
                .body(Map.of("error", "请上传 FASTA 文件"));
        }

        try {
            String fastaContent = new String(fasta.getBytes(), "UTF-8");
            AnalysisResult result = phyloService.analyzeWithRVisualization(fastaContent, method);
            return ResponseEntity.ok(result);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest()
                .body(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.internalServerError()
                .body(Map.of("error", "分析过程出错：" + e.getMessage()));
        }
    }
   @GetMapping("/health")
   public ResponseEntity<Map<String, String>> health() {
       return ResponseEntity.ok(Map.of("status", "UP", "service", "PhyloPlatform"));
   }

    // ===== 数据库序列数据相关接口 =====

    /**
     * 获取所有序列数据列表（默认 + 用户）
     */
    @GetMapping("/sequences")
    public ResponseEntity<List<Map<String, Object>>> getAllSequences() {
        List<SequenceData> list = phyloService.getAllSequences();
        return ResponseEntity.ok(toSequenceListResponse(list));
    }

    /**
     * 获取默认序列数据列表
     */
    @GetMapping("/sequences/default")
    public ResponseEntity<List<Map<String, Object>>> getDefaultSequences() {
        List<SequenceData> list = phyloService.getDefaultSequences();
        return ResponseEntity.ok(toSequenceListResponse(list));
    }

    /**
     * 使用数据库中的单个序列数据执行分析
     */
    @PostMapping("/analyze-db")
    public ResponseEntity<?> analyzeFromDb(@RequestBody Map<String, Object> body) {
        try {
            Long id = Long.valueOf(body.get("id").toString());
            String method = body.getOrDefault("method", "upgma").toString();
            AnalysisResult result = phyloService.analyzeFromDatabase(id, method);
            return ResponseEntity.ok(result);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.internalServerError()
                .body(Map.of("error", "分析过程出错: " + e.getMessage()));
        }
    }

    /**
     * 使用多个数据库序列数据合并后执行分析
     */
    @SuppressWarnings("unchecked")
    @PostMapping("/analyze-db-multi")
    public ResponseEntity<?> analyzeFromDbMulti(@RequestBody Map<String, Object> body) {
        try {
            List<Number> rawIds = (List<Number>) body.get("ids");
            List<Long> ids = rawIds.stream().map(Number::longValue).collect(Collectors.toList());
            String method = body.getOrDefault("method", "upgma").toString();

            if (ids.isEmpty()) {
                return ResponseEntity.badRequest().body(Map.of("error", "请至少选择一个数据集"));
            }

            AnalysisResult result = phyloService.analyzeFromMultipleDatabase(ids, method);
            return ResponseEntity.ok(result);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.internalServerError()
                .body(Map.of("error", "分析过程出错: " + e.getMessage()));
        }
    }

    /**
     * 保存用户上传的序列数据到数据库（关联当前登录用户）
     */
    @PostMapping("/sequences/save")
    public ResponseEntity<?> saveUserSequence(
            @RequestBody Map<String, String> body,
            @RequestHeader(value = "Authorization", required = false) String authHeader) {
        try {
            String name = body.get("name");
            String fasta = body.get("fasta");
            String fileName = body.getOrDefault("fileName", "user_input");

            if (name == null || name.isBlank()) {
                return ResponseEntity.badRequest().body(Map.of("error", "请提供数据集名称"));
            }
            if (fasta == null || fasta.isBlank()) {
                return ResponseEntity.badRequest().body(Map.of("error", "请提供FASTA序列内容"));
            }

            // 解析当前用户
            Long userId = resolveUserId(authHeader);

            SequenceData saved = phyloService.saveUserSequence(name, fasta, fileName, userId);
            return ResponseEntity.ok(Map.of(
                "id", saved.getId(),
                "name", saved.getName(),
                "message", "保存成功"
            ));
        } catch (Exception e) {
            return ResponseEntity.internalServerError()
                .body(Map.of("error", "保存失败: " + e.getMessage()));
        }
    }

    /**
     * 获取当前用户保存的序列数据列表
     */
    @GetMapping("/sequences/mine")
    public ResponseEntity<?> getMySequences(
            @RequestHeader(value = "Authorization", required = false) String authHeader) {
        Long userId = resolveUserId(authHeader);
        if (userId == null) {
            return ResponseEntity.status(401).body(Map.of("error", "请先登录"));
        }
        List<SequenceData> list = phyloService.getUserSequences(userId);
        return ResponseEntity.ok(toSequenceListResponse(list));
    }

    /**
     * 从 Authorization Header 解析用户 ID
     */
    private Long resolveUserId(String authHeader) {
        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            String token = authHeader.substring(7);
            Optional<User> optUser = userRepository.findByToken(token);
            if (optUser.isPresent()) {
                return optUser.get().getId();
            }
        }
        return null;
    }

    /**
     * 将序列数据列表转换为精简的响应格式（不包含 FASTA 内容）
     */
    private List<Map<String, Object>> toSequenceListResponse(List<SequenceData> list) {
        return list.stream().map(data -> {
            Map<String, Object> map = new java.util.LinkedHashMap<>();
            map.put("id", data.getId());
            map.put("name", data.getName());
            map.put("description", data.getDescription());
            map.put("sequenceCount", data.getSequenceCount());
            map.put("source", data.getSource());
            map.put("fileName", data.getFileName());
            map.put("createdAt", data.getCreatedAt() != null ? data.getCreatedAt().toString() : null);
            return map;
        }).collect(Collectors.toList());
    }

    // ===== NCBI 序列获取相关接口 =====

    /**
     * 从 NCBI 下载单个序列并执行分析
     */
    @PostMapping("/ncbi")
    public ResponseEntity<?> analyzeFromNcbi(@RequestBody Map<String, String> body) {
        try {
            String accession = body.get("accession");
            String method = body.getOrDefault("method", "upgma").toString();

            if (accession == null || accession.isBlank()) {
                return ResponseEntity.badRequest()
                    .body(Map.of("error", "请提供 NCBI Accession Number"));
            }

            AnalysisResult result = phyloService.analyzeFromNcbi(accession.trim(), method);
            return ResponseEntity.ok(result);

        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.internalServerError()
                .body(Map.of("error", "NCBI 下载或分析失败：" + e.getMessage()));
        }
    }

    /**
     * 从 NCBI 下载多个序列并执行分析
     */
    @SuppressWarnings("unchecked")
    @PostMapping("/ncbi-multi")
    public ResponseEntity<?> analyzeFromNcbiMulti(@RequestBody Map<String, Object> body) {
        try {
            List<String> rawAccessions = (List<String>) body.get("accessions");
            String method = body.getOrDefault("method", "upgma").toString();

            if (rawAccessions == null || rawAccessions.isEmpty()) {
                return ResponseEntity.badRequest()
                    .body(Map.of("error", "请至少提供一个 Accession Number"));
            }

            AnalysisResult result = phyloService.analyzeFromNcbiMulti(rawAccessions, method);
            return ResponseEntity.ok(result);

        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.internalServerError()
                .body(Map.of("error", "NCBI 批量下载或分析失败：" + e.getMessage()));
        }
    }

    /**
     * 验证 NCBI Accession Number 是否有效
     */
    @PostMapping("/ncbi-validate")
    public ResponseEntity<?> validateNcbiAccession(@RequestBody Map<String, String> body) {
        try {
            String accession = body.get("accession");

            if (accession == null || accession.isBlank()) {
                return ResponseEntity.badRequest()
                    .body(Map.of("error", "请提供 Accession Number"));
            }

            boolean valid = phyloService.validateNcbiAccession(accession.trim());
            return ResponseEntity.ok(Map.of(
                "accession", accession,
                "valid", valid,
                "message", valid ? "有效的 Accession Number" : "无法从 NCBI 获取该序列"
            ));

        } catch (Exception e) {
            return ResponseEntity.internalServerError()
                .body(Map.of("error", "验证失败：" + e.getMessage()));
        }
    }
}
