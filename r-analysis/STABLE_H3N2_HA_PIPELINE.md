# H3N2 HA Pipeline — 稳定版本记录（Frozen Snapshot）

> **版本标签**：`h3n2-ha-pipeline-stable-2026-07-24`  
> **记录日期**：2026-07-24  
> **状态**：已验证成功；**2026-07-24 已按 `docs/migration_plan.md` 完成目录迁移并复验**  
> **原则**：冻结时不删文件；迁移仅 `git mv` + 路径更新。

### 迁移后路径（以本表为准）

| 角色 | 新路径 |
|------|--------|
| 建树 | `engine/phylogenetic_tree.R` |
| metadata | `engine/ncbi_metadata_to_tree_metadata.R` |
| circular | `engine/ggtree_visualization.R` |
| 编排 | `scripts/runners/run_h3n2_ha_benchmark.ps1` |
| 输入 | `data/benchmarks/h3n2_ha/` |
| 输出 | `output/benchmarks/h3n2_ha/` |
| Boot 配置 | `phylo.r.script=../r-analysis/engine/phylogenetic_tree.R` |

下文若仍出现旧路径 `scripts/phylogenetic_tree.R` / `data/ncbi_h3n2_ha_benchmark` / `output/h3n2_ha_benchmark`，一律按上表映射。

---

## 0. 快照身份

| 项 | 值 |
|----|-----|
| 仓库路径 | `D:/Projects/phylo-platform/r-analysis` |
| 记录时 git HEAD | `411c1f8ee39c74dd99a357bbf5b337fd9749d601`（`master`） |
| 注意 | 工作区存在未提交改动；**以本文件所列路径 + SHA256 前缀为准**，不以「干净 git tree」为准 |
| 序列数 / tips | **167** |
| 建树方法 | Maximum Likelihood / **JC69** |
| 可视化 | ggtree + ggtreeExtra `geom_fruit(geom_tile)`；Country + Year 双环 |
| 正式图 | `circular_tree_final.png` / `.pdf`（2026-07-24 14:14:17） |
| Bootstrap | 树内真实 `node.label`；展示阈值 ≥70；显示 72 / 总数 151 |

### 如何用本记录恢复

若目录重构失败：

1. 对照 §3「不可删除」清单，确认文件仍在**当前路径**（或从备份拷回）。  
2. 用 §5 SHA256 前缀校验关键输入/脚本/成品是否被改坏。  
3. 按 §1 流程从编排脚本重跑（或逐步 CLI）。  
4. 成功判据：§6。

---

## 1. 完整运行流程（当前已验证）

### 1.1 一键编排（推荐）

```powershell
cd D:\Projects\phylo-platform\r-analysis\scripts
.\run_h3n2_ha_benchmark.ps1
```

编排内部顺序（与脚本一致）：

```text
[前置]
  PATH += r-analysis/tools
  PATH += r-analysis/tools/mafft-win

[1/3] 建树
  Rscript scripts/phylogenetic_tree.R
    <data/ncbi_h3n2_ha_benchmark/h3n2_ha_unaligned.fasta>
    <output/h3n2_ha_benchmark>
  → distance_matrix.csv, tree.nwk, tree.png, analysis_result.json

[2/3] metadata 对齐
  Rscript scripts/ncbi_metadata_to_tree_metadata.R
    <data/ncbi_h3n2_ha_benchmark/ncbi_metadata.csv>
    <output/h3n2_ha_benchmark/tree.nwk>
    <output/h3n2_ha_benchmark/metadata.csv>
  → tip 顺序 100% 对齐的 metadata.csv（label,Country,Year,Host）

[3/3] 论文级 circular
  Rscript scripts/ggtree_visualization.R
    <output/h3n2_ha_benchmark/tree.nwk>
    <output/h3n2_ha_benchmark/metadata.csv>
    <output/h3n2_ha_benchmark>
  → circular_tree_final.png, circular_tree_final.pdf, visualization_report.json

[附加] 文字汇总
  Rscript scripts/report_h3n2_benchmark.R
    <output/h3n2_ha_benchmark>
    <data/ncbi_h3n2_ha_benchmark/ncbi_metadata.csv>
  → benchmark_report.txt
```

### 1.2 可选增强（非编排默认步，但已用于当前树）

当前 `tree.nwk` 含真实 bootstrap（`visualization_report.bootstrap.present=true`）。  
若需在**不改拓扑/枝长**前提下重贴 bootstrap：

```text
Rscript scripts/add_bootstrap_labels_only.R
  <data/ncbi_h3n2_ha_benchmark/h3n2_ha_unaligned.fasta>
  <已有 tree.nwk>
  <输出 tree.nwk>
  [bs=100]
```

备份参考：`output/h3n2_ha_benchmark/tree.nwk.bak_nobootstrap`（补 bootstrap 前）。

### 1.3 基准输入如何再生（离线准备，非日常热路径）

```text
Rscript scripts/prepare_h3n2_ha_benchmark.R
  [output_dir=data/ncbi_h3n2_ha_benchmark]
  [target_n]
→ h3n2_ha_unaligned.fasta, ncbi_metadata.csv, sampling_report.txt
```

**稳定版恢复优先使用已落盘的 `data/ncbi_h3n2_ha_benchmark/`，不要轻易重抽。**

### 1.4 数据流图

```text
data/ncbi_h3n2_ha_benchmark/
  h3n2_ha_unaligned.fasta ──┐
  ncbi_metadata.csv ────────┼──┐
                            │  │
                            ▼  │
              phylogenetic_tree.R
                            │  │
                            ▼  │
              output/h3n2_ha_benchmark/
                tree.nwk ──────────────┤
                distance_matrix.csv    │
                tree.png               │
                analysis_result.json   │
                                       ▼
                         ncbi_metadata_to_tree_metadata.R
                                       │
                                       ▼
                                 metadata.csv
                                       │
                                       ▼
                         ggtree_visualization.R
                                       │
                                       ▼
                         circular_tree_final.png/pdf
                         visualization_report.json
                                       │
                                       ▼
                         report_h3n2_benchmark.R
                                       │
                                       ▼
                         benchmark_report.txt

运行时依赖（查找/PATH）：
  tools/muscle.exe
  tools/mafft-win/   （mafft.bat 等）
```

---

## 2. 全部输入 / 输出路径

根目录：`r-analysis/`（绝对：`D:/Projects/phylo-platform/r-analysis`）

### 2.1 输入（不可替代则无法按本快照复现）

| 角色 | 路径 |
|------|------|
| 未比对 FASTA | `data/ncbi_h3n2_ha_benchmark/h3n2_ha_unaligned.fasta` |
| NCBI 元数据 | `data/ncbi_h3n2_ha_benchmark/ncbi_metadata.csv` |
| 抽样可追溯 | `data/ncbi_h3n2_ha_benchmark/sampling_report.txt` |
| 编排脚本 | `scripts/run_h3n2_ha_benchmark.ps1` |
| 建树引擎 | `scripts/phylogenetic_tree.R` |
| metadata 桥 | `scripts/ncbi_metadata_to_tree_metadata.R` |
| circular 可视化 | `scripts/ggtree_visualization.R` |
| 汇总报告 | `scripts/report_h3n2_benchmark.R` |
| （可选）bootstrap | `scripts/add_bootstrap_labels_only.R` |
| MUSCLE | `tools/muscle.exe` |
| MAFFT | `tools/mafft-win/`（整树） |

### 2.2 输出目录

| 角色 | 路径 |
|------|------|
| 任务输出根 | `output/h3n2_ha_benchmark/` |

### 2.3 输出文件明细

| 文件 | 角色 | 本快照状态 |
|------|------|------------|
| `tree.nwk` | ML 树 + bootstrap labels | **正式**（mtime 11:46；含 BS） |
| `tree.nwk.bak_nobootstrap` | 补 BS 前备份 | 保留参考 |
| `distance_matrix.csv` | K80 距离矩阵 | 正式 |
| `tree.png` | 简易矩形树 | 正式 |
| `analysis_result.json` | 建树机器摘要 | 正式；`status=success` |
| `metadata.csv` | tip 对齐 Country/Year | 正式 |
| `circular_tree_final.png` | **正式 circular PNG @300dpi** | **正式成品** |
| `circular_tree_final.pdf` | 正式 circular 矢量 | **正式成品** |
| `visualization_report.json` | 可视化诊断 | 正式；`status=success` |
| `benchmark_report.txt` | tip/年/国/枝长汇总 | 正式 |
| `circular_tree_distance.png/.pdf` | 旧/过渡命名产物 | 历史并存；非当前契约名 |
| `_smoke_in.fasta` / `_smoke_aln.fasta` | 工具 smoke 残留 | 非 pipeline 产物 |

### 2.4 关键产物指标（验证时）

| 指标 | 值 |
|------|-----|
| tip_count | 167 |
| year_span | 2007–2024（15 个年份有样本） |
| regions (Country) | Americas 56, Asia 55, Europe 38, Oceania 18 |
| branch_length max / mean / median | 0.1054 / 0.0022 / 0.0006 |
| bootstrap displayed (≥70) | 72 |
| analysis_result.method | Maximum Likelihood / JC69 |

---

## 3. 不可删除文件（重构失败时的恢复底线）

下列文件/目录在重构、归档、清理时**禁止删除**（可复制，勿丢）：

### 3.1 脚本（逻辑）

- `scripts/run_h3n2_ha_benchmark.ps1`
- `scripts/phylogenetic_tree.R`
- `scripts/ncbi_metadata_to_tree_metadata.R`
- `scripts/ggtree_visualization.R`
- `scripts/report_h3n2_benchmark.R`
- `scripts/add_bootstrap_labels_only.R`（恢复含 BS 的树时需要）
- `scripts/prepare_h3n2_ha_benchmark.R`（仅当需从零重抽基准时）

### 3.2 基准输入（数据）

- `data/ncbi_h3n2_ha_benchmark/h3n2_ha_unaligned.fasta`
- `data/ncbi_h3n2_ha_benchmark/ncbi_metadata.csv`
- `data/ncbi_h3n2_ha_benchmark/sampling_report.txt`

### 3.3 已验证输出（成品）

- `output/h3n2_ha_benchmark/tree.nwk`
- `output/h3n2_ha_benchmark/metadata.csv`
- `output/h3n2_ha_benchmark/circular_tree_final.png`
- `output/h3n2_ha_benchmark/circular_tree_final.pdf`
- `output/h3n2_ha_benchmark/visualization_report.json`
- `output/h3n2_ha_benchmark/analysis_result.json`
- `output/h3n2_ha_benchmark/distance_matrix.csv`
- `output/h3n2_ha_benchmark/benchmark_report.txt`
- `output/h3n2_ha_benchmark/tree.png`（建议一并保留）

### 3.4 运行时工具

- `tools/muscle.exe`
- `tools/mafft-win/`（整目录）

### 3.5 本记录自身

- `STABLE_H3N2_HA_PIPELINE.md`（本文件）

> 明确：**不可删除 ≠ 不可移动**。若按 `migration_plan.md` 移动，必须先备份本清单路径，并同步改编排/Java 路径后再删旧路径副本。

---

## 4. Spring Boot 可能调用的文件

### 4.1 当前已对接

| 组件 | 路径 / 配置 |
|------|-------------|
| R 脚本 | `scripts/phylogenetic_tree.R` |
| 配置 | `backend/src/main/resources/application.properties` → `phylo.r.script=../r-analysis/scripts/phylogenetic_tree.R` |
| 属性类 | `PhyloRProperties`（默认同上） |
| 服务 | `ProcessBuilderRPhylogeneticAnalysisService` |
| API | `/api/r-analysis`（`RAnalysisController`） |
| CLI | `Rscript phylogenetic_tree.R <input.fasta> <output_dir>` |
| 期望输出 | `distance_matrix.csv`, `tree.nwk`, `tree.png`, `analysis_result.json` |
| 运行时工具 | `tools/muscle.exe`, `tools/mafft-win/`（脚本侧查找） |

### 4.2 下一步很可能对接（P0）

| 脚本 | CLI | 产出 |
|------|-----|------|
| `scripts/ggtree_visualization.R` | `Rscript ... <tree.nwk> <metadata.csv> <output_dir>` | `circular_tree_final.png/pdf`, `visualization_report.json` |
| `scripts/ncbi_metadata_to_tree_metadata.R` | `Rscript ... <ncbi_metadata.csv> <tree.nwk\|fasta> <out.csv>` | tip 对齐 `metadata.csv` |

### 4.3 可选对接（P1）

| 脚本 | 用途 |
|------|------|
| `scripts/add_bootstrap_labels_only.R` | 已有树补真实 bootstrap |

### 4.4 一般不由 Boot 调用（人工/科研）

| 脚本 | 用途 |
|------|------|
| `scripts/run_h3n2_ha_benchmark.ps1` | 端到端基准编排 |
| `scripts/report_h3n2_benchmark.R` | 文字报告 |
| `scripts/prepare_h3n2_ha_benchmark.R` | 在线抽样造集 |
| `scripts/parse_ncbi_genbank_ha.R` | GenBank 解析（P2 才可能） |

---

## 5. 完整性指纹（SHA256 前 16 位）

记录时计算，用于重构后核对「是否仍是这一版」。

### 5.1 脚本

| 相对路径 | bytes | SHA256[:16] |
|----------|------:|-------------|
| `scripts/run_h3n2_ha_benchmark.ps1` | 1856 | `CFB56BE98B46B935` |
| `scripts/phylogenetic_tree.R` | 18142 | `748231817ED56B24` |
| `scripts/ncbi_metadata_to_tree_metadata.R` | 8949 | `E70FB782CF6E3ACA` |
| `scripts/ggtree_visualization.R` | 32039 | `9CC1F17B44C50B15` |
| `scripts/report_h3n2_benchmark.R` | 2653 | `8C901EF74AAF9EE4` |
| `scripts/add_bootstrap_labels_only.R` | 3185 | `217409C853DA040E` |

### 5.2 输入

| 相对路径 | bytes | SHA256[:16] |
|----------|------:|-------------|
| `data/ncbi_h3n2_ha_benchmark/h3n2_ha_unaligned.fasta` | 291277 | `2FB413080D9B31B0` |
| `data/ncbi_h3n2_ha_benchmark/ncbi_metadata.csv` | 30041 | `80949F39B3F8E0EC` |
| `data/ncbi_h3n2_ha_benchmark/sampling_report.txt` | 960 | `0E42E0B694FE9FFD` |

### 5.3 关键输出

| 相对路径 | bytes | SHA256[:16] |
|----------|------:|-------------|
| `output/h3n2_ha_benchmark/tree.nwk` | 8381 | `69CCC12653CD8B8A` |
| `output/h3n2_ha_benchmark/metadata.csv` | 7040 | `B0CD567485E47DD0` |
| `output/h3n2_ha_benchmark/circular_tree_final.png` | 198494 | `C9EF8B47C5B42EB2` |
| `output/h3n2_ha_benchmark/circular_tree_final.pdf` | 28459 | `46B44365AAF75442` |
| `output/h3n2_ha_benchmark/visualization_report.json` | 2353 | `A41A5C7018C37DA1` |
| `output/h3n2_ha_benchmark/analysis_result.json` | 247 | `5BDB00194D35F5E1` |
| `output/h3n2_ha_benchmark/benchmark_report.txt` | 1186 | `42D58A33121FD964` |

校验示例（PowerShell）：

```powershell
Get-FileHash .\output\h3n2_ha_benchmark\circular_tree_final.png -Algorithm SHA256
```

---

## 6. 成功判据（恢复后验收）

同时满足即可认为「回到本稳定版能力」：

1. `analysis_result.json` → `"status": "success"`，`sequence_count` = 167  
2. `visualization_report.json` → `"status": "success"`，`tip_count` = 167，`bootstrap.present` = true  
3. 存在 `circular_tree_final.png` 与 `.pdf`  
4. `metadata.csv` 行数 = tips + 表头（168 行量级），`label` 与 `tree.nwk` tip 一一对应  
5. （严格）§5 关键输出哈希一致；或（宽松）指标与 §2.4 一致且图可读  

---

## 7. 与其他文档关系

| 文档 | 关系 |
|------|------|
| `directory_audit.md` | 全目录审计；本文件是其中 H3N2 热路径的冻结切片 |
| `cleanup_plan.md` | 清理建议；执行前以本文件「不可删除」为准 |
| `migration_plan.md` | 生产化移动设计；移动前先备份本清单路径 |

---

## 8. 声明

- 本文生成时：**未修改任何代码，未移动，未删除任何文件。**  
- 标签：`h3n2-ha-pipeline-stable-2026-07-24`  
- 正式可视化契约文件名：**`circular_tree_final.*`**（不是 `circular_tree_distance.*`）
