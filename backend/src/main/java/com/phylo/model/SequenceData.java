package com.phylo.model;

import jakarta.persistence.*;
import java.time.LocalDateTime;

/**
 * 序列数据实体类 - 存储默认/用户提交的FASTA序列数据
 * 
 * 每条记录代表一个FASTA文件（可包含多条序列）
 */
@Entity
@Table(name = "sequence_data")
public class SequenceData {

    /** 主键ID，自增 */
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** 数据集名称（如：E.coli 16S rRNA） */
    @Column(name = "name", nullable = false)
    private String name;

    /** 物种/来源描述 */
    @Column(name = "description")
    private String description;

    /** FASTA格式的序列内容（完整文本） */
    @Column(name = "fasta_content", columnDefinition = "LONGTEXT", nullable = false)
    private String fastaContent;

    /** 序列条数 */
    @Column(name = "sequence_count")
    private Integer sequenceCount;

    /** 数据来源：DEFAULT=系统默认, USER=用户上传 */
    @Column(name = "source", nullable = false)
    private String source;

    /** 原始文件名 */
    @Column(name = "file_name")
    private String fileName;

    /** 所属用户ID（用户上传时关联） */
    @Column(name = "user_id")
    private Long userId;

    /** 创建时间 */
    @Column(name = "created_at")
    private LocalDateTime createdAt;

    public SequenceData() {
        this.createdAt = LocalDateTime.now();
    }

    public SequenceData(String name, String description, String fastaContent,
                        Integer sequenceCount, String source, String fileName) {
        this.name = name;
        this.description = description;
        this.fastaContent = fastaContent;
        this.sequenceCount = sequenceCount;
        this.source = source;
        this.fileName = fileName;
        this.createdAt = LocalDateTime.now();
    }

    public SequenceData(String name, String description, String fastaContent,
                        Integer sequenceCount, String source, String fileName, Long userId) {
        this.name = name;
        this.description = description;
        this.fastaContent = fastaContent;
        this.sequenceCount = sequenceCount;
        this.source = source;
        this.fileName = fileName;
        this.userId = userId;
        this.createdAt = LocalDateTime.now();
    }

    // ===== Getters & Setters =====

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public String getFastaContent() {
        return fastaContent;
    }

    public void setFastaContent(String fastaContent) {
        this.fastaContent = fastaContent;
    }

    public Integer getSequenceCount() {
        return sequenceCount;
    }

    public void setSequenceCount(Integer sequenceCount) {
        this.sequenceCount = sequenceCount;
    }

    public String getSource() {
        return source;
    }

    public void setSource(String source) {
        this.source = source;
    }

    public String getFileName() {
        return fileName;
    }

    public void setFileName(String fileName) {
        this.fileName = fileName;
    }

    public Long getUserId() {
        return userId;
    }

    public void setUserId(Long userId) {
        this.userId = userId;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }

    @Override
    public String toString() {
        return "SequenceData{id=" + id + ", name='" + name + "', source='" + source
                + "', sequenceCount=" + sequenceCount + ", createdAt=" + createdAt + "}";
    }
}
