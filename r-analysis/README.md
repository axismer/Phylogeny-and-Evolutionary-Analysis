# r-analysis — 独立系统发育分析引擎

基于 R（`ape` / `phangorn` / `ggplot2` / `ggtree`）的命令行分析模块，供本地运行或 Spring Boot 通过 `Rscript` 调用。

## 目录结构

```text
r-analysis/
├── engine/                            # 冻结生产引擎（Boot 现有契约）
│   ├── phylogenetic_tree.R
│   ├── ggtree_visualization.R
│   └── ...
├── core/                              # 多类型公共接口（Strategy 底座）
├── strategies/                        # virus|bacteria|archaea|eukaryote
├── metadata/                          # schema + validator
├── runners/run_analysis.R             # 统一 CLI（未来 Boot 主入口）
├── config/analysis_config.yaml
├── input/templates/                   # metadata 表头模板
├── scripts/                           # prep / demo / runners（ps1）
├── data/benchmarks/h3n2_ha/           # H3N2 基准输入（保留）
├── output/benchmarks/h3n2_ha/         # H3N2 基准产物（保留）
├── output/tasks/                      # 任务输出
├── test-data/ / tools/ / archive/ / docs/
└── README.md
```

稳定基准说明见 [`STABLE_H3N2_HA_PIPELINE.md`](STABLE_H3N2_HA_PIPELINE.md)；迁移计划见 [`docs/migration_plan.md`](docs/migration_plan.md)。

多生物类型框架（Virus / Bacteria / Archaea / Eukaryote）见 [`docs/multi_organism_framework.md`](docs/multi_organism_framework.md)；统一 CLI：`runners/run_analysis.R`。现有 `engine/phylogenetic_tree.R` 契约保持不变。Bacteria 环图分类粒度见 [`docs/bacteria_taxonomy_level.md`](docs/bacteria_taxonomy_level.md)。

## 安装 R 依赖

环境要求：R ≥ 4.4（本项目按 R 4.4.2 验证）。

在 R 控制台执行：

```r
install.packages(c("ape", "phangorn", "ggplot2", "tidyverse", "jsonlite", "ggnewscale"))

if (!requireNamespace("BiocManager", quietly = TRUE)) {
  install.packages("BiocManager")
}
BiocManager::install(c("ggtree", "ggtreeExtra", "treeio"))
```

- **必需**：`ape`、`phangorn`、`ggplot2`
- **推荐**：`ggtree` / `ggtreeExtra` / `treeio` / `ggnewscale`；`jsonlite`
- 建树：`engine/phylogenetic_tree.R`（ggtree 不可用时 `tree.png` 回退 ape）
- 环形图：`engine/ggtree_visualization.R`（不回退 ape）

可选：`tools/muscle.exe`、`tools/mafft-win/`（不等长比对）。

## 如何运行

### 1）示例冒烟

```powershell
cd d:\Projects\phylo-platform\r-analysis\scripts\runners
.\run_test_example.ps1
```

或：

```powershell
Rscript ..\..\engine\phylogenetic_tree.R ..\..\data\smoke\example.fasta ..\..\output\tasks\example
```

### 2）H3N2 HA 正式基准（可复现）

```powershell
cd d:\Projects\phylo-platform\r-analysis\scripts\runners
.\run_h3n2_ha_benchmark.ps1
```

流程：

```text
data/benchmarks/h3n2_ha/h3n2_ha_unaligned.fasta
  → engine/phylogenetic_tree.R
  → output/benchmarks/h3n2_ha/tree.nwk
  → engine/ncbi_metadata_to_tree_metadata.R
  → metadata.csv
  → engine/ggtree_visualization.R
  → circular_tree_final.png / .pdf
```

### 3）真实 FASTA（test-data）

```powershell
cd d:\Projects\phylo-platform\r-analysis\scripts\runners
.\run_test_real_data.ps1
```

详见 [`test-data/README.md`](test-data/README.md)。

### CLI（Spring Boot 契约）

```bash
Rscript engine/phylogenetic_tree.R <input.fasta> <output_dir>
```

配置：`phylo.r.script=../r-analysis/engine/phylogenetic_tree.R`

成功退出码 `0`，失败 `1`。

## 分析流程

1. `read_fasta()` — 读取 DNA FASTA  
2. `align_sequences()` — 等长跳过 / MAFFT / MUSCLE / gap 回退  
3. `calculate_distance()` — K80 → `distance_matrix.csv`  
4. `build_tree()` — NJ + **ML (JC69)**  
5. `save_newick()` → `tree.nwk`  
6. `plot_tree()` → `tree.png`  
7. `write_result_json()` → `analysis_result.json`

## 输出文件

| 文件 | 含义 |
|------|------|
| `distance_matrix.csv` | K80 遗传距离矩阵 |
| `tree.nwk` | ML（JC69）Newick |
| `tree.png` | 简易树图 |
| `analysis_result.json` | 机器可读摘要 |
| `metadata.csv` | tip 对齐 Country/Year（可视化步） |
| `circular_tree_final.png/pdf` | 论文级 circular（正式契约名） |
| `visualization_report.json` | 可视化诊断 |

## 环形树可视化

```powershell
cd d:\Projects\phylo-platform\r-analysis\scripts\runners
.\run_ggtree_viz.ps1
```

或：

```powershell
Rscript ..\..\engine\ggtree_visualization.R `
  ..\..\output\benchmarks\h3n2_ha\tree.nwk `
  ..\..\output\benchmarks\h3n2_ha\metadata.csv `
  ..\..\output\benchmarks\h3n2_ha
```

输入列：`label,Country,Year`（兼容旧 `Phylum`/`Age`）。  
输出：`circular_tree_final.png`（300 dpi）与 `.pdf`；真实枝长；Country + Year 双环；bootstrap≥70。
