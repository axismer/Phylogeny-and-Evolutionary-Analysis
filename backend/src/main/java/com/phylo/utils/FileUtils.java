package com.phylo.utils;

import java.io.IOException;
import java.nio.charset.StandardCharsets;

import org.springframework.web.multipart.MultipartFile;

/**
 * 文件处理工具类
 */
public class FileUtils {

    /**
     * 读取上传文件的文本内容
     *
     * @param file 上传的文件
     * @return 文件文本内容
     * @throws IOException 读取失败时抛出
     */
    public static String readAsString(MultipartFile file) throws IOException {
        return new String(file.getBytes(), StandardCharsets.UTF_8);
    }

    /**
     * 验证文件扩展名是否为FASTA格式
     *
     * @param filename 文件名
     * @return 是否为有效的FASTA文件
     */
    public static boolean isFastaFile(String filename) {
        if (filename == null || filename.isBlank()) {
            return false;
        }
        String lower = filename.toLowerCase();
        return lower.endsWith(".fasta") || lower.endsWith(".fa") || lower.endsWith(".fas");
    }
}
