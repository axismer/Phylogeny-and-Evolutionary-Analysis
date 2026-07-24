package com.phylo.repository;

import com.phylo.model.AnalysisRecord;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

/**
 * 分析记录数据访问接口
 */
@Repository
public interface AnalysisRecordRepository extends JpaRepository<AnalysisRecord, Long> {

    /** 按创建时间倒序查询所有记录 */
    List<AnalysisRecord> findAllByOrderByCreatedAtDesc();

    /** 按建树方法查询记录 */
    List<AnalysisRecord> findByMethodOrderByCreatedAtDesc(String method);

    /** 按文件名模糊查询 */
    List<AnalysisRecord> findByFileNameContainingOrderByCreatedAtDesc(String fileName);
}
