package com.phylo.service;

import com.phylo.model.entity.User;
import com.phylo.repository.UserRepository;
import com.phylo.security.JwtUtil;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.Map;

/**
 * 用户认证服务
 */
@Service
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtil jwtUtil;

    public AuthService(UserRepository userRepository, PasswordEncoder passwordEncoder, JwtUtil jwtUtil) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtUtil = jwtUtil;
    }

    /**
     * 用户注册
     */
    public Map<String, Object> register(String uname, String password, String nickname, String email) {
        if (userRepository.existsByUname(uname)) {
            throw new IllegalArgumentException("用户名已存在");
        }
        if (email != null && !email.isBlank() && userRepository.existsByEmail(email)) {
            throw new IllegalArgumentException("邮箱已被注册");
        }

        User user = new User();
        user.setUname(uname);
        user.setUpassword(passwordEncoder.encode(password));
        user.setNickname(nickname != null ? nickname : uname);
        user.setRole("user");
        user.setEmail(email);

        user = userRepository.save(user);

        Map<String, Object> result = new HashMap<>();
        result.put("uid", user.getUid());
        result.put("uname", user.getUname());
        result.put("nickname", user.getNickname());
        result.put("message", "注册成功");
        return result;
    }

    /**
     * 用户登录
     */
    public Map<String, Object> login(String uname, String password) {
        User user = userRepository.findByUname(uname)
                .orElseThrow(() -> new IllegalArgumentException("用户名或密码错误"));

        if (!passwordEncoder.matches(password, user.getUpassword())) {
            throw new IllegalArgumentException("用户名或密码错误");
        }

        String token = jwtUtil.generateToken(user.getUid(), user.getUname());

        Map<String, Object> result = new HashMap<>();
        result.put("token", token);
        result.put("uid", user.getUid());
        result.put("uname", user.getUname());
        result.put("nickname", user.getNickname());
        result.put("role", user.getRole());
        return result;
    }

    /**
     * 获取用户信息
     */
    public Map<String, Object> getUserInfo(Integer uid) {
        User user = userRepository.findById(uid)
                .orElseThrow(() -> new IllegalArgumentException("用户不存在"));

        Map<String, Object> result = new HashMap<>();
        result.put("uid", user.getUid());
        result.put("uname", user.getUname());
        result.put("nickname", user.getNickname());
        result.put("role", user.getRole());
        result.put("email", user.getEmail());
        return result;
    }
}
