package com.phylo.repository;

import com.phylo.model.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

/**
 * 用户数据访问接口
 */
@Repository
public interface UserRepository extends JpaRepository<User, Long> {

    /** 根据用户名查找用户 */
    Optional<User> findByUsername(String username);

    /** 根据Token查找用户 */
    Optional<User> findByToken(String token);

    /** 检查用户名是否已存在 */
    boolean existsByUsername(String username);

    /** 检查邮箱是否已存在 */
    boolean existsByEmail(String email);
}
