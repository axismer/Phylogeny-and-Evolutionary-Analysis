package com.phylo.repository;

import com.phylo.model.entity.SequenceEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface SequenceRepository extends JpaRepository<SequenceEntity, Integer> {
    List<SequenceEntity> findByUid(Integer uid);
    List<SequenceEntity> findByDid(Integer did);
    List<SequenceEntity> findBySid(Integer sid);
    List<SequenceEntity> findByUidAndDid(Integer uid, Integer did);
}
