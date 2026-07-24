package com.phylo.model.entity;

import jakarta.persistence.*;

/**
 * 物种实体类
 */
@Entity
@Table(name = "species")
public class Species {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer sid;

    @Column
    private Integer uid;

    @Column(length = 50)
    private String sname;

    @Column(length = 50)
    private String taxonomyId;

    @Column(columnDefinition = "TEXT")
    private String sdescription;

    public Species() {}

    public Species(Integer uid, String sname, String taxonomyId, String sdescription) {
        this.uid = uid;
        this.sname = sname;
        this.taxonomyId = taxonomyId;
        this.sdescription = sdescription;
    }

    public Integer getSid() { return sid; }
    public void setSid(Integer sid) { this.sid = sid; }
    public Integer getUid() { return uid; }
    public void setUid(Integer uid) { this.uid = uid; }
    public String getSname() { return sname; }
    public void setSname(String sname) { this.sname = sname; }
    public String getTaxonomyId() { return taxonomyId; }
    public void setTaxonomyId(String taxonomyId) { this.taxonomyId = taxonomyId; }
    public String getSdescription() { return sdescription; }
    public void setSdescription(String sdescription) { this.sdescription = sdescription; }
}
