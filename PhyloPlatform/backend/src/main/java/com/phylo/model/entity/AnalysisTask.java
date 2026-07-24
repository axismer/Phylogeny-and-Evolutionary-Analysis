package com.phylo.model.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

/**
 * 分析任务实体类
 */
@Entity
@Table(name = "analysis_task")
public class AnalysisTask {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer tid;

    @Column
    private Integer uid;

    @Column
    private Integer did;

    @Column(length = 20)
    private String ttype;

    @Column(length = 20)
    private String tstatus;

    @Column(length = 255)
    private String resultPath;

    @Column(columnDefinition = "TEXT")
    private String errorMsg;

    private LocalDateTime startedAt;
    private LocalDateTime completedAt;
    private LocalDateTime createdAt;

    public AnalysisTask() {
        this.createdAt = LocalDateTime.now();
    }

    public AnalysisTask(Integer uid, Integer did, String ttype, String tstatus) {
        this.uid = uid;
        this.did = did;
        this.ttype = ttype;
        this.tstatus = tstatus;
        this.createdAt = LocalDateTime.now();
    }

    public Integer getTid() { return tid; }
    public void setTid(Integer tid) { this.tid = tid; }
    public Integer getUid() { return uid; }
    public void setUid(Integer uid) { this.uid = uid; }
    public Integer getDid() { return did; }
    public void setDid(Integer did) { this.did = did; }
    public String getTtype() { return ttype; }
    public void setTtype(String ttype) { this.ttype = ttype; }
    public String getTstatus() { return tstatus; }
    public void setTstatus(String tstatus) { this.tstatus = tstatus; }
    public String getResultPath() { return resultPath; }
    public void setResultPath(String resultPath) { this.resultPath = resultPath; }
    public String getErrorMsg() { return errorMsg; }
    public void setErrorMsg(String errorMsg) { this.errorMsg = errorMsg; }
    public LocalDateTime getStartedAt() { return startedAt; }
    public void setStartedAt(LocalDateTime startedAt) { this.startedAt = startedAt; }
    public LocalDateTime getCompletedAt() { return completedAt; }
    public void setCompletedAt(LocalDateTime completedAt) { this.completedAt = completedAt; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
}
