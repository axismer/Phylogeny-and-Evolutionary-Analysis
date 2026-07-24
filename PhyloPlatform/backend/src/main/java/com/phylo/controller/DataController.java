package com.phylo.controller;

import com.phylo.model.entity.Dataset;
import com.phylo.service.FileStorageService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 数据管理控制器 - 数据集和序列文件管理
 */
@RestController
@RequestMapping("/api/data")
public class DataController {

    private final FileStorageService fileStorageService;

    public DataController(FileStorageService fileStorageService) {
        this.fileStorageService = fileStorageService;
    }

    /** 创建数据集 */
    @PostMapping("/dataset")
    public ResponseEntity<?> createDataset(Authentication auth, @RequestBody Map<String, String> body) {
        Integer uid = (Integer) auth.getPrincipal();
        String name = body.get("name");
        String description = body.get("description");

        if (name == null || name.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("error", "数据集名称不能为空"));
        }

        Dataset dataset = fileStorageService.createDataset(uid, name, description);
        return ResponseEntity.ok(Map.of(
            "did", dataset.getDid(),
            "dname", dataset.getDname(),
            "dstatus", dataset.getDstatus()
        ));
    }

    /** 获取用户数据集列表 */
    @GetMapping("/datasets")
    public ResponseEntity<?> getDatasets(Authentication auth) {
        Integer uid = (Integer) auth.getPrincipal();
        List<Dataset> datasets = fileStorageService.getUserDatasets(uid);
        return ResponseEntity.ok(datasets);
    }

    /** 上传FASTA文件到数据集 */
    @PostMapping("/upload")
    public ResponseEntity<?> uploadFile(Authentication auth,
                                        @RequestParam("file") MultipartFile file,
                                        @RequestParam("did") Integer did,
                                        @RequestParam(value = "speciesName", required = false) String speciesName) {
        Integer uid = (Integer) auth.getPrincipal();

        if (file.isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("error", "文件为空"));
        }

        try {
            Map<String, Object> result = fileStorageService.uploadFastaFile(uid, did, file, speciesName);
            return ResponseEntity.ok(result);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.internalServerError().body(Map.of("error", "上传失败: " + e.getMessage()));
        }
    }

    /** 获取数据集下的物种和序列 */
    @GetMapping("/dataset/{did}/species")
    public ResponseEntity<?> getDatasetSpecies(Authentication auth, @PathVariable Integer did) {
        Integer uid = (Integer) auth.getPrincipal();
        try {
            List<Map<String, Object>> result = fileStorageService.getDatasetSpecies(uid, did);
            return ResponseEntity.ok(result);
        } catch (Exception e) {
            return ResponseEntity.internalServerError().body(Map.of("error", e.getMessage()));
        }
    }

    /** 批量上传FASTA文件到数据集 */
    @PostMapping("/batch-upload")
    public ResponseEntity<?> batchUpload(Authentication auth,
                                         @RequestParam("files") MultipartFile[] files,
                                         @RequestParam("did") Integer did,
                                         @RequestParam(value = "speciesNames", required = false) String speciesNames) {
        Integer uid = (Integer) auth.getPrincipal();

        if (files == null || files.length == 0) {
            return ResponseEntity.badRequest().body(Map.of("error", "没有选择文件"));
        }

        // speciesNames 用逗号分隔，与文件一一对应
        String[] names = speciesNames != null ? speciesNames.split(",", -1) : new String[0];

        List<Map<String, Object>> results = new ArrayList<>();
        int successCount = 0;
        int failCount = 0;

        for (int i = 0; i < files.length; i++) {
            MultipartFile file = files[i];
            String spName = (i < names.length && !names[i].isBlank()) ? names[i].trim() : file.getOriginalFilename();
            Map<String, Object> item = new HashMap<>();
            item.put("fileName", file.getOriginalFilename());
            try {
                if (file.isEmpty()) {
                    item.put("success", false);
                    item.put("error", "文件为空");
                    failCount++;
                } else {
                    Map<String, Object> uploadResult = fileStorageService.uploadFastaFile(uid, did, file, spName);
                    item.put("success", true);
                    item.put("speciesName", uploadResult.get("speciesName"));
                    item.put("sequenceCount", uploadResult.get("sequenceCount"));
                    successCount++;
                }
            } catch (Exception e) {
                item.put("success", false);
                item.put("error", e.getMessage());
                failCount++;
            }
            results.add(item);
        }

        Map<String, Object> response = new HashMap<>();
        response.put("results", results);
        response.put("successCount", successCount);
        response.put("failCount", failCount);
        response.put("total", files.length);
        return ResponseEntity.ok(response);
    }

    /** 删除数据集 */
    @DeleteMapping("/dataset/{did}")
    public ResponseEntity<?> deleteDataset(Authentication auth, @PathVariable Integer did) {
        Integer uid = (Integer) auth.getPrincipal();
        try {
            fileStorageService.deleteDataset(uid, did);
            return ResponseEntity.ok(Map.of("message", "删除成功"));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }
}
