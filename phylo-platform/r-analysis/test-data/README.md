# test-data — 真实 FASTA 测试目录

本目录用于在**不改动建树核心逻辑**的前提下，用真实（或平台已有）DNA 数据验证 R 分析引擎。

示例玩具数据仍使用：`../data/example.fasta` → `../output/`。

## 目录约定

```text
r-analysis/test-data/
├── README.md                 # 本说明
├── input.fasta               # 【你放入】待分析的多序列 FASTA（可改名，见下）
├── platform_16s.fasta        # 【可选】由仓库 data/raw 合并生成的 16S 集合
└── output/                   # 真实数据运行结果输出目录
    ├── distance_matrix.csv
    ├── tree.nwk
    ├── tree.png
    └── analysis_result.json
```

## 如何替换为真实 FASTA 并运行

### 方式 A：直接替换 / 放入单个 FASTA

1. 准备**一个** FASTA 文件，内含 **≥ 3 条** DNA 序列（多物种/多样本）。
2. 复制到本目录，命名为 `input.fasta`（或任意名，运行时传入路径即可）。
3. 在 PowerShell 中执行：

```powershell
cd d:\Projects\phylo-platform\r-analysis\scripts

Rscript phylogenetic_tree.R ..\test-data\input.fasta ..\test-data\output
```

成功后检查：

- `..\test-data\output\tree.nwk`
- `..\test-data\output\tree.png`
- `..\test-data\output\analysis_result.json`
- （同时会有 `distance_matrix.csv`）

### 方式 B：使用本仓库已有 16S raw（合并后再跑）

平台 Java 侧 `data/raw/` 下是「一文件一物种」。R 引擎需要**单文件多序列** FASTA。可先合并：

```powershell
cd d:\Projects\phylo-platform\r-analysis\scripts

Rscript prepare_platform_fasta.R
Rscript phylogenetic_tree.R ..\test-data\platform_16s.fasta ..\test-data\output
```

或一键：

```powershell
cd d:\Projects\phylo-platform\r-analysis\scripts
.\run_test_real_data.ps1
```

### 方式 C：保留 example 冒烟测试（玩具数据）

```powershell
cd d:\Projects\phylo-platform\r-analysis\scripts
.\run_test_example.ps1
```

等价于：

```powershell
Rscript phylogenetic_tree.R ..\data\example.fasta ..\output
```

## 输入建议（真实数据）

| 项 | 建议 |
|----|------|
| 格式 | 标准 FASTA，DNA |
| 条数 | ≥ 3 |
| 标签 | `>Species_name` 尽量简短、无奇怪符号 |
| 比对 | **强烈建议先做 MSA** 再喂给引擎；长度不一致时脚本可能补 gap / 调 MUSCLE，非正式科研预处理 |
| 长度 | 16S 等长片段或已比对排列最稳妥 |

## 输出含义（与主引擎相同）

| 文件 | 说明 |
|------|------|
| `tree.nwk` | ML（JC69）树 Newick |
| `tree.png` | 树图 |
| `analysis_result.json` | `status` / `method` / `model` / 文件名摘要 |
| `distance_matrix.csv` | K80 距离矩阵 |

## Outgroup（生根）说明 — 仅评估，当前未改代码

当前 `build_tree()` 在 `pml` + `optim.pml` **之后**执行：

```r
ape::root(fit$tree, outgroup = fit$tree$tip.label[1], ...)
```

即用**第一条 tip 标签**作展示用外群。

| 方案 | 含义 | 建议 |
|------|------|------|
| 保持 `tip.label[1]` | 实现简单，但外群**任意**，解释拓扑时易误导 | 仅适合 demo |
| 默认无根树写出 `tree.nwk` | 更符合 ML 无根本质；展示时再临时生根 | **科研输出更稳妥** |
| 增加 `outgroup` 参数（CLI/配置） | 由用户指定可靠外群；未指定则无根或中点生根 | **推荐后续增强**（不改 pml/optim.pml） |

**结论（评估）：** 不应把 `tip.label[1]` 当作生物学外群；后续宜增加可选 `outgroup`，默认对 Newick 保持无根或明确标注「仅显示用根」。本次为遵守「不修改建树核心逻辑」，**未改** `build_tree` 中的 `pml` / `optim.pml` / 现有生根行。
