package com.phylo.repository;

import com.phylo.model.SequenceData;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

/**
 * 序列数据访问接口
 */
@Repository
public interface SequenceDataRepository extends JpaRepository<SequenceData, Long> {

    /** 按数据来源查询（DEFAULT / USER） */
    List<SequenceData> findBySourceOrderByCreatedAtDesc(String source);

    /** 查询所有默认数据（按创建时间正序） */
    List<SequenceData> findBySourceOrderByCreatedAtAsc(String source);

    /** 按名称模糊查询 */
    List<SequenceData> findByNameContainingOrderByCreatedAtDesc(String name);

    /** 检查是否已存在同名默认数据（避免重复导入） */
    boolean existsByNameAndSource(String name, String source);

    /** 按创建时间倒序查询所有 */
    List<SequenceData> findAllByOrderByCreatedAtDesc();

    /** 按用户ID查询该用户保存的序列（按时间倒序） */
    List<SequenceData> findByUserIdOrderByCreatedAtDesc(Long userId);
}
