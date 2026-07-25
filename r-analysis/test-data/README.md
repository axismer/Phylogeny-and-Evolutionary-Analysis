# test-data — 真实 FASTA 测试目录

本目录用于在**不改动建树核心逻辑**的前提下，用真实（或平台已有）DNA 数据验证 R 分析引擎。

示例玩具数据：`../data/smoke/example.fasta` → `../output/tasks/example/`。

## 目录约定

```text
r-analysis/test-data/
├── README.md
├── input.fasta               # 【你放入】待分析多序列 FASTA
├── fixtures/
│   ├── platform_16s.fasta    # 由仓库 data/raw 合并
│   ├── platform_16s_equal_len.fasta
│   └── h3n2_na_20.fasta
└── output/                   # 真实数据运行结果
```

## 如何运行

### 方式 A：放入 input.fasta

```powershell
cd d:\Projects\phylo-platform\r-analysis
Rscript engine\phylogenetic_tree.R test-data\input.fasta test-data\output
```

### 方式 B：平台 16S 合并

```powershell
cd d:\Projects\phylo-platform\r-analysis
Rscript scripts\prep\prepare_platform_fasta.R
Rscript engine\phylogenetic_tree.R test-data\fixtures\platform_16s.fasta test-data\output
```

或：

```powershell
cd d:\Projects\phylo-platform\r-analysis\scripts\runners
.\run_test_real_data.ps1
```

### 方式 C：example 冒烟

```powershell
cd d:\Projects\phylo-platform\r-analysis\scripts\runners
.\run_test_example.ps1
```

## 输入建议

| 项 | 建议 |
|----|------|
| 格式 | 标准 FASTA，DNA |
| 条数 | ≥ 3 |
| 比对 | 强烈建议先做 MSA |

## 输出

| 文件 | 说明 |
|------|------|
| `tree.nwk` | ML（JC69）Newick |
| `tree.png` | 树图 |
| `analysis_result.json` | 状态摘要 |
| `distance_matrix.csv` | K80 距离矩阵 |
