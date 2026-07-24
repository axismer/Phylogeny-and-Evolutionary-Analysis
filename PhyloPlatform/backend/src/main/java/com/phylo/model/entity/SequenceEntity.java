package com.phylo.model.entity;

import jakarta.persistence.*;

/**
 * 序列实体类 - 存储序列文件路径及元数据
 */
@Entity
@Table(name = "sequence")
public class SequenceEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer seid;

    @Column
    private Integer sid;

    @Column
    private Integer uid;

    @Column
    private Integer did;

    @Column(length = 100)
    private String accession;

    @Column(length = 50)
    private String sename;

    @Column(length = 255)
    private String filePath;

    @Column
    private Integer seLength;

    @Column(length = 10)
    private String ssource;

    public SequenceEntity() {}

    public SequenceEntity(Integer sid, Integer uid, Integer did, String accession,
                          String sename, String filePath, Integer seLength, String ssource) {
        this.sid = sid;
        this.uid = uid;
        this.did = did;
        this.accession = accession;
        this.sename = sename;
        this.filePath = filePath;
        this.seLength = seLength;
        this.ssource = ssource;
    }

    public Integer getSeid() { return seid; }
    public void setSeid(Integer seid) { this.seid = seid; }
    public Integer getSid() { return sid; }
    public void setSid(Integer sid) { this.sid = sid; }
    public Integer getUid() { return uid; }
    public void setUid(Integer uid) { this.uid = uid; }
    public Integer getDid() { return did; }
    public void setDid(Integer did) { this.did = did; }
    public String getAccession() { return accession; }
    public void setAccession(String accession) { this.accession = accession; }
    public String getSename() { return sename; }
    public void setSename(String sename) { this.sename = sename; }
    public String getFilePath() { return filePath; }
    public void setFilePath(String filePath) { this.filePath = filePath; }
    public Integer getSeLength() { return seLength; }
    public void setSeLength(Integer seLength) { this.seLength = seLength; }
    public String getSsource() { return ssource; }
    public void setSsource(String ssource) { this.ssource = ssource; }
}
