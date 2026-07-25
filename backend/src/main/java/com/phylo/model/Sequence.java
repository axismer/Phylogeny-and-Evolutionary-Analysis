package com.phylo.model;

/**
 * 表示一条DNA/蛋白质序列
 */
public class Sequence {

    /** 序列名称（来自FASTA的 > 行） */
    private String name;

    /** 序列内容（碱基/氨基酸字符串） */
    private String sequence;

    public Sequence() {
    }

    public Sequence(String name, String sequence) {
        this.name = name;
        this.sequence = sequence;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getSequence() {
        return sequence;
    }

    public void setSequence(String sequence) {
        this.sequence = sequence;
    }

    /** 获取序列长度 */
    public int getLength() {
        return sequence == null ? 0 : sequence.length();
    }

    @Override
    public String toString() {
        return "Sequence{name='" + name + "', length=" + getLength() + "}";
    }
}
