# r-analysis 完整目录审计报告

> 生成日期：2026-07-24  
> 范围：`r-analysis/` 全树（只读审计）  
> 原则：**不删除、不修改代码、不移动文件**  
> 配套计划：[`cleanup_plan.md`](cleanup_plan.md)

---

## 0. 目录树（逻辑视图）

```text
r-analysis/
│
├── README.md
├── cleanup_plan.md
├── directory_audit.md          # 本报告
├── Rplots.pdf                  # 根目录偶然 R 绘图残留
├── tmp_aplot_0.2.9.zip         # 临时依赖包 zip
│
├── config/                     # 空目录
│
├── scripts/
│   ├── phylogenetic_tree.R           # 建树引擎（Spring Boot 已对接）
│   ├── ggtree_visualization.R        # 论文级 circular 可视化
│   ├── ncbi_metadata_to_tree_metadata.R
│   ├── parse_ncbi_genbank_ha.R
│   ├── prepare_h3n2_ha_benchmark.R
│   ├── report_h3n2_benchmark.R
│   ├── add_bootstrap_labels_only.R
│   ├── prepare_platform_fasta.R
│   ├── plot_circular_tree.R          # 旧 circular（含 ape fallback）
│   ├── prepare_circular_demo.R
│   ├── run_h3n2_ha_benchmark.ps1
│   ├── run_ggtree_viz.ps1
│   ├── run_test_example.ps1
│   ├── run_test_real_data.ps1
│   ├── run_circular_demo.ps1
│   └── Rplots.pdf
│
├── data/
│   ├── example.fasta
│   ├── example_metadata.csv
│   ├── example_metadata_6tips.csv
│   ├── circular_demo/
│   │   ├── tree.nwk
│   │   └── metadata.csv
│   ├── ncbi_h3n2_ha/                 # 早期小规模 NCBI 解析产物
│   │   ├── accession_ids.txt
│   │   ├── esummary.json
│   │   ├── ncbi_raw.gb
│   │   ├── ncbi_raw.fasta
│   │   ├── h3n2_ha.fasta
│   │   └── ncbi_metadata.csv
│   └── ncbi_h3n2_ha_benchmark/       # 正式 H3N2 HA 基准集
│       ├── h3n2_ha_unaligned.fasta
│       ├── ncbi_metadata.csv
│       └── sampling_report.txt
│
├── output/
│   ├── .gitkeep
│   ├── （根目录小规模跑通产物：tree/matrix/json/circular_*）
│   ├── _probe_*.png                  # 调试探针图 ×6
│   ├── ggtree_install_failure.txt
│   ├── circular_demo/
│   ├── h3n2_real/
│   └── h3n2_ha_benchmark/            # 正式基准输出
│
├── test-data/
│   ├── README.md
│   ├── h3n2_na_20.fasta
│   ├── platform_16s.fasta
│   ├── platform_16s_equal_len.fasta
│   └── output/.gitkeep
│
└── tools/
    ├── muscle.exe
    ├── _smoke.fa
    ├── _smoke_muscle.fa
    ├── mafft-7.526-win64-signed.zip
    ├── mafft-fresh.zip
    ├── mafft-extract/                # 空目录
    └── mafft-win/                    # 已解压 MAFFT（~106 文件，厂商树）
```

---

## 1. 调用关系总览

```text
【正式端到端基准】
  data/ncbi_h3n2_ha_benchmark/h3n2_ha_unaligned.fasta
       │
       ▼
  phylogenetic_tree.R  ──►  output/.../tree.nwk, distance_matrix.csv,
                            tree.png, analysis_result.json
       │
       ▼
  ncbi_metadata_to_tree_metadata.R (← ncbi_metadata.csv + tree.nwk)
       │
       ▼  metadata.csv
  ggtree_visualization.R  ──►  circular_tree_final.png/pdf,
                               visualization_report.json
       │
       ▼
  report_h3n2_benchmark.R  ──►  benchmark_report.txt

  编排：run_h3n2_ha_benchmark.ps1

【Spring Boot 现状】
  ProcessBuilderRPhylogeneticAnalysisService
       → phylo.r.script = ../r-analysis/scripts/phylogenetic_tree.R
       → 仅建树；尚未调用 ggtree / metadata 转换

【旧 demo 路径】
  prepare_circular_demo.R → data/circular_demo/
  run_circular_demo.ps1 → plot_circular_tree.R → output/circular_demo/

【冒烟】
  run_test_example.ps1 → phylogenetic_tree.R (example.fasta)
  run_test_real_data.ps1 → [prepare_platform_fasta.R] → phylogenetic_tree.R
```

---

## 2. 重点分析

### 2.1 `phylogenetic_tree.R`

| 项 | 说明 |
|----|------|
| 角色 | **正式建树引擎**；CLI：`Rscript phylogenetic_tree.R <input.fasta> <output_dir>` |
| 流程 | read FASTA → 比对（等长跳过 / MUSCLE / MAFFT / gap 回退）→ K80 距离 → NJ+ML(JC69) → Newick/PNG/JSON |
| 产出 | `distance_matrix.csv`, `tree.nwk`, `tree.png`, `analysis_result.json` |
| 被谁引用 | Spring Boot `PhyloRProperties`；`run_test_*.ps1`；`run_h3n2_ha_benchmark.ps1`；`add_bootstrap_labels_only.R`（`source`） |
| pipeline | **是（核心）** |
| 可否删除 | **否** |
| 可否移动 | 可迁路径，但必须同步改 `application.properties` / `PhyloRProperties` |

### 2.2 `ggtree_visualization.R`

| 项 | 说明 |
|----|------|
| 角色 | **正式论文级 circular 可视化**（真实枝长 + Country/Year 环 + bootstrap≥70） |
| CLI | `Rscript ggtree_visualization.R <tree.nwk> <metadata.csv> <output_dir>` |
| 产出 | `circular_tree_final.png/pdf`, `visualization_report.json`；失败写 `ggtree_install_failure.txt` |
| 被谁引用 | `run_h3n2_ha_benchmark.ps1`, `run_ggtree_viz.ps1` |
| pipeline | **是（可视化出口）**；后端尚未对接 |
| 可否删除 | **否** |
| 可否移动 | 可，需同步编排脚本与未来 Java 配置 |

### 2.3 metadata 处理脚本

| 脚本 | 作用 |
|------|------|
| `ncbi_metadata_to_tree_metadata.R` | NCBI CSV → tip 对齐 `label,Country,Year,Host`；**正式 metadata 桥** |
| `prepare_circular_demo.R` | 随机生成 demo 树+metadata（含写 `example_metadata.csv`）；**旧 demo** |
| 输入样例 | `data/example_metadata*.csv`, `data/circular_demo/metadata.csv`, 各 `output/**/metadata.csv` |

正式路径：`ncbi_metadata.csv` → `ncbi_metadata_to_tree_metadata.R` → `metadata.csv` → `ggtree_visualization.R`。

### 2.4 NCBI 数据处理脚本

| 脚本 | 作用 |
|------|------|
| `parse_ncbi_genbank_ha.R` | GenBank `.gb` → `h3n2_ha.fasta` + `ncbi_metadata.csv` |
| `prepare_h3n2_ha_benchmark.R` | 在线 E-utilities 分层抽样构造基准集到 `data/ncbi_h3n2_ha_benchmark/` |
| `report_h3n2_benchmark.R` | 汇总 tip/年/国/枝长 → `benchmark_report.txt` |

数据资产：

- **正式基准**：`data/ncbi_h3n2_ha_benchmark/`
- **早期中间产物**：`data/ncbi_h3n2_ha/`（可归档）

### 2.5 demo 文件

| 路径 | 说明 |
|------|------|
| `scripts/prepare_circular_demo.R` + `run_circular_demo.ps1` | 旧 demo 编排 |
| `scripts/plot_circular_tree.R` | 旧引擎（ggtree 或 ape fallback） |
| `data/circular_demo/` | demo 输入 |
| `output/circular_demo/` | demo 出图 |
| `data/example_metadata.csv` | demo 同步写出 |

已被 `ggtree_visualization.R` 取代；保留作历史/教学，建议归档。

### 2.6 `test-data/`

| 文件 | 说明 |
|------|------|
| `README.md` | 真实数据测试约定；**保留** |
| `platform_16s.fasta` / `platform_16s_equal_len.fasta` | 平台 raw 合并产物；可再生 |
| `h3n2_na_20.fasta` | 早期 NA 测试；非当前 HA 基准 |
| `output/.gitkeep` | 占位；**保留** |
| （无 `input.fasta`） | 由用户按需放入 |

用途：冒烟 / 平台 16S 验证；**不属于 H3N2 正式基准 pipeline**。

### 2.7 `output/`

| 子树 | 定位 |
|------|------|
| `h3n2_ha_benchmark/` | **正式基准成功产物**（建议至少保留一套） |
| `h3n2_real/` | 较小规模真实跑通；可归档 |
| `circular_demo/` | 旧 demo 出图；可归档 |
| 根目录 `tree.*` / `circular_*` / `metadata.csv` 等 | 最近一次小规模/调试跑通；可归档 |
| `_probe_*.png` | 调试探针；可删 |
| `*_smoke_*.fasta` | 工具 smoke 残留；可删 |
| `ggtree_install_failure.txt` | 环境失败日志；可删 |
| 命名分化 | 旧：`circular_tree*.png` / `circular_tree_distance.*`；新：`circular_tree_final.*` |

---

## 3. 逐文件说明

图例：  
**I**=输入 · **O**=输出 · **T**=临时/偶然 · **V**=厂商工具 · **D**=文档 · **S**=脚本

### 3.1 根目录

================
文件路径：`r-analysis/README.md`  
文件类型：Markdown 文档  
创建用途：模块说明、依赖安装、CLI 约定  
当前作用：仍有效；部分输出文件名仍写 `circular_tree_distance`（与现脚本 `circular_tree_final` 不完全一致）  
是否被其他脚本引用：否（文档）  
分类：D  
是否属于正式 pipeline：文档配套 — **是**  
是否可以删除：否  
是否可以移动：否（模块入口文档）  
================

================
文件路径：`r-analysis/cleanup_plan.md`  
文件类型：Markdown（审计衍生）  
创建用途：四类清理/归档建议  
当前作用：计划文档  
是否被其他脚本引用：否  
分类：D  
是否属于正式 pipeline：否  
是否可以删除：可（仅文档）；建议保留至清理执行完毕  
是否可以移动：可  
================

================
文件路径：`r-analysis/directory_audit.md`  
文件类型：Markdown（本审计）  
创建用途：完整目录与逐文件说明  
当前作用：审计报告  
是否被其他脚本引用：否  
分类：D  
是否属于正式 pipeline：否  
是否可以删除：可（文档）  
是否可以移动：可  
================

================
文件路径：`r-analysis/Rplots.pdf`  
文件类型：PDF  
创建用途：R 默认设备意外落盘  
当前作用：无  
是否被其他脚本引用：否  
分类：T  
是否属于正式 pipeline：否  
是否可以删除：**是**  
是否可以移动：可（无意义）  
================

================
文件路径：`r-analysis/tmp_aplot_0.2.9.zip`  
文件类型：zip 依赖包  
创建用途：临时下载 ggtree 相关依赖  
当前作用：无运行时引用  
是否被其他脚本引用：否  
分类：T  
是否属于正式 pipeline：否  
是否可以删除：建议删或归档  
是否可以移动：可 → archive  
================

================
文件路径：`r-analysis/config/`  
文件类型：空目录  
创建用途：可能预留配置  
当前作用：空  
是否被其他脚本引用：否  
分类：T  
是否属于正式 pipeline：否  
是否可以删除：**是**（空目录）  
是否可以移动：可  
================

### 3.2 `scripts/`

================
文件路径：`scripts/phylogenetic_tree.R`  
文件类型：R 脚本  
创建用途：系统发育建树引擎  
当前作用：正式入口；Java `phylo.r.script` 指向此处  
是否被其他脚本引用：是 — `run_test_*.ps1`、`run_h3n2_ha_benchmark.ps1`、`add_bootstrap_labels_only.R`（source）、Spring Boot  
分类：S / I→O 生产者  
是否属于正式 pipeline：**是**  
是否可以删除：**否**  
是否可以移动：需同步后端配置  
================

================
文件路径：`scripts/ggtree_visualization.R`  
文件类型：R 脚本  
创建用途：论文级 circular 树  
当前作用：正式可视化出口  
是否被其他脚本引用：是 — `run_h3n2_ha_benchmark.ps1`、`run_ggtree_viz.ps1`  
分类：S  
是否属于正式 pipeline：**是**  
是否可以删除：**否**  
是否可以移动：需同步编排/未来 Java  
================

================
文件路径：`scripts/ncbi_metadata_to_tree_metadata.R`  
文件类型：R 脚本  
创建用途：NCBI metadata → tip 对齐 CSV  
当前作用：正式 metadata 桥  
是否被其他脚本引用：是 — `run_h3n2_ha_benchmark.ps1`  
分类：S  
是否属于正式 pipeline：**是**  
是否可以删除：**否**  
是否可以移动：需同步编排/未来 Java  
================

================
文件路径：`scripts/parse_ncbi_genbank_ha.R`  
文件类型：R 脚本  
设计用途：解析 GenBank → FASTA + NCBI CSV  
当前作用：数据准备工具（离线重跑早期集）  
是否被其他脚本引用：间接（人工/历史对 `data/ncbi_h3n2_ha/`）  
分类：S  
是否属于正式 pipeline：数据准备 — **是（科研链路）**；非 Java 热路径  
是否可以删除：否（建议保留）  
是否可以移动：可归档到 `scripts/prep/`  
================

================
文件路径：`scripts/prepare_h3n2_ha_benchmark.R`  
文件类型：R 脚本  
设计用途：在线抽样构造 H3N2 HA 基准  
当前作用：可再生 `data/ncbi_h3n2_ha_benchmark/`  
是否被其他脚本引用：人工调用；基准编排依赖其产出数据，非直接调用  
分类：S  
是否属于正式 pipeline：基准构造 — **是**  
是否可以删除：否  
是否可以移动：可  
================

================
文件路径：`scripts/report_h3n2_benchmark.R`  
文件类型：R 脚本  
设计用途：基准汇总文字报告  
当前作用：被 `run_h3n2_ha_benchmark.ps1` 调用  
是否被其他脚本引用：是 — `run_h3n2_ha_benchmark.ps1`  
分类：S  
是否属于正式 pipeline：**是（基准）**  
是否可以删除：否  
是否可以移动：可  
================

================
文件路径：`scripts/add_bootstrap_labels_only.R`  
文件类型：R 脚本  
设计用途：不改拓扑/枝长，仅补真实 bootstrap  
当前作用：增强工具；`source(phylogenetic_tree.R)`  
是否被其他脚本引用：人工；基准树 `tree.nwk.bak_nobootstrap` 暗示曾用过  
分类：S  
是否属于正式 pipeline：可选增强 — **建议保留（P1 暴露）**  
是否可以删除：否  
是否可以移动：可  
================

================
文件路径：`scripts/prepare_platform_fasta.R`  
文件类型：R 脚本  
设计用途：合并仓库 `data/raw` → `test-data/platform_16s.fasta`  
当前作用：真实 16S 冒烟准备  
是否被其他脚本引用：是 — `run_test_real_data.ps1`  
分类：S  
是否属于正式 pipeline：测试辅助 — 半正式  
是否可以删除：否（测试链路）  
是否可以移动：可  
================

================
文件路径：`scripts/plot_circular_tree.R`  
文件类型：R 脚本  
设计用途：旧 circular（ggtree / ape+ggplot2 fallback）  
当前作用：仅 `run_circular_demo.ps1`  
是否被其他脚本引用：是 — `run_circular_demo.ps1`  
分类：S  
是否属于正式 pipeline：**否**（已被 ggtree_visualization 取代）  
是否可以删除：建议先归档再删  
是否可以移动：**建议归档**  
================

================
文件路径：`scripts/prepare_circular_demo.R`  
文件类型：R 脚本  
设计用途：生成 24-tip 随机 demo 树+metadata  
当前作用：写 `data/circular_demo/` 与 `example_metadata.csv`  
是否被其他脚本引用：是 — `run_circular_demo.ps1`  
分类：S  
是否属于正式 pipeline：否  
是否可以删除：建议归档  
是否可以移动：建议归档  
================

================
文件路径：`scripts/run_h3n2_ha_benchmark.ps1`  
文件类型：PowerShell  
设计用途：端到端基准：建树→metadata→ggtree→report  
当前作用：正式科研/回归编排入口  
是否被其他脚本引用：人工入口  
分类：S  
是否属于正式 pipeline：**是**  
是否可以删除：否  
是否可以移动：可（保持相对路径）  
================

================
文件路径：`scripts/run_ggtree_viz.ps1`  
文件类型：PowerShell  
设计用途：对 `output/tree.nwk`+`metadata.csv` 一键出图  
当前作用：可视化快捷入口  
是否被其他脚本引用：人工入口  
分类：S  
是否属于正式 pipeline：辅助正式  
是否可以删除：否  
是否可以移动：可  
================

================
文件路径：`scripts/run_test_example.ps1`  
文件类型：PowerShell  
设计用途：example.fasta 冒烟  
当前作用：玩具测试  
是否被其他脚本引用：人工  
分类：S  
是否属于正式 pipeline：冒烟 — 建议保留  
是否可以删除：否  
是否可以移动：可  
================

================
文件路径：`scripts/run_test_real_data.ps1`  
文件类型：PowerShell  
设计用途：真实 FASTA / platform_16s 冒烟  
当前作用：测试编排  
是否被其他脚本引用：人工  
分类：S  
是否属于正式 pipeline：测试  
是否可以删除：否  
是否可以移动：可  
================

================
文件路径：`scripts/run_circular_demo.ps1`  
文件类型：PowerShell  
设计用途：旧 circular demo  
当前作用：调用旧 `plot_circular_tree.R`  
是否被其他脚本引用：人工  
分类：S  
是否属于正式 pipeline：否  
是否可以删除：建议归档  
是否可以移动：建议归档  
================

================
文件路径：`scripts/Rplots.pdf`  
文件类型：PDF  
设计用途：偶然产物  
当前作用：无  
是否被其他脚本引用：否  
分类：T  
是否属于正式 pipeline：否  
是否可以删除：**是**  
是否可以移动：可  
================

### 3.3 `data/`

================
文件路径：`data/example.fasta`  
文件类型：FASTA  
设计用途：玩具冒烟输入  
当前作用：`run_test_example.ps1` / README 示例  
是否被其他脚本引用：是（测试脚本路径）  
分类：I  
是否属于正式 pipeline：冒烟输入 — **保留**  
是否可以删除：否  
是否可以移动：需同步测试脚本  
================

================
文件路径：`data/example_metadata.csv`  
文件类型：CSV  
设计用途：demo/兼容元数据  
当前作用：由 `prepare_circular_demo.R` 同步写出  
是否被其他脚本引用：间接（文档/旧 demo）  
分类：I  
是否属于正式 pipeline：否  
是否可以删除：可归档  
是否可以移动：建议归档  
================

================
文件路径：`data/example_metadata_6tips.csv`  
文件类型：CSV  
设计用途：小规模 metadata 样例  
当前作用：样例；无热路径引用  
是否被其他脚本引用：否（未见脚本硬编码）  
分类：I  
是否属于正式 pipeline：否  
是否可以删除：可归档  
是否可以移动：建议归档  
================

#### `data/circular_demo/`

================
文件路径：`data/circular_demo/tree.nwk`  
文件类型：Newick  
设计用途：demo 树输入  
当前作用：`run_circular_demo.ps1` / `plot_circular_tree.R`  
是否被其他脚本引用：是  
分类：I  
是否属于正式 pipeline：否  
是否可以删除：可归档  
是否可以移动：建议归档  
================

================
文件路径：`data/circular_demo/metadata.csv`  
文件类型：CSV  
设计用途：demo tip 元数据（Phylum/Age 风格）  
当前作用：旧 circular demo  
是否被其他脚本引用：是  
分类：I  
是否属于正式 pipeline：否  
是否可以删除：可归档  
是否可以移动：建议归档  
================

#### `data/ncbi_h3n2_ha/`（早期链路）

================
文件路径：`data/ncbi_h3n2_ha/accession_ids.txt`  
文件类型：文本  
设计用途：accession 列表  
当前作用：历史可追溯；非正式基准  
是否被其他脚本引用：否（静态产物）  
分类：O（历史）  
是否属于正式 pipeline：否  
是否可以删除：建议归档（勿直接丢）  
是否可以移动：建议 → `data/_archive/ncbi_h3n2_ha/`  
================

================
文件路径：`data/ncbi_h3n2_ha/esummary.json`  
文件类型：JSON  
设计用途：NCBI esummary 原始响应  
当前作用：中间产物存档  
是否被其他脚本引用：否  
分类：O/T  
是否属于正式 pipeline：否  
是否可以删除：可归档  
是否可以移动：建议归档  
================

================
文件路径：`data/ncbi_h3n2_ha/ncbi_raw.gb`  
文件类型：GenBank flat  
设计用途：`parse_ncbi_genbank_ha.R` 输入  
当前作用：可复现早期解析  
是否被其他脚本引用：人工可再喂给 parse 脚本  
分类：I  
是否属于正式 pipeline：否（早期）  
是否可以删除：可归档  
是否可以移动：建议归档  
================

================
文件路径：`data/ncbi_h3n2_ha/ncbi_raw.fasta`  
文件类型：FASTA  
设计用途：原始下载 FASTA  
当前作用：历史  
是否被其他脚本引用：否  
分类：O  
是否属于正式 pipeline：否  
是否可以删除：可归档  
是否可以移动：建议归档  
================

================
文件路径：`data/ncbi_h3n2_ha/h3n2_ha.fasta`  
文件类型：FASTA  
设计用途：parse 脚本产出的 HA 序列  
当前作用：早期小规模输入；`h3n2_real` 可能由此跑出  
是否被其他脚本引用：历史人工  
分类：O/I  
是否属于正式 pipeline：否  
是否可以删除：可归档  
是否可以移动：建议归档  
================

================
文件路径：`data/ncbi_h3n2_ha/ncbi_metadata.csv`  
文件类型：CSV  
设计用途：早期 NCBI 风格 metadata  
当前作用：历史；正式集在 `ncbi_h3n2_ha_benchmark/`  
是否被其他脚本引用：历史人工  
分类：O/I  
是否属于正式 pipeline：否  
是否可以删除：可归档  
是否可以移动：建议归档  
================

#### `data/ncbi_h3n2_ha_benchmark/`（正式基准输入）

================
文件路径：`data/ncbi_h3n2_ha_benchmark/h3n2_ha_unaligned.fasta`  
文件类型：FASTA（未比对）  
设计用途：正式基准输入  
当前作用：`run_h3n2_ha_benchmark.ps1` 第一步输入  
是否被其他脚本引用：是  
分类：I  
是否属于正式 pipeline：**是**  
是否可以删除：**否**  
是否可以移动：需同步 `run_h3n2_ha_benchmark.ps1`  
================

================
文件路径：`data/ncbi_h3n2_ha_benchmark/ncbi_metadata.csv`  
文件类型：CSV  
设计用途：正式基准 NCBI metadata  
当前作用：metadata 转换输入  
是否被其他脚本引用：是  
分类：I  
是否属于正式 pipeline：**是**  
是否可以删除：**否**  
是否可以移动：需同步编排脚本  
================

================
文件路径：`data/ncbi_h3n2_ha_benchmark/sampling_report.txt`  
文件类型：文本  
设计用途：分层抽样可追溯报告  
当前作用：科研可重复性记录  
是否被其他脚本引用：否（文档资产）  
分类：O/D  
是否属于正式 pipeline：**是（可追溯）**  
是否可以删除：否  
是否可以移动：可随基准目录整体移动  
================

### 3.4 `output/`

================
文件路径：`output/.gitkeep`  
文件类型：占位  
设计用途：保留空目录入 git  
当前作用：结构占位  
是否被其他脚本引用：否  
分类：D  
是否属于正式 pipeline：结构 — 是  
是否可以删除：否  
是否可以移动：否  
================

#### 根 `output/` 跑通/调试产物

================
文件路径：`output/tree.nwk`  
文件类型：Newick  
设计用途：建树输出  
当前作用：`run_ggtree_viz.ps1` 默认输入；小规模最新跑通  
是否被其他脚本引用：是 — `run_ggtree_viz.ps1`  
分类：O  
是否属于正式 pipeline：任务产物（非正式基准副本）  
是否可以删除：可归档（正式以子目录为准）  
是否可以移动：建议归档；若删需改 `run_ggtree_viz.ps1` 默认路径  
================

================
文件路径：`output/tree.png`  
文件类型：PNG  
设计用途：简易树图  
当前作用：最近跑通预览  
是否被其他脚本引用：否  
分类：O  
是否属于正式 pipeline：产物  
是否可以删除：可归档  
是否可以移动：可  
================

================
文件路径：`output/distance_matrix.csv`  
文件类型：CSV  
设计用途：K80 距离矩阵  
当前作用：最近跑通  
是否被其他脚本引用：否  
分类：O  
是否属于正式 pipeline：产物  
是否可以删除：可归档  
是否可以移动：可  
================

================
文件路径：`output/analysis_result.json`  
文件类型：JSON  
设计用途：建树机器可读摘要（Java 也读此契约）  
当前作用：最近跑通  
是否被其他脚本引用：后端解析同类文件  
分类：O  
是否属于正式 pipeline：契约产物  
是否可以删除：可归档（样本可留在基准目录）  
是否可以移动：可  
================

================
文件路径：`output/metadata.csv`  
文件类型：CSV  
设计用途：tip 对齐元数据  
当前作用：`run_ggtree_viz.ps1` 输入  
是否被其他脚本引用：是  
分类：O/I  
是否属于正式 pipeline：中间产物  
是否可以删除：可归档  
是否可以移动：可（改 ps1）  
================

================
文件路径：`output/circular_tree_final.png` / `.pdf`  
文件类型：图像/矢量  
设计用途：正式命名 circular 成品  
当前作用：根目录最近可视化  
是否被其他脚本引用：否  
分类：O  
是否属于正式 pipeline：命名契约产物（副本）  
是否可以删除：可归档（保留基准目录那份）  
是否可以移动：可  
================

================
文件路径：`output/circular_tree.png` / `.pdf`  
文件类型：图像  
设计用途：旧命名 circular  
当前作用：历史  
是否被其他脚本引用：否  
分类：O  
是否属于正式 pipeline：否  
是否可以删除：可归档  
是否可以移动：建议归档  
================

================
文件路径：`output/circular_tree_distance.png` / `.pdf`  
文件类型：图像  
设计用途：过渡命名（README 仍提及）  
当前作用：历史；现脚本写 `circular_tree_final`  
是否被其他脚本引用：`report_h3n2_benchmark.R` 仍检查 `circular_tree_distance.png` 路径字符串（报告字段）  
分类：O  
是否属于正式 pipeline：命名过时  
是否可以删除：可归档；报告脚本字段日后应对齐新文件名  
是否可以移动：建议归档  
================

================
文件路径：`output/visualization_report.json`  
文件类型：JSON  
设计用途：ggtree 诊断报告  
当前作用：根目录最近可视化  
是否被其他脚本引用：否  
分类：O  
是否属于正式 pipeline：契约产物  
是否可以删除：可归档  
是否可以移动：可  
================

================
文件路径：`output/ggtree_install_failure.txt`  
文件类型：文本日志  
设计用途：ggtree 加载失败记录  
当前作用：某次环境失败残留  
是否被其他脚本引用：否（由 viz 脚本在失败时写出）  
分类：T  
是否属于正式 pipeline：否  
是否可以删除：**是**  
是否可以移动：可  
================

================
文件路径：`output/_probe_circ.png`  
文件路径：`output/_probe_fan2.png`  
文件路径：`output/_probe_full_ggsave.png`  
文件路径：`output/_probe_print.png`  
文件路径：`output/_probe_rect.png`  
文件路径：`output/_probe_tree.png`  
文件类型：PNG  
设计用途：布局/渲染调试探针  
当前作用：无  
是否被其他脚本引用：否  
分类：T  
是否属于正式 pipeline：否  
是否可以删除：**是**  
是否可以移动：可 → trash  
================

#### `output/circular_demo/`

================
文件路径：`output/circular_demo/circular_tree.png` / `.pdf`  
文件类型：图像  
设计用途：旧 demo 出图  
当前作用：展示样例  
是否被其他脚本引用：否（`run_circular_demo.ps1` 产出）  
分类：O  
是否属于正式 pipeline：否  
是否可以删除：可归档  
是否可以移动：建议归档  
================

#### `output/h3n2_real/`

================
文件路径：`output/h3n2_real/tree.nwk`  
`distance_matrix.csv` / `tree.png` / `analysis_result.json` / `metadata.csv` /  
`circular_tree_distance.png` / `.pdf`  
文件类型：分析产物集  
设计用途：较小规模真实 H3N2 跑通  
当前作用：历史样例；非正式大基准  
是否被其他脚本引用：否  
分类：O  
是否属于正式 pipeline：否（早期实跑）  
是否可以删除：可归档  
是否可以移动：建议归档  
================

#### `output/h3n2_ha_benchmark/`（正式基准输出）

================
文件路径：`output/h3n2_ha_benchmark/tree.nwk`  
文件类型：Newick（含 bootstrap labels）  
设计用途：正式基准树  
当前作用：正式可视化与报告输入  
是否被其他脚本引用：是 — 基准编排链  
分类：O  
是否属于正式 pipeline：**是**  
是否可以删除：**否**（至少保留最新成功一份）  
是否可以移动：任务子目录整体可迁，勿拆散  
================

================
文件路径：`output/h3n2_ha_benchmark/tree.nwk.bak_nobootstrap`  
文件类型：Newick 备份  
设计用途：补 bootstrap 前备份  
当前作用：安全回退  
是否被其他脚本引用：否  
分类：O/T  
是否属于正式 pipeline：否（备份）  
是否可以删除：可归档  
是否可以移动：建议归档  
================

================
文件路径：`output/h3n2_ha_benchmark/tree.png`  
文件类型：PNG  
设计用途：简易树  
当前作用：基准配套  
是否被其他脚本引用：否  
分类：O  
是否属于正式 pipeline：是  
是否可以删除：否（建议随基准保留）  
是否可以移动：可随目录  
================

================
文件路径：`output/h3n2_ha_benchmark/distance_matrix.csv`  
文件类型：CSV（较大）  
设计用途：基准距离矩阵  
当前作用：正式产物  
是否被其他脚本引用：否  
分类：O  
是否属于正式 pipeline：是  
是否可以删除：否  
是否可以移动：可随目录  
================

================
文件路径：`output/h3n2_ha_benchmark/analysis_result.json`  
文件类型：JSON  
设计用途：建树摘要  
当前作用：正式产物 / 契约样例  
是否被其他脚本引用：后端同类契约  
分类：O  
是否属于正式 pipeline：是  
是否可以删除：否  
是否可以移动：可随目录  
================

================
文件路径：`output/h3n2_ha_benchmark/metadata.csv`  
文件类型：CSV  
设计用途：tip 对齐 Country/Year  
当前作用：ggtree 输入  
是否被其他脚本引用：是  
分类：O/I  
是否属于正式 pipeline：是  
是否可以删除：否  
是否可以移动：可随目录  
================

================
文件路径：`output/h3n2_ha_benchmark/circular_tree_final.png` / `.pdf`  
文件类型：图像/矢量  
设计用途：正式 circular 成品  
当前作用：当前打开查看的正式图  
是否被其他脚本引用：否  
分类：O  
是否属于正式 pipeline：**是**  
是否可以删除：**否**  
是否可以移动：可随目录  
================

================
文件路径：`output/h3n2_ha_benchmark/circular_tree_distance.png` / `.pdf`  
文件类型：图像  
设计用途：旧/过渡命名成品  
当前作用：历史对比；`report_h3n2_benchmark.R` 仍引用该文件名检查  
是否被其他脚本引用：报告脚本路径检查  
分类：O  
是否属于正式 pipeline：命名过时但仍被 report 提及  
是否可以删除：报告脚本对齐前建议保留或归档  
是否可以移动：可归档  
================

================
文件路径：`output/h3n2_ha_benchmark/visualization_report.json`  
文件类型：JSON  
设计用途：可视化诊断  
当前作用：正式产物  
是否被其他脚本引用：否  
分类：O  
是否属于正式 pipeline：是  
是否可以删除：否  
是否可以移动：可随目录  
================

================
文件路径：`output/h3n2_ha_benchmark/benchmark_report.txt`  
文件类型：文本  
设计用途：基准文字汇总  
当前作用：正式报告  
是否被其他脚本引用：否（`report_h3n2_benchmark.R` 产出）  
分类：O  
是否属于正式 pipeline：是  
是否可以删除：否  
是否可以移动：可随目录  
================

================
文件路径：`output/h3n2_ha_benchmark/_smoke_in.fasta`  
文件路径：`output/h3n2_ha_benchmark/_smoke_aln.fasta`  
文件类型：FASTA  
设计用途：MAFFT/MUSCLE smoke 残留  
当前作用：无  
是否被其他脚本引用：否  
分类：T  
是否属于正式 pipeline：否  
是否可以删除：**是**  
是否可以移动：可  
================

### 3.5 `test-data/`

================
文件路径：`test-data/README.md`  
文件类型：文档  
设计用途：真实数据测试说明  
当前作用：有效  
是否被其他脚本引用：否  
分类：D  
是否属于正式 pipeline：测试配套 — 是  
是否可以删除：否  
是否可以移动：否  
================

================
文件路径：`test-data/h3n2_na_20.fasta`  
文件类型：FASTA  
设计用途：早期 H3N2 NA 20 条测试  
当前作用：非当前 HA 基准  
是否被其他脚本引用：否（未见编排硬编码）  
分类：I  
是否属于正式 pipeline：否  
是否可以删除：可归档  
是否可以移动：建议归档  
================

================
文件路径：`test-data/platform_16s.fasta`  
文件类型：FASTA  
设计用途：平台 raw 合并多序列  
当前作用：`run_test_real_data.ps1` 回退输入；`prepare_platform_fasta.R` 产出  
是否被其他脚本引用：是  
分类：I/O  
是否属于正式 pipeline：测试  
是否可以删除：可再生，可归档副本  
是否可以移动：可（改脚本路径）  
================

================
文件路径：`test-data/platform_16s_equal_len.fasta`  
文件类型：FASTA  
设计用途：等长版本 16S 测试  
当前作用：未见编排硬编码  
是否被其他脚本引用：否  
分类：I  
是否属于正式 pipeline：否  
是否可以删除：可归档  
是否可以移动：建议归档  
================

================
文件路径：`test-data/output/.gitkeep`  
文件类型：占位  
设计用途：保留测试输出目录  
当前作用：结构  
是否被其他脚本引用：否  
分类：D  
是否属于正式 pipeline：是（结构）  
是否可以删除：否  
是否可以移动：否  
================

### 3.6 `tools/`

================
文件路径：`tools/muscle.exe`  
文件类型：可执行文件  
设计用途：不等长序列比对  
当前作用：`phylogenetic_tree.R` 可查找并调用  
是否被其他脚本引用：是（运行时查找）  
分类：V  
是否属于正式 pipeline：**是（可选但强烈建议保留）**  
是否可以删除：否（无 PATH 全局 muscle 时必需）  
是否可以移动：需同步脚本查找逻辑  
================

================
文件路径：`tools/mafft-win/`（整树，约 106 文件）  
文件类型：厂商 MAFFT Windows 发行版  
设计用途：Windows 本地 MAFFT  
当前作用：`phylogenetic_tree.R` 在 `tools/mafft-win` 下解析可执行文件  
是否被其他脚本引用：是  
分类：V  
是否属于正式 pipeline：**是**  
是否可以删除：**否**  
是否可以移动：需同步查找路径  
说明：内部含 `mafft.bat`、`mafft-signed.ps1`、`usr/bin/mafft`、perl/ruby 辅助脚本、man 页、`testdata.txt` 等；按厂商树整体保留，不逐文件清理。  
================

================
文件路径：`tools/mafft-7.526-win64-signed.zip`  
文件路径：`tools/mafft-fresh.zip`  
文件类型：安装包 zip（各约 25MB）  
设计用途：下载/解压源  
当前作用：已解压到 `mafft-win/`；运行时不读 zip  
是否被其他脚本引用：否  
分类：T/V 安装残留  
是否属于正式 pipeline：否  
是否可以删除：可（建议归档后删以省空间）  
是否可以移动：建议归档  
================

================
文件路径：`tools/_smoke.fa` / `tools/_smoke_muscle.fa`  
文件类型：FASTA  
设计用途：工具可用性 smoke  
当前作用：无  
是否被其他脚本引用：否  
分类：T  
是否属于正式 pipeline：否  
是否可以删除：**是**  
是否可以移动：可  
================

================
文件路径：`tools/mafft-extract/`  
文件类型：空目录  
设计用途：解压中转  
当前作用：空  
是否被其他脚本引用：否  
分类：T  
是否属于正式 pipeline：否  
是否可以删除：**是**  
是否可以移动：可  
================

---

## 4. 审计结论（摘要）

| 区域 | 结论 |
|------|------|
| 正式热路径 | `phylogenetic_tree.R` →（可选 metadata）→ `ggtree_visualization.R`；基准编排 `run_h3n2_ha_benchmark.ps1` |
| Spring Boot | **仅**暴露建树脚本；viz/metadata 为下一步 |
| 最大可清理体积 | 两个 MAFFT zip（~50MB）+ probe/smoke/旧 circular 产物 |
| 切勿删 | `scripts` 核心 R、`data/ncbi_h3n2_ha_benchmark/`、`tools/muscle.exe`、`tools/mafft-win/`、`output/h3n2_ha_benchmark/` 正式成品 |
| 命名债 | `circular_tree_distance` vs `circular_tree_final`；README 与 `report_h3n2_benchmark.R` 待对齐 |

详细四类处置见 [`cleanup_plan.md`](cleanup_plan.md)。
