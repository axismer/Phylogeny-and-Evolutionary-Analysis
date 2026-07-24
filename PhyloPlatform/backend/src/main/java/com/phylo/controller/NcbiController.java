package com.phylo.controller;

import com.phylo.service.NcbiService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * NCBI 数据下载控制器
 */
@RestController
@RequestMapping("/api/ncbi")
public class NcbiController {

    private final NcbiService ncbiService;

    public NcbiController(NcbiService ncbiService) {
        this.ncbiService = ncbiService;
    }

    /** 搜索NCBI核酸数据库 */
    @GetMapping("/search")
    public ResponseEntity<?> search(@RequestParam String term,
                                    @RequestParam(defaultValue = "10") int retMax) {
        Map<String, Object> result = ncbiService.searchNucleotide(term, retMax);
        return ResponseEntity.ok(result);
    }

    /** 根据accession下载序列到数据集 */
    @PostMapping("/download")
    public ResponseEntity<?> download(Authentication auth, @RequestBody Map<String, Object> body) {
        Integer uid = (Integer) auth.getPrincipal();
        Integer did = (Integer) body.get("did");
        String accession = (String) body.get("accession");
        String speciesName = (String) body.get("speciesName");

        if (did == null || accession == null || accession.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("error", "缺少必要参数"));
        }

        try {
            Map<String, Object> result = ncbiService.downloadByAccession(uid, did, accession, speciesName);
            return ResponseEntity.ok(result);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.internalServerError().body(Map.of("error", "下载失败: " + e.getMessage()));
        }
    }

    /** 批量下载 */
    @SuppressWarnings("unchecked")
    @PostMapping("/batch-download")
    public ResponseEntity<?> batchDownload(Authentication auth, @RequestBody Map<String, Object> body) {
        Integer uid = (Integer) auth.getPrincipal();
        Integer did = (Integer) body.get("did");
        List<String> accessions = (List<String>) body.get("accessions");
        String speciesName = (String) body.get("speciesName");

        if (did == null || accessions == null || accessions.isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("error", "缺少必要参数"));
        }

        try {
            List<Map<String, Object>> results = ncbiService.batchDownload(uid, did, accessions, speciesName);
            return ResponseEntity.ok(Map.of("results", results));
        } catch (Exception e) {
            return ResponseEntity.internalServerError().body(Map.of("error", "批量下载失败: " + e.getMessage()));
        }
    }
}
