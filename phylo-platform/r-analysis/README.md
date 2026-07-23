# r-analysis — 独立系统发育分析引擎

基于 R（`ape` / `phangorn` / `ggplot2` / `ggtree`）的命令行分析模块，供本地运行或后续 Spring Boot 通过 `Rscript` 调用。

## 目录结构

```text
r-analysis/
├── data/
│   └── example.fasta              # 玩具示例（保留）
├── output/                        # example 测试输出
├── test-data/                     # 真实 FASTA 测试
│   ├── README.md                  # 如何替换真实数据并运行
│   ├── input.fasta                # （可选）你放入的真实 FASTA
│   ├── platform_16s.fasta         # （可选）由 data/raw 合并生成
│   └── output/                    # 真实数据运行输出
├── scripts/
│   ├── phylogenetic_tree.R        # 分析引擎入口
│   ├── prepare_platform_fasta.R   # 合并平台 raw → 单文件 FASTA
│   ├── run_test_example.ps1       # example 冒烟
│   └── run_test_real_data.ps1     # 真实数据一键测试
└── README.md
```

## 安装 R 依赖

环境要求：R ≥ 4.4（本项目按 R 4.4.2 验证）。

在 R 控制台执行：

```r
install.packages(c("ape", "phangorn", "ggplot2", "tidyverse", "jsonlite"))

# ggtree 来自 Bioconductor
if (!requireNamespace("BiocManager", quietly = TRUE)) {
  install.packages("BiocManager")
}
BiocManager::install("ggtree")
```

说明：

- **必需**：`ape`、`phangorn`、`ggplot2`
- **推荐**：`ggtree`（绘制 `tree.png`）；`jsonlite`（写 `analysis_result.json`，无则脚本手写 JSON）
- 若 `ggtree` 与当前 `ggplot2` 版本冲突，引擎会自动回退到 `ape::plot.phylo` 出图，不影响 CSV / Newick / JSON

可选：安装 [MUSCLE](https://www.drive5.com/muscle/) 并加入 PATH，可在序列长度不一致时调用 `ape::muscle` 做比对。

## 如何运行

### 1）示例数据（保留）

```powershell
cd d:\Projects\phylo-platform\r-analysis\scripts
.\run_test_example.ps1
```

或：

```powershell
Rscript phylogenetic_tree.R ..\data\example.fasta ..\output
```

### 2）真实 FASTA（test-data）

将多序列 FASTA 放到 `test-data/input.fasta`，或先合并平台 `data/raw`：

```powershell
cd d:\Projects\phylo-platform\r-analysis\scripts
.\run_test_real_data.ps1
```

手工调用：

```powershell
Rscript phylogenetic_tree.R ..\test-data\input.fasta ..\test-data\output
```

详细说明见 [`test-data/README.md`](test-data/README.md)。

命令行形式（固定）：

```bash
Rscript phylogenetic_tree.R input.fasta output_dir
```

成功时进程退出码为 `0`，失败为 `1`。

后续 Java 调用示意（不改本仓库 Java，仅说明）：

```text
Rscript <script> <fasta绝对路径> <output绝对路径>
```

## 分析流程

1. `read_fasta()` — 读取 DNA FASTA  
2. `align_sequences()` — 内部比对（等长跳过 / MUSCLE / 末端补 gap 回退）  
3. `calculate_distance()` — K80 距离 → `distance_matrix.csv`  
4. `build_tree()` — NJ 起步 + **Maximum Likelihood (JC69)**  
5. `save_newick()` — 写出 `tree.nwk`  
6. `plot_tree()` — 写出 `tree.png`  
7. `write_result_json()` — 写出 `analysis_result.json`

主结果树为 **ML（JC69）**；距离矩阵用于 NJ 起步与 CSV 导出。

## 输出文件含义

| 文件 | 含义 |
|------|------|
| `distance_matrix.csv` | 基于比对序列的 K80（Kimura 2-parameter）遗传距离矩阵 |
| `tree.nwk` | Maximum Likelihood（JC69）树的 Newick 文本 |
| `tree.png` | 系统发育树图（优先 ggtree，否则 ape） |
| `analysis_result.json` | 机器可读摘要，供后端/前端判定任务状态 |

`analysis_result.json` 成功示例：

```json
{
  "input": "example.fasta",
  "sequence_count": 6,
  "method": "Maximum Likelihood",
  "model": "JC69",
  "tree_file": "tree.nwk",
  "matrix_file": "distance_matrix.csv",
  "image_file": "tree.png",
  "status": "success"
}
```

失败时（若输出目录可写）仍会尽量写出同结构 JSON，且 `"status": "failed"`。

## 输入要求

- FASTA 格式 DNA
- **至少 3 条**序列
- 建议预先做多序列比对；若长度已一致，引擎视为已比对
- 长度不一致且无 MUSCLE 时，仅作末端补 gap 以便跑通，**非正式科研 MSA**

## 模块函数一览

| 函数 | 作用 |
|------|------|
| `read_fasta()` | 读入 FASTA |
| `calculate_distance()` | 算距离并写 CSV |
| `build_tree()` | 构建 ML 树 |
| `save_newick()` | 写 Newick |
| `plot_tree()` | 写 PNG |
| `write_result_json()` | 写分析元数据 |

## Outgroup 评估（未改建树核心）

当前 `build_tree()` 在 **`pml` + `optim.pml` 之后**用 `tip.label[1]` 做 `ape::root()`，仅影响展示/写出的有根形态，**不是**生物学上可靠的外群选择。

建议后续（仍不改 ML 优化本身）：

1. **默认**：`tree.nwk` 写无根 ML 树；或  
2. **增加可选 `outgroup` 参数**（CLI/配置），用户指定外群后再生根；未指定则无根或中点生根。

本次为遵守「不修改建树核心逻辑」，**未改** `build_tree` 中的 NJ / `pml` / `optim.pml` 流程。详见 `test-data/README.md`。
