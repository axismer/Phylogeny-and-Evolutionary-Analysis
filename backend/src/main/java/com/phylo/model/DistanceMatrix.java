package com.phylo.model;

import java.util.List;

/**
 * 表示距离矩阵
 * names: 序列名称列表
 * values: 二维距离数组
 */
public class DistanceMatrix {

    /** 序列名称列表 */
    private List<String> names;

    /** 距离矩阵（二维数组） */
    private double[][] values;

    public DistanceMatrix() {
    }

    public DistanceMatrix(List<String> names, double[][] values) {
        this.names = names;
        this.values = values;
    }

    public List<String> getNames() {
        return names;
    }

    public void setNames(List<String> names) {
        this.names = names;
    }

    public double[][] getValues() {
        return values;
    }

    public void setValues(double[][] values) {
        this.values = values;
    }

    /** 获取矩阵维度（物种数量） */
    public int getSize() {
        return names == null ? 0 : names.size();
    }
}
