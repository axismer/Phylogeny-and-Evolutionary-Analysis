package com.phylo.repository;

import com.phylo.model.entity.Dataset;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface DatasetRepository extends JpaRepository<Dataset, Integer> {
    List<Dataset> findByUid(Integer uid);
    List<Dataset> findByUidOrderByDidDesc(Integer uid);
}
