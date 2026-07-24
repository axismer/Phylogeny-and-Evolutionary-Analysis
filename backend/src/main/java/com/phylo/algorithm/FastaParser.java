package com.phylo.algorithm;

import com.phylo.model.Sequence;

import java.util.ArrayList;
import java.util.List;

/**
 * FASTA格式解析器
 * 
 * FASTA格式示例：
 * >Species_A
 * ATCGATCG
 * >Species_B
 * ATGGATCG
 */
public class FastaParser {

    /**
     * 解析FASTA格式的文本内容，返回序列列表
     *
     * @param fastaContent FASTA文件的文本内容
     * @return 解析后的序列列表
     */
    public List<Sequence> parse(String fastaContent) {
        List<Sequence> sequences = new ArrayList<>();

        if (fastaContent == null || fastaContent.isBlank()) {
            return sequences;
        }

        String[] lines = fastaContent.split("\\r?\\n");
        String currentName = null;
        StringBuilder currentSeq = new StringBuilder();

        for (String line : lines) {
            line = line.trim();
            if (line.isEmpty()) {
                continue;
            }

            if (line.startsWith(">")) {
                // 保存上一条序列
                if (currentName != null) {
                    sequences.add(new Sequence(currentName, currentSeq.toString()));
                }
                // 开始新序列（去掉 '>' 前缀）
                currentName = line.substring(1).trim();
                currentSeq = new StringBuilder();
            } else {
                // 序列行，拼接（支持多行序列）
                currentSeq.append(line.replaceAll("\\s+", ""));
            }
        }

        // 保存最后一条序列
        if (currentName != null) {
            sequences.add(new Sequence(currentName, currentSeq.toString()));
        }

        return sequences;
    }
}
