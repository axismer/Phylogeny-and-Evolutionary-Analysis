package com.phylo.controller;

import com.phylo.model.User;
import com.phylo.repository.UserRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/**
 * 用户认证控制器
 *
 * POST /api/auth/register - 用户注册
 * POST /api/auth/login    - 用户登录
 * GET  /api/auth/verify   - 验证Token有效性
 * POST /api/auth/logout   - 退出登录
 */
@RestController
@RequestMapping("/api/auth")
@CrossOrigin(origins = "*")
public class AuthController {

    private final UserRepository userRepository;

    public AuthController(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    /**
     * 用户注册
     */
    @PostMapping("/register")
    public ResponseEntity<?> register(@RequestBody Map<String, String> body) {
        String username = body.get("username") != null ? body.get("username").trim() : null;
        String password = body.get("password");
        String email = body.get("email") != null ? body.get("email").trim() : null;

        // 参数校验
        if (username == null || username.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("error", "用户名不能为空"));
        }
        if (username.length() < 2 || username.length() > 20) {
            return ResponseEntity.badRequest().body(Map.of("error", "用户名长度为2-20个字符"));
        }
        if (password == null || password.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("error", "密码不能为空"));
        }
        if (password.length() < 6) {
            return ResponseEntity.badRequest().body(Map.of("error", "密码长度至少6位"));
        }

        // 检查用户名是否已存在
        if (userRepository.existsByUsername(username)) {
            return ResponseEntity.badRequest().body(Map.of("error", "用户名已存在"));
        }

        // 检查邮箱是否已存在
        if (email != null && !email.isBlank() && userRepository.existsByEmail(email)) {
            return ResponseEntity.badRequest().body(Map.of("error", "邮箱已被注册"));
        }

        // 创建用户（密码加密存储）
        User user = new User(username, hashPassword(password), email);
        userRepository.save(user);

        return ResponseEntity.ok(Map.of(
            "message", "注册成功",
            "username", username
        ));
    }

    /**
     * 用户登录
     */
    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody Map<String, String> body) {
        String username = body.get("username") != null ? body.get("username").trim() : null;
        String password = body.get("password");

        if (username == null || username.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("error", "请输入用户名"));
        }
        if (password == null || password.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("error", "请输入密码"));
        }

        // 查找用户
        Optional<User> optUser = userRepository.findByUsername(username);
        if (optUser.isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("error", "用户名或密码错误"));
        }

        User user = optUser.get();

        // 验证密码
        if (!user.getPassword().equals(hashPassword(password))) {
            return ResponseEntity.badRequest().body(Map.of("error", "用户名或密码错误"));
        }

        // 生成Token
        String token = UUID.randomUUID().toString().replace("-", "")
                     + UUID.randomUUID().toString().replace("-", "").substring(0, 32);
        user.setToken(token);
        user.setLastLoginAt(LocalDateTime.now());
        userRepository.save(user);

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("message", "登录成功");
        result.put("token", token);
        result.put("username", user.getUsername());
        result.put("email", user.getEmail());

        return ResponseEntity.ok(result);
    }

    /**
     * 验证Token有效性
     */
    @GetMapping("/verify")
    public ResponseEntity<?> verify(@RequestHeader(value = "Authorization", required = false) String authHeader) {
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            return ResponseEntity.status(401).body(Map.of("error", "未登录"));
        }

        String token = authHeader.substring(7);
        Optional<User> optUser = userRepository.findByToken(token);

        if (optUser.isEmpty()) {
            return ResponseEntity.status(401).body(Map.of("error", "登录已过期，请重新登录"));
        }

        User user = optUser.get();
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("valid", true);
        result.put("username", user.getUsername());
        result.put("email", user.getEmail());

        return ResponseEntity.ok(result);
    }

    /**
     * 退出登录
     */
    @PostMapping("/logout")
    public ResponseEntity<?> logout(@RequestHeader(value = "Authorization", required = false) String authHeader) {
        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            String token = authHeader.substring(7);
            userRepository.findByToken(token).ifPresent(user -> {
                user.setToken(null);
                userRepository.save(user);
            });
        }
        return ResponseEntity.ok(Map.of("message", "已退出登录"));
    }

    /**
     * 密码哈希（SHA-256）
     */
    private String hashPassword(String password) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(password.getBytes(StandardCharsets.UTF_8));
            StringBuilder hexString = new StringBuilder();
            for (byte b : hash) {
                String hex = Integer.toHexString(0xff & b);
                if (hex.length() == 1) hexString.append('0');
                hexString.append(hex);
            }
            return hexString.toString();
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException("密码加密失败", e);
        }
    }
}
