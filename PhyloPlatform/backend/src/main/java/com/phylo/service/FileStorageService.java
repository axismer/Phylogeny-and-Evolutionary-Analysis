package com.phylo.service;

import com.phylo.model.entity.Dataset;
import com.phylo.model.entity.SequenceEntity;
import com.phylo.model.entity.Species;
import com.phylo.algorithm.FastaParser;
import com.phylo.model.Sequence;
import com.phylo.repository.DatasetRepository;
import com.phylo.repository.SequenceRepository;
import com.phylo.repository.SpeciesRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import jakarta.annotation.PostConstruct;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;
import java.util.stream.Collectors;

/**
 * 文件存储服务 - 管理序列文件的上传、存储和读取
 */
@Service
public class FileStorageService {

    @Value("${phylo.storage.path}")
    private String storagePath;

    private final DatasetRepository datasetRepository;
    private final SequenceRepository sequenceRepository;
    private final SpeciesRepository speciesRepository;
    private final FastaParser fastaParser = new FastaParser();

    public FileStorageService(DatasetRepository datasetRepository,
                              SequenceRepository sequenceRepository,
                              SpeciesRepository speciesRepository) {
        this.datasetRepository = datasetRepository;
        this.sequenceRepository = sequenceRepository;
        this.speciesRepository = speciesRepository;
    }

    @PostConstruct
    public void init() throws IOException {
        Files.createDirectories(Paths.get(storagePath));
    }

    /**
     * 创建数据集
     */
    public Dataset createDataset(Integer uid, String name, String description) {
        Dataset dataset = new Dataset(uid, name, "upload", description, "active");
        return datasetRepository.save(dataset);
    }

    /**
     * 获取用户的数据集列表
     */
    public List<Dataset> getUserDatasets(Integer uid) {
        return datasetRepository.findByUidOrderByDidDesc(uid);
    }

    /**
     * 上传FASTA文件到指定数据集，解析序列并存储
     */
    public Map<String, Object> uploadFastaFile(Integer uid, Integer did, MultipartFile file, String speciesName) throws IOException {
        Dataset dataset = datasetRepository.findById(did)
                .orElseThrow(() -> new IllegalArgumentException("数据集不存在"));
        if (!dataset.getUid().equals(uid)) {
            throw new IllegalArgumentException("无权操作此数据集");
        }

        String content = new String(file.getBytes(), StandardCharsets.UTF_8);
        List<Sequence> sequences = fastaParser.parse(content);

        if (sequences.isEmpty()) {
            throw new IllegalArgumentException("未能从文件中解析到任何序列");
        }

        // 创建物种记录
        Species species = new Species(uid, speciesName != null ? speciesName : file.getOriginalFilename(), "", "");
        species = speciesRepository.save(species);

        // 存储文件
        String fileName = System.currentTimeMillis() + "_" + file.getOriginalFilename();
        Path filePath = Paths.get(storagePath, fileName);
        Files.write(filePath, file.getBytes());

        // 为每条序列创建记录
        List<Map<String, Object>> seqList = new ArrayList<>();
        for (Sequence seq : sequences) {
            SequenceEntity entity = new SequenceEntity(
                    species.getSid(), uid, did,
                    extractAccession(seq.getName()),
                    seq.getName(),
                    filePath.toString(),
                    seq.getLength(),
                    "local"
            );
            entity = sequenceRepository.save(entity);

            Map<String, Object> seqInfo = new HashMap<>();
            seqInfo.put("seid", entity.getSeid());
            seqInfo.put("name", seq.getName());
            seqInfo.put("length", seq.getLength());
            seqInfo.put("accession", entity.getAccession());
            seqList.add(seqInfo);
        }

        Map<String, Object> result = new HashMap<>();
        result.put("speciesId", species.getSid());
        result.put("speciesName", species.getSname());
        result.put("sequenceCount", sequences.size());
        result.put("sequences", seqList);
        result.put("filePath", filePath.toString());
        return result;
    }

    /**
     * 获取数据集下的所有物种及其序列
     */
    public List<Map<String, Object>> getDatasetSpecies(Integer uid, Integer did) {
        List<SequenceEntity> seqEntities = sequenceRepository.findByUidAndDid(uid, did);

        // 按物种分组
        Map<Integer, List<SequenceEntity>> grouped = seqEntities.stream()
                .collect(Collectors.groupingBy(SequenceEntity::getSid));

        List<Map<String, Object>> result = new ArrayList<>();
        for (Map.Entry<Integer, List<SequenceEntity>> entry : grouped.entrySet()) {
            Species species = speciesRepository.findById(entry.getKey()).orElse(null);
            Map<String, Object> speciesInfo = new HashMap<>();
            speciesInfo.put("sid", entry.getKey());
            speciesInfo.put("sname", species != null ? species.getSname() : "Unknown");

            List<Map<String, Object>> seqs = entry.getValue().stream().map(se -> {
                Map<String, Object> m = new HashMap<>();
                m.put("seid", se.getSeid());
                m.put("name", se.getSename());
                m.put("accession", se.getAccession());
                m.put("length", se.getSeLength());
                m.put("source", se.getSsource());
                return m;
            }).collect(Collectors.toList());

            speciesInfo.put("sequences", seqs);
            speciesInfo.put("sequenceCount", seqs.size());
            result.add(speciesInfo);
        }
        return result;
    }

    /**
     * 读取指定序列文件内容
     */
    public String readSequenceFile(String filePath) throws IOException {
        Path path = Paths.get(filePath);
        if (!Files.exists(path)) {
            throw new IllegalArgumentException("文件不存在: " + filePath);
        }
        return Files.readString(path, StandardCharsets.UTF_8);
    }

    /**
     * 删除数据集及其关联数据
     */
    public void deleteDataset(Integer uid, Integer did) {
        Dataset dataset = datasetRepository.findById(did)
                .orElseThrow(() -> new IllegalArgumentException("数据集不存在"));
        if (!dataset.getUid().equals(uid)) {
            throw new IllegalArgumentException("无权操作此数据集");
        }

        List<SequenceEntity> seqs = sequenceRepository.findByDid(did);
        sequenceRepository.deleteAll(seqs);
        datasetRepository.delete(dataset);
    }

    /**
     * 从序列名称中提取accession号
     */
    private String extractAccession(String name) {
        if (name == null) return "";
        String[] parts = name.split("\\s+");
        return parts.length > 0 ? parts[0] : name;
    }
}
