# r-analysis 清理与归档计划

> 生成日期：2026-07-24  
> 原则：**本计划仅建议，不执行删除/移动。**  
> 完整逐文件说明见同目录 [`directory_audit.md`](directory_audit.md)。

---

## 第一类：必须保留文件

正式 pipeline / Spring Boot / 可复现基准所依赖。

### 核心引擎（Spring Boot 已对接或将对接）

| 路径 | 理由 |
|------|------|
| `scripts/phylogenetic_tree.R` | 建树引擎；`PhyloRProperties.script` 默认指向此文件 |
| `scripts/ggtree_visualization.R` | 论文级 circular 可视化（geom_fruit）；正式图出口 |
| `scripts/ncbi_metadata_to_tree_metadata.R` | NCBI 元数据 → tip 对齐 `metadata.csv` |
| `README.md` | 模块说明与调用约定 |

### 数据准备 / 基准编排（科研与回归）

| 路径 | 理由 |
|------|------|
| `scripts/parse_ncbi_genbank_ha.R` | GenBank → FASTA + NCBI metadata |
| `scripts/prepare_h3n2_ha_benchmark.R` | 构造可复现 H3N2 HA 基准集 |
| `scripts/report_h3n2_benchmark.R` | 基准汇总报告 |
| `scripts/run_h3n2_ha_benchmark.ps1` | 端到端：建树 → metadata → ggtree → report |
| `scripts/run_ggtree_viz.ps1` | 对已有 `tree.nwk`+`metadata.csv` 一键出图 |
| `scripts/add_bootstrap_labels_only.R` | 不改拓扑/枝长，仅补真实 bootstrap |
| `scripts/run_test_example.ps1` | 玩具冒烟 |
| `scripts/run_test_real_data.ps1` | 真实 FASTA 冒烟 |
| `scripts/prepare_platform_fasta.R` | 合并平台 `data/raw` → 多序列 FASTA |

### 最小可用输入与工具

| 路径 | 理由 |
|------|------|
| `data/example.fasta` | 冒烟输入 |
| `data/ncbi_h3n2_ha_benchmark/h3n2_ha_unaligned.fasta` | 正式基准 FASTA |
| `data/ncbi_h3n2_ha_benchmark/ncbi_metadata.csv` | 正式基准元数据 |
| `data/ncbi_h3n2_ha_benchmark/sampling_report.txt` | 采样可追溯 |
| `tools/muscle.exe` | 不等长比对（`phylogenetic_tree.R` 可调用） |
| `tools/mafft-win/`（整树） | Windows MAFFT；PATH/查找逻辑依赖 |
| `output/.gitkeep` | 保留输出目录结构 |
| `test-data/README.md` | 真实数据测试约定 |
| `test-data/output/.gitkeep` | 测试输出占位 |

### 代表性正式输出（建议至少保留一份最新成功产物）

| 路径 | 理由 |
|------|------|
| `output/h3n2_ha_benchmark/tree.nwk` | 正式基准树 |
| `output/h3n2_ha_benchmark/metadata.csv` | tip 对齐元数据 |
| `output/h3n2_ha_benchmark/circular_tree_final.png` | 正式 circular 成品 |
| `output/h3n2_ha_benchmark/circular_tree_final.pdf` | 矢量成品 |
| `output/h3n2_ha_benchmark/visualization_report.json` | 可视化诊断 |
| `output/h3n2_ha_benchmark/analysis_result.json` | 建树机器可读摘要 |
| `output/h3n2_ha_benchmark/distance_matrix.csv` | 距离矩阵 |
| `output/h3n2_ha_benchmark/benchmark_report.txt` | 基准文字报告 |
| `output/h3n2_ha_benchmark/tree.png` | 简易树预览 |

---

## 第二类：建议归档文件

有历史价值，但不在日常热路径；建议迁到 `output/_archive/YYYYMMDD/` 或 `data/_archive/`（**尚未执行**）。

### 旧可视化路径 / 过时命名

| 路径 | 理由 |
|------|------|
| `scripts/plot_circular_tree.R` | 旧 circular 引擎（含 ape fallback）；已被 `ggtree_visualization.R` 取代 |
| `scripts/prepare_circular_demo.R` | 随机 demo 树生成 |
| `scripts/run_circular_demo.ps1` | 调用旧 `plot_circular_tree.R` |
| `data/circular_demo/` | demo 输入（`tree.nwk` + `metadata.csv`） |
| `data/example_metadata.csv` | demo/兼容元数据 |
| `data/example_metadata_6tips.csv` | 小规模元数据样例 |
| `output/circular_demo/` | demo 出图 |
| `output/circular_tree.png` / `.pdf` | 旧命名出图 |
| `output/circular_tree_distance.png` / `.pdf` | README / report 仍可能提及；现脚本写 `circular_tree_final.*` |
| `output/h3n2_ha_benchmark/circular_tree_distance.*` | 基准目录中的旧命名产物 |
| `output/h3n2_real/` | 较小规模真实跑通结果；可归档为样例 |

### NCBI 中间产物 / 小规模实跑输入

| 路径 | 理由 |
|------|------|
| `data/ncbi_h3n2_ha/` 全部 | 早期 GenBank 解析链路产物；基准集已独立到 `ncbi_h3n2_ha_benchmark/` |
| `test-data/h3n2_na_20.fasta` | 早期 NA 测试；非当前 HA 基准 |
| `test-data/platform_16s*.fasta` | 平台合并产物；可再生 |
| `output/h3n2_ha_benchmark/tree.nwk.bak_nobootstrap` | bootstrap 前备份 |
| `output/tree.nwk` / `metadata.csv` / `tree.png` / `distance_matrix.csv` / `analysis_result.json` / `visualization_report.json` / `circular_tree_final.*` | 根 `output/` 上一次小规模跑通；可归档，正式以任务子目录为准 |

### 工具包下载残留

| 路径 | 理由 |
|------|------|
| `tools/mafft-7.526-win64-signed.zip` | 安装包（~25MB）；已解压到 `mafft-win/` |
| `tools/mafft-fresh.zip` | 重复下载包（~26MB） |
| `tmp_aplot_0.2.9.zip` | 临时依赖 zip（根目录） |

---

## 第三类：可以删除文件

无 pipeline 引用、明确为调试/空目录/偶然产物。删除前建议先移入回收站或 `_trash/` 观察一周。

| 路径 | 理由 |
|------|------|
| `output/_probe_*.png`（6 个） | 调试探针图：`_probe_circ/fan2/full_ggsave/print/rect/tree.png` |
| `output/h3n2_ha_benchmark/_smoke_in.fasta` | MAFFT/MUSCLE smoke 输入残留 |
| `output/h3n2_ha_benchmark/_smoke_aln.fasta` | smoke 比对残留 |
| `tools/_smoke.fa` / `tools/_smoke_muscle.fa` | 工具 smoke 临时 FASTA |
| `scripts/Rplots.pdf` | R 默认绘图设备偶然输出 |
| `Rplots.pdf`（r-analysis 根） | 同上 |
| `output/ggtree_install_failure.txt` | 某次环境失败日志；非数据资产 |
| `config/`（空目录） | 无配置文件 |
| `tools/mafft-extract/`（空目录） | 解压中转空壳 |

> 注意：`tools/mafft-win/` **不要删**（正式比对依赖）。仅 zip 安装包可删。

---

## 第四类：未来 Spring Boot 调用需要暴露的核心文件

当前 Java 仅调用建树；环形图与 metadata 转换是下一阶段应暴露的 CLI。

### 已暴露（现状）

| 组件 | 路径 / 约定 |
|------|-------------|
| Rscript 入口 | `scripts/phylogenetic_tree.R` |
| CLI | `Rscript phylogenetic_tree.R <input.fasta> <output_dir>` |
| 配置 | `backend/.../PhyloRProperties.java` → `phylo.r.script` |
| 期望输出 | `distance_matrix.csv`, `tree.nwk`, `tree.png`, `analysis_result.json` |
| API | `/api/r-analysis`（`RAnalysisController`） |

### 建议下一步暴露

| 优先级 | 脚本 | CLI 约定 | 产出 |
|--------|------|----------|------|
| P0 | `ggtree_visualization.R` | `Rscript ggtree_visualization.R <tree.nwk> <metadata.csv> <output_dir>` | `circular_tree_final.png/pdf`, `visualization_report.json` |
| P0 | `ncbi_metadata_to_tree_metadata.R` | `Rscript ... <ncbi_metadata.csv> <tree.nwk\|fasta> <out.csv>` | tip 对齐 `metadata.csv` |
| P1 | `add_bootstrap_labels_only.R` | 可选增强：已有树补 bootstrap | 更新后的 `tree.nwk` |
| P2 | `parse_ncbi_genbank_ha.R` | 仅当后端要接 GenBank 上传时 | FASTA + NCBI CSV |

### 运行时依赖（部署需打包或文档化）

- R ≥ 4.4 + `ape`, `phangorn`, `ggplot2`, `jsonlite`
- Bioconductor：`ggtree`, `ggtreeExtra`, `treeio`, `ggnewscale`
- 可选二进制：`tools/muscle.exe`、`tools/mafft-win/`

### 建议后端契约（输出契约稳定名）

```text
{taskOutputDir}/
  analysis_result.json          # 建树状态
  tree.nwk
  distance_matrix.csv
  tree.png                      # 简易树
  metadata.csv                  # tip 对齐（Country/Year）
  circular_tree_final.png       # 正式 circular（勿再用 circular_tree_distance）
  circular_tree_final.pdf
  visualization_report.json
```

---

## 建议执行顺序（仍不自动执行）

1. 先归档第二类到 `output/_archive/YYYYMMDD/` / `data/_archive/`  
2. 再删除第三类探针与 smoke 残留  
3. 更新 `README.md`：将 `circular_tree_distance.*` 文档改为 `circular_tree_final.*`；顺带对齐 `report_h3n2_benchmark.R` 中的 png 路径检查  
4. Spring Boot：新增 `phylo.r.vizScript` / metadata 转换配置，再接线 `ggtree_visualization.R`

---

## 本次审计范围确认

- 已遍历 `r-analysis` 全树（含 `tools/mafft-win` 厂商树约 106 文件，按整体保留）
- **未删除、未修改代码、未移动任何文件**
- 产出报告：`directory_audit.md` + 本 `cleanup_plan.md`
