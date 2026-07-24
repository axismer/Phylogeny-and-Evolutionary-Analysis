package com.phylo.service;

import com.phylo.model.entity.Dataset;
import com.phylo.model.entity.SequenceEntity;
import com.phylo.model.entity.Species;
import com.phylo.repository.DatasetRepository;
import com.phylo.repository.SequenceRepository;
import com.phylo.repository.SpeciesRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;

/**
 * NCBI 数据下载服务 - 通过 E-utilities API 下载序列数据
 */
@Service
public class NcbiService {

    @Value("${phylo.storage.path}")
    private String storagePath;

    private final RestTemplate restTemplate = new RestTemplate();
    private final DatasetRepository datasetRepository;
    private final SequenceRepository sequenceRepository;
    private final SpeciesRepository speciesRepository;

    private static final String ESEARCH_URL = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi";
    private static final String EFETCH_URL = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi";

    public NcbiService(DatasetRepository datasetRepository,
                       SequenceRepository sequenceRepository,
                       SpeciesRepository speciesRepository) {
        this.datasetRepository = datasetRepository;
        this.sequenceRepository = sequenceRepository;
        this.speciesRepository = speciesRepository;
    }

    /**
     * 搜索NCBI核酸数据库
     */
    public Map<String, Object> searchNucleotide(String term, int retMax) {
        String url = ESEARCH_URL + "?db=nucleotide&term=" + term
                + "&retmax=" + retMax + "&retmode=json";

        try {
            String response = restTemplate.getForObject(url, String.class);
            Map<String, Object> result = new HashMap<>();
            result.put("raw", response);
            result.put("query", term);
            result.put("success", true);
            return result;
        } catch (Exception e) {
            Map<String, Object> result = new HashMap<>();
            result.put("success", false);
            result.put("error", "NCBI搜索失败: " + e.getMessage());
            return result;
        }
    }

    /**
     * 根据accession号下载FASTA序列并保存到数据集
     */
    public Map<String, Object> downloadByAccession(Integer uid, Integer did, String accession, String speciesName) throws IOException {
        Dataset dataset = datasetRepository.findById(did)
                .orElseThrow(() -> new IllegalArgumentException("数据集不存在"));
        if (!dataset.getUid().equals(uid)) {
            throw new IllegalArgumentException("无权操作此数据集");
        }

        // 从NCBI获取FASTA格式序列
        String url = EFETCH_URL + "?db=nucleotide&id=" + accession + "&rettype=fasta&retmode=text";

        String fastaContent;
        try {
            fastaContent = restTemplate.getForObject(url, String.class);
        } catch (Exception e) {
            throw new IllegalArgumentException("从NCBI下载失败: " + e.getMessage());
        }

        if (fastaContent == null || fastaContent.isBlank()) {
            throw new IllegalArgumentException("未能从NCBI获取到序列数据，请检查accession号: " + accession);
        }

        // 解析序列信息
        String seqName = "";
        int seqLength = 0;
        String[] lines = fastaContent.split("\\r?\\n");
        if (lines.length > 0 && lines[0].startsWith(">")) {
            seqName = lines[0].substring(1).trim();
        }
        StringBuilder seqBuilder = new StringBuilder();
        for (int i = 1; i < lines.length; i++) {
            seqBuilder.append(lines[i].trim());
        }
        seqLength = seqBuilder.length();

        // 创建物种记录
        Species species = new Species(uid, speciesName != null ? speciesName : accession, "", "Downloaded from NCBI");
        species = speciesRepository.save(species);

        // 保存文件
        String fileName = System.currentTimeMillis() + "_" + accession + ".fasta";
        Path filePath = Paths.get(storagePath, fileName);
        Files.createDirectories(filePath.getParent());
        Files.write(filePath, fastaContent.getBytes(StandardCharsets.UTF_8));

        // 创建序列记录
        SequenceEntity entity = new SequenceEntity(
                species.getSid(), uid, did, accession,
                seqName.isEmpty() ? accession : seqName,
                filePath.toString(), seqLength, "NCBI"
        );
        entity = sequenceRepository.save(entity);

        Map<String, Object> result = new HashMap<>();
        result.put("seid", entity.getSeid());
        result.put("accession", accession);
        result.put("name", seqName);
        result.put("length", seqLength);
        result.put("speciesId", species.getSid());
        result.put("filePath", filePath.toString());
        result.put("success", true);
        return result;
    }

    /**
     * 批量下载多个accession
     */
    public List<Map<String, Object>> batchDownload(Integer uid, Integer did, List<String> accessions, String speciesName) throws IOException {
        List<Map<String, Object>> results = new ArrayList<>();
        for (String acc : accessions) {
            try {
                Map<String, Object> r = downloadByAccession(uid, did, acc.trim(), speciesName);
                results.add(r);
                // NCBI API 限速，间隔350ms
                Thread.sleep(350);
            } catch (Exception e) {
                Map<String, Object> err = new HashMap<>();
                err.put("accession", acc);
                err.put("success", false);
                err.put("error", e.getMessage());
                results.add(err);
            }
        }
        return results;
    }
}
