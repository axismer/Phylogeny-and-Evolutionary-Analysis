package com.phylo.model;

import java.util.List;

/**
 * 分析结果 - 返回给前端的完整JSON结构
 */
public class AnalysisResult {

    /** 序列基本信息列表 */
    private List<SequenceInfo> sequences;
    
    /** 距离矩阵 */
    private DistanceMatrix distanceMatrix;
    
    /** Newick 格式的系统发育树 */
    private String tree;
    
    /** 使用的建树方法 */
    private String method;
    
    /** R 绘制的环状树图片 (base64) */
    private String circularTreeImage;
    
    public AnalysisResult() {
    }

    public AnalysisResult(List<SequenceInfo> sequences, DistanceMatrix distanceMatrix, String tree) {
        this.sequences = sequences;
        this.distanceMatrix = distanceMatrix;
        this.tree = tree;
    }

    public AnalysisResult(List<SequenceInfo> sequences, DistanceMatrix distanceMatrix, String tree, String method) {
        this.sequences = sequences;
        this.distanceMatrix = distanceMatrix;
        this.tree = tree;
        this.method = method;
    }

    public List<SequenceInfo> getSequences() {
        return sequences;
    }

    public void setSequences(List<SequenceInfo> sequences) {
        this.sequences = sequences;
    }

    public DistanceMatrix getDistanceMatrix() {
        return distanceMatrix;
    }

    public void setDistanceMatrix(DistanceMatrix distanceMatrix) {
        this.distanceMatrix = distanceMatrix;
    }

    public String getTree() {
        return tree;
    }

    public void setTree(String tree) {
        this.tree = tree;
    }

    public String getMethod() {
        return method;
    }

    public void setMethod(String method) {
        this.method = method;
    }

    public String getCircularTreeImage() {
        return circularTreeImage;
    }

    public void setCircularTreeImage(String circularTreeImage) {
        this.circularTreeImage = circularTreeImage;
    }

    /**
     * 序列摘要信息（不暴露完整序列内容）
     */
    public static class SequenceInfo {
        private String name;
        private int length;

        public SequenceInfo() {
        }

        public SequenceInfo(String name, int length) {
            this.name = name;
            this.length = length;
        }

        public String getName() {
            return name;
        }

        public void setName(String name) {
            this.name = name;
        }

        public int getLength() {
            return length;
        }

        public void setLength(int length) {
            this.length = length;
        }
    }
}
