package com.phylo.model;

import jakarta.persistence.*;
import java.time.LocalDateTime;

/**
 * 分析记录实体类 - 持久化存储系统发育分析的历史记录
 */
@Entity
@Table(name = "analysis_record")
public class AnalysisRecord {

    /** 主键ID，自增 */
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** 上传的文件名 */
    @Column(name = "file_name")
    private String fileName;

    /** 原始FASTA序列内容 */
    @Column(name = "fasta_content", columnDefinition = "TEXT")
    private String fastaContent;

    /** 建树方法（UPGMA / NJ） */
    @Column(name = "method")
    private String method;

    /** 生成的Newick格式树 */
    @Column(name = "tree_result", columnDefinition = "TEXT")
    private String treeResult;

    /** 距离矩阵（JSON字符串） */
    @Column(name = "distance_matrix", columnDefinition = "TEXT")
    private String distanceMatrix;

    /** 序列数量 */
    @Column(name = "sequence_count")
    private Integer sequenceCount;

    /** 创建时间 */
    @Column(name = "created_at")
    private LocalDateTime createdAt;

    public AnalysisRecord() {
        this.createdAt = LocalDateTime.now();
    }

    public AnalysisRecord(String fileName, String fastaContent, String method,
                          String treeResult, String distanceMatrix, Integer sequenceCount) {
        this.fileName = fileName;
        this.fastaContent = fastaContent;
        this.method = method;
        this.treeResult = treeResult;
        this.distanceMatrix = distanceMatrix;
        this.sequenceCount = sequenceCount;
        this.createdAt = LocalDateTime.now();
    }

    // ===== Getters & Setters =====

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getFileName() {
        return fileName;
    }

    public void setFileName(String fileName) {
        this.fileName = fileName;
    }

    public String getFastaContent() {
        return fastaContent;
    }

    public void setFastaContent(String fastaContent) {
        this.fastaContent = fastaContent;
    }

    public String getMethod() {
        return method;
    }

    public void setMethod(String method) {
        this.method = method;
    }

    public String getTreeResult() {
        return treeResult;
    }

    public void setTreeResult(String treeResult) {
        this.treeResult = treeResult;
    }

    public String getDistanceMatrix() {
        return distanceMatrix;
    }

    public void setDistanceMatrix(String distanceMatrix) {
        this.distanceMatrix = distanceMatrix;
    }

    public Integer getSequenceCount() {
        return sequenceCount;
    }

    public void setSequenceCount(Integer sequenceCount) {
        this.sequenceCount = sequenceCount;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }

    @Override
    public String toString() {
        return "AnalysisRecord{id=" + id + ", fileName='" + fileName + "', method='" + method
                + "', sequenceCount=" + sequenceCount + ", createdAt=" + createdAt + "}";
    }
}
