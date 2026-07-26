package com.phylo.service;

import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.multipart.MultipartFile;

import java.io.*;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.*;

/**
 * R 语言分析服务 - 使用 Bioconductor/ggtree 绘制专业系统发育树
 */
@Service
public class RAnalysisService {

    private static final String R_SCRIPT_DIR = "r-analysis/scripts";
    
    /**
     * 使用 R 语言绘制环状系统发育树
     * 
     * @param newickTree Newick 格式的树字符串
     * @param seqNames 序列名称列表（用于注释）
     * @return PNG 图片的 base64 编码
     */
    public String drawCircularTree(String newickTree, List<String> seqNames) throws Exception {
        // 创建临时 R 脚本
        String rScript = createRScript(newickTree, seqNames);
        
        // 执行 R 脚本
        String outputBase64 = executeRScript(rScript);
        
        return outputBase64;
    }
    
    /**
     * 创建 R 脚本来绘制环状树
     */
    private String createRScript(String newickTree, List<String> seqNames) {
        StringBuilder sb = new StringBuilder();
        sb.append("# 系统发育树可视化 - 使用 R 语言和 ggtree\n");
        sb.append("# Phylogenetic Tree Visualization with ggtree\n\n");
        
        sb.append("# 加载必要的包\n");
        sb.append("library(ape)\n");
        sb.append("library(ggtree)\n");
        sb.append("library(ggplot2)\n\n");
        
        // 写入 Newick 树到临时文件
        sb.append("# 读取 Newick 树\n");
        sb.append("newick <- \"").append(escapeRString(newickTree)).append("\"\n");
        sb.append("tree <- read.tree(text=newick)\n\n");
        
        // 创建环形树的 ggplot 绘图
        sb.append("# 绘制环状系统发育树\n");
        sb.append("p <- ggtree(tree, layout=\"circular\") +\n");
        sb.append("  geom_tiplab(size=3, hjust=0.5, angle=\"horizontal\", fill=\"black\") +\n");
        sb.append("  geom_root_node(size=5, color=\"#e74c3c\") +\n");
        sb.append("  geom_branch(color=\"#4a90d9\", size=0.5) +\n");
        sb.append("  theme_bw() +\n");
        sb.append("  theme(\n");
        sb.append("    plot.background = element_rect(fill=\"white\", color=NA),\n");
        sb.append("    panel.grid = element_blank(),\n");
        sb.append("    axis.text = element_blank(),\n");
        sb.append("    axis.ticks = element_blank(),\n");
        sb.append("    legend.position = \"right\"\n");
        sb.append("  ) +\n");
        sb.append("  ggtitle(\"系统发育树 - Circular Phylogenetic Tree\") +\n");
        sb.append("  guides(color=guide_legend(title=\"Phylogeny\")))\n\n");
        
        // 保存图片
        sb.append("# 输出 PNG 图片 (1200x1200 分辨率)\n");
        sb.append("png(\"output.png\", width=1200, height=1200, res=150)\n");
        sb.append("print(p)\n");
        sb.append("dev.off()\n\n");
        
        // 读取图片并输出为 base64
        sb.append("# 将图片转换为 base64 输出\n");
        sb.append("img <- readPNG(\"output.png\")\n");
        sb.append("# R 中没有直接的 base64 编码，这里我们保存文件由 Java 读取\n");
        sb.append("cat(\"Image saved to output.png\\n\")\n");
        
        return sb.toString();
    }
    
    /**
     * 执行 R 脚本
     */
    private String executeRScript(String rScriptContent) throws Exception {
        // 创建临时 R 脚本文件
        Path tempScript = Files.createTempFile("phylo_tree", ".R");
        Files.write(tempScript, rScriptContent.getBytes("UTF-8"));
        
        try {
            // 执行 R 脚本
            ProcessBuilder pb = new ProcessBuilder(
                "Rscript", 
                tempScript.toString()
            );
            pb.redirectErrorStream(true);
            Process process = pb.start();
            
            // 等待执行完成
            int exitCode = process.waitFor();
            if (exitCode != 0) {
                throw new RuntimeException("R 脚本执行失败，退出码：" + exitCode);
            }
            
            // 读取生成的图片
            Path outputPath = Paths.get("output.png");
            if (!Files.exists(outputPath)) {
                throw new FileNotFoundException("R 脚本未生成 output.png 文件");
            }
            
            byte[] imageBytes = Files.readAllBytes(outputPath);
            
            // 删除临时文件
            Files.deleteIfExists(tempScript);
            Files.deleteIfExists(outputPath);
            
            // 返回 base64 编码
            return Base64.getEncoder().encodeToString(imageBytes);
            
        } catch (IOException e) {
            Files.deleteIfExists(tempScript);
            throw new RuntimeException("执行 R 脚本失败：" + e.getMessage(), e);
        }
    }
    
    /**
     * 转义 R 字符串中的特殊字符
     */
    private String escapeRString(String input) {
        return input
            .replace("\\", "\\\\")
            .replace("\"", "\\\"")
            .replace("\n", "\\n")
            .replace("\r", "\\r")
            .replace("\t", "\\t");
    }
    
    /**
     * 验证 R 环境是否可用
     */
    public boolean isREnvironmentAvailable() {
        try {
            ProcessBuilder pb = new ProcessBuilder("Rscript", "--version");
            Process process = pb.start();
            int exitCode = process.waitFor();
            return exitCode == 0;
        } catch (Exception e) {
            return false;
        }
    }
}
