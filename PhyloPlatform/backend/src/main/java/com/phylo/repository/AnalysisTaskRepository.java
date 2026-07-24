package com.phylo.repository;

import com.phylo.model.entity.AnalysisTask;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface AnalysisTaskRepository extends JpaRepository<AnalysisTask, Integer> {
    List<AnalysisTask> findByUidOrderByCreatedAtDesc(Integer uid);
    List<AnalysisTask> findByUidAndDid(Integer uid, Integer did);
}
