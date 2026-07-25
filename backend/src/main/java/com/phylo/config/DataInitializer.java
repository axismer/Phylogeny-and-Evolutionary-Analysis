package com.phylo.config;

import com.phylo.algorithm.FastaParser;
import com.phylo.model.Sequence;
import com.phylo.model.SequenceData;
import com.phylo.model.User;
import com.phylo.repository.SequenceDataRepository;
import com.phylo.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.List;

/**
 * 数据初始化器 - 应用启动时自动将默认FASTA数据导入MySQL数据库
 * 
 * 从配置的目录（默认为 ../数据）读取所有 .fasta 文件，
 * 解析后存入 sequence_data 表（source = "DEFAULT"）。
 * 已存在的数据不会重复导入。
 */
@Component
public class DataInitializer implements CommandLineRunner {

    private static final Logger log = LoggerFactory.getLogger(DataInitializer.class);

    private final SequenceDataRepository sequenceDataRepository;
    private final UserRepository userRepository;
    private final FastaParser fastaParser = new FastaParser();

    @Value("${phylo.default-data-path:../数据}")
    private String defaultDataPath;

    public DataInitializer(SequenceDataRepository sequenceDataRepository, UserRepository userRepository) {
        this.sequenceDataRepository = sequenceDataRepository;
        this.userRepository = userRepository;
    }

    @Override
    public void run(String... args) {
        initDefaultUser();
        log.info("====== 开始初始化默认序列数据 ======");
        log.info("当前工作目录: {}", Paths.get("").toAbsolutePath());

        // 尝试多个可能的路径（兼容不同的工作目录设置）
        Path dataDir = resolveDataDir();
        if (dataDir == null) {
            log.warn("未找到默认数据目录，已尝试路径: [{}], [{}], [{}]，跳过初始化",
                    Paths.get(defaultDataPath).toAbsolutePath(),
                    Paths.get("数据").toAbsolutePath(),
                    Paths.get("../数据").toAbsolutePath());
            return;
        }
        log.info("找到数据目录: {}", dataDir.toAbsolutePath());

        File[] fastaFiles = dataDir.toFile().listFiles((dir, name) -> {
            String lower = name.toLowerCase();
            return lower.endsWith(".fasta") || lower.endsWith(".fa") || lower.endsWith(".fas");
        });

        if (fastaFiles == null || fastaFiles.length == 0) {
            log.warn("数据目录中没有找到FASTA文件");
            return;
        }

        int imported = 0;
        int skipped = 0;

        for (File file : fastaFiles) {
            String dataName = extractName(file.getName());

            // 检查是否已导入
            if (sequenceDataRepository.existsByNameAndSource(dataName, "DEFAULT")) {
                skipped++;
                continue;
            }

            try {
                String content = Files.readString(file.toPath(), StandardCharsets.UTF_8);
                List<Sequence> sequences = fastaParser.parse(content);

                if (sequences.isEmpty()) {
                    log.warn("文件 {} 中未解析到序列，跳过", file.getName());
                    continue;
                }

                String description = buildDescription(sequences);

                SequenceData data = new SequenceData(
                    dataName,
                    description,
                    content,
                    sequences.size(),
                    "DEFAULT",
                    file.getName()
                );

                sequenceDataRepository.save(data);
                imported++;
                log.info("已导入: {} ({}条序列)", dataName, sequences.size());

            } catch (IOException e) {
                log.error("读取文件失败: {}", file.getName(), e);
            }
        }

        log.info("====== 数据初始化完成: 新导入 {} 个, 跳过 {} 个已存在 ======", imported, skipped);
    }

    /**
     * 解析数据目录 - 尝试多个可能的路径
     * 兼容从 backend/ 目录或项目根目录启动的情况
     */
    private Path resolveDataDir() {
        String[] candidates = {
            defaultDataPath,          // 配置的路径（../数据）
            "数据",                   // 当前目录下的数据文件夹
            "../数据",                // 上级目录的数据文件夹
            "./数据",                 // 显式当前目录
            "backend/../数据"          // 从项目根目录启动时
        };

        for (String candidate : candidates) {
            Path path = Paths.get(candidate);
            if (Files.exists(path) && Files.isDirectory(path)) {
                // 确认目录中有FASTA文件
                File[] files = path.toFile().listFiles((dir, name) -> {
                    String lower = name.toLowerCase();
                    return lower.endsWith(".fasta") || lower.endsWith(".fa") || lower.endsWith(".fas");
                });
                if (files != null && files.length > 0) {
                    return path;
                }
            }
        }
        return null;
    }

    /**
     * 从文件名提取数据集名称
     * 例如: "E.coli16S.fasta" -> "E.coli16S"
     */
    private String extractName(String fileName) {
        String name = fileName;
        // 去除扩展名
        int dotIndex = name.lastIndexOf('.');
        if (dotIndex > 0) {
            name = name.substring(0, dotIndex);
        }
        return name;
    }

    /**
     * 初始化默认管理员账号（admin / 123456）
     */
    private void initDefaultUser() {
        if (!userRepository.existsByUsername("admin")) {
            User admin = new User("admin", hashPassword("123456"), "admin@phylo.local");
            userRepository.save(admin);
            log.info("已创建默认管理员账号: admin / 123456");
        }
    }

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

    /**
     * 根据解析的序列构建描述信息
     */
    private String buildDescription(List<Sequence> sequences) {
        if (sequences.isEmpty()) return "";
        // 取第一条序列的名称作为描述基础
        String firstName = sequences.get(0).getName();
        return "包含 " + sequences.size() + " 条序列 | " + firstName;
    }
}
