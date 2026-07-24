package com.phylo.model.entity;

import jakarta.persistence.*;

/**
 * 数据集实体类
 */
@Entity
@Table(name = "dataset")
public class Dataset {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer did;

    @Column
    private Integer uid;

    @Column(length = 50)
    private String dname;

    @Column(length = 10)
    private String source;

    @Column(columnDefinition = "TEXT")
    private String ddescription;

    @Column(length = 10)
    private String dstatus;

    public Dataset() {}

    public Dataset(Integer uid, String dname, String source, String ddescription, String dstatus) {
        this.uid = uid;
        this.dname = dname;
        this.source = source;
        this.ddescription = ddescription;
        this.dstatus = dstatus;
    }

    public Integer getDid() { return did; }
    public void setDid(Integer did) { this.did = did; }
    public Integer getUid() { return uid; }
    public void setUid(Integer uid) { this.uid = uid; }
    public String getDname() { return dname; }
    public void setDname(String dname) { this.dname = dname; }
    public String getSource() { return source; }
    public void setSource(String source) { this.source = source; }
    public String getDdescription() { return ddescription; }
    public void setDdescription(String ddescription) { this.ddescription = ddescription; }
    public String getDstatus() { return dstatus; }
    public void setDstatus(String dstatus) { this.dstatus = dstatus; }
}
