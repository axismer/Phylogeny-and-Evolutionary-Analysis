# 多生物类型系统发育分析框架

> 版本：`v0.1-framework`  
> 日期：2026-07-24  
> 原则：**旁路新增架构；不移动/不改写** `engine/phylogenetic_tree.R`、`engine/ggtree_visualization.R`、H3N2 benchmark 与现有 output。

---

## 1. 设计目标

用户上传数据时可选择：

1. Virus  
2. Bacteria  
3. Archaea  
4. Eukaryote  

不同类型走不同 Strategy，但共享：

- 统一 CLI：`runners/run_analysis.R`
- 统一输入：`sequence.fasta` + `metadata.csv`
- 统一输出：`analysis_result.json`

模式：**Strategy Pattern**（`PhyloAnalysisStrategy`）。

---

## 2. 目录结构（新增 + 保留）

```text
r-analysis/
├── engine/                          # ★ 冻结生产引擎（勿改算法）
│   ├── phylogenetic_tree.R
│   ├── ggtree_visualization.R
│   ├── ncbi_metadata_to_tree_metadata.R
│   └── add_bootstrap_labels_only.R
│
├── core/                            # ★ 公共阶段接口（薄封装，不复制算法）
│   ├── strategy_base.R              # PhyloAnalysisStrategy 契约
│   ├── alignment.R
│   ├── distance.R
│   ├── tree_builder.R
│   ├── visualization.R
│   └── result_writer.R              # 统一 analysis_result.json
│
├── strategies/
│   ├── strategy_registry.R          # get_strategy(--type)
│   ├── virus/
│   │   ├── virus_strategy.R         # 委托 legacy engine
│   │   └── virus_annotation.R
│   ├── bacteria/                    # 骨架 only
│   ├── archaea/                     # 骨架 only
│   └── eukaryote/                   # 骨架 only
│
├── metadata/
│   ├── metadata_schema.md
│   └── metadata_validator.R
│
├── runners/
│   └── run_analysis.R               # 统一 CLI（未来 Boot 主入口）
│
├── config/
│   └── analysis_config.yaml
│
├── input/
│   ├── README.md
│   └── templates/                   # 各类型 metadata 表头
│
├── scripts/                         # 既有 prep / demo / runners（保留）
├── data/benchmarks/h3n2_ha/         # ★ H3N2 基准输入（保留）
├── output/benchmarks/h3n2_ha/       # ★ H3N2 基准产物（保留）
└── docs/
    └── multi_organism_framework.md  # 本文件
```

---

## 3. 模块职责

| 模块 | 职责 |
|------|------|
| `core/strategy_base.R` | 定义 `PhyloAnalysisStrategy`：`validate_input` / `parse_metadata` / `tree_params` / `annotation_config` / `output_spec` / `run` |
| `core/alignment.R` | 比对阶段契约；过渡期指向 legacy engine |
| `core/distance.R` | 距离阶段契约与默认 model |
| `core/tree_builder.R` | 建树契约；`invoke_legacy_tree_engine()` 子进程调用冻结脚本 |
| `core/visualization.R` | 可视化契约；`invoke_legacy_ggtree_viz()` |
| `core/result_writer.R` | 统一 JSON 写出与旧结果字段升级 |
| `strategies/*` | 各生物类型策略与 annotation |
| `metadata/*` | schema 文档 + CSV 校验 |
| `runners/run_analysis.R` | `--type` 分发入口 |
| `config/analysis_config.yaml` | 默认参数声明 |
| `engine/*` | **现有算法与可视化实现（稳定契约）** |

---

## 4. Strategy 接口

每个 Strategy 必须实现：

1. **输入数据检查** — `validate_input(ctx)`
2. **metadata 解析** — `parse_metadata(ctx)`
3. **建树参数配置** — `tree_params(ctx)`
4. **annotation 配置** — `annotation_config(ctx)`
5. **输出格式定义** — `output_spec(ctx)`
6. **编排执行** — `run(ctx)`（调用 `core/*`，禁止复制 JC69 实现）

工厂：

```r
strategy <- get_strategy("virus")  # strategies/strategy_registry.R
result  <- strategy$run(ctx)
```

---

## 5. 统一 CLI

```bash
Rscript runners/run_analysis.R \
  --type virus \
  --fasta input/sequence.fasta \
  --metadata input/metadata.csv \
  --output output/tasks/<runId>
```

| `--type` | Strategy | 当前状态 |
|----------|----------|----------|
| `virus` | `VirusPhyloStrategy` | 生产：委托 `engine/phylogenetic_tree.R`（+ 可选 ggtree） |
| `bacteria` | `BacteriaPhyloStrategy` | 生产：委托 legacy engine + bacteria viz |
| `archaea` | `ArchaeaPhyloStrategy` | `status=not_implemented`（exit 2） |
| `eukaryote` | `EukaryotePhyloStrategy` | 同上 |

统一结果契约（**v0.1 冻结**）：见 [`docs/analysis_result_contract.md`](analysis_result_contract.md)。  
冻结报告：[`docs/framework_freeze_report.md`](framework_freeze_report.md)。

```json
{
  "status": "success",
  "organism_type": "virus",
  "input": "sequences.fasta",
  "tree": "tree.nwk",
  "visualization": "circular_tree_final.png",
  "metadata": "metadata.csv",
  "statistics": {},
  "error_message": ""
}
```

过渡期额外保留别名（`tree_file`, `sequence_count`, `method`, `model`, …）以便现有 Java DTO 兼容。

---

## 6. Virus 如何迁移到新架构

**目标：零破坏迁移，分三步。**

### 阶段 A — 双入口并存（当前）

| 入口 | 用途 |
|------|------|
| `engine/phylogenetic_tree.R <fasta> <out>` | Spring Boot 现有配置（保持） |
| `runners/run_analysis.R --type virus ...` | 新统一入口（旁路） |
| `scripts/runners/run_h3n2_ha_benchmark.ps1` | H3N2 可复现基准（保持） |

VirusStrategy 内部：`system2(Rscript, engine/phylogenetic_tree.R …)`，**不改算法**。

### 阶段 B — Boot 切换主入口

1. `phylo.r.script` → `../r-analysis/runners/run_analysis.R`
2. ProcessBuilder 改为传 `--type --fasta --metadata --output`
3. 解析扩展后的 `analysis_result.json`（含 `organism_type`）
4. 保留旧脚本路径配置一段时间作回滚

### 阶段 C —（可选）抽出函数库

将 `phylogenetic_tree.R` 中纯函数抽到 `core/*.R`，CLI 薄壳调用；**仅在有回归测试覆盖 H3N2 后再做**。在此之前禁止改写 JC69 / K80 逻辑。

### 映射关系

```text
旧 H3N2 流程                         新框架对应
─────────────────────────────────────────────────────
FASTA                                ctx$fasta_path
alignment / distance / ML JC69       VirusStrategy → legacy engine
tree.nwk                             output_spec$tree_file
ncbi_metadata_to_tree_metadata.R     仍可用于基准；新任务用统一 metadata.csv
ggtree circular                      VirusStrategy → legacy ggtree（有 metadata 时）
analysis_result.json                 result_writer 升级字段
```

---

## 7. Bacteria 后续需实现的文件

最小可交付集合：

| 文件 | 工作内容 |
|------|----------|
| `strategies/bacteria/bacteria_strategy.R` | 实现 `run()`：校验 → 比对 → 距离 → 建树 → 写结果 |
| `strategies/bacteria/bacteria_annotation.R` | taxonomy / environment 等环图映射 |
| `metadata` 模板 | 已有 `input/templates/bacteria_metadata.csv` |
| 测试数据 | `data/smoke/` 或 `test-data/fixtures/` 增加细菌小样本 |
| `config/analysis_config.yaml` | `bacteria.enabled: true` + 选定 model |
| （可选）`core/distance.R` / `tree_builder.R` | 增加 bacteria 分支参数，仍复用公共写出逻辑 |
| Spring Boot | UI 选择 Bacteria + 传 `--type bacteria` |

**明确不做（本框架阶段）**：完整 16S/全基因组 bacteria pipeline 算法实现。

Archaea / Eukaryote 同理，对应各自 `*_strategy.R` / `*_annotation.R`。

---

## 8. Spring Boot 调用建议

### 8.1 配置（建议新增，旧项保留）

```properties
# 旧（过渡保留）
phylo.r.script=../r-analysis/engine/phylogenetic_tree.R

# 新统一入口
phylo.r.entrypoint=../r-analysis/runners/run_analysis.R
phylo.r.rscript=Rscript
phylo.r.timeout-seconds=600
```

### 8.2 进程参数

```text
Rscript runners/run_analysis.R
  --type {virus|bacteria|archaea|eukaryote}
  --fasta {abs/path/sequence.fasta}
  --metadata {abs/path/metadata.csv}
  --output {abs/path/output/tasks/{runId}}
```

### 8.3 API 草案

```http
POST /api/r-analysis/runs
Content-Type: multipart/form-data

organismType: virus
fasta: <file>
metadata: <file>
```

响应：

```json
{
  "runId": "...",
  "status": "success",
  "organismType": "virus",
  "treeFile": "tree.nwk",
  "visualization": "circular_tree_final.png",
  "metadata": "metadata.csv",
  "statistics": {},
  "outputDir": ".../output/tasks/{runId}"
}
```

### 8.4 Java 侧注意点

1. 工作目录建议设为 `r-analysis/` 或对脚本使用绝对路径  
2. 读取 `analysis_result.json`：先认新字段，旧字段作 fallback  
3. `exitCode == 2` → 类型未实现（可映射 501 / 业务错误）  
4. 任务输出只写 `output/tasks/{runId}/`，**禁止覆盖** `output/benchmarks/h3n2_ha/`  
5. UI 在选择 organism type 后展示对应 metadata 扩展字段表单  

### 8.5 兼容策略

```text
Boot 1.x：只调 phylogenetic_tree.R（现状）
Boot 1.y：可调 run_analysis.R，默认 type=virus
Boot 2.0：强制统一入口 + organismType 必填
```

---

## 9. 验收清单（本阶段）

- [x] 新目录与接口文件就位  
- [x] metadata schema 文档  
- [x] 统一 CLI 骨架  
- [x] Virus 委托 legacy；Bacteria/Archaea/Eukaryote 返回 `not_implemented`  
- [x] **未修改** 建树/可视化算法脚本  
- [x] **未移动** H3N2 benchmark 与现有 output  

---

## 10. 相关文档

- [`docs/analysis_result_contract.md`](analysis_result_contract.md) — **v0.1 输出契约（冻结）**
- [`docs/framework_freeze_report.md`](framework_freeze_report.md) — **v0.1 冻结报告**
- [`docs/framework_architecture_audit.md`](framework_architecture_audit.md) — Hardening 架构审计
- [`docs/new_organism_development_guide.md`](new_organism_development_guide.md) — 新类型接入规范
- [`docs/error_handling_audit.md`](error_handling_audit.md) — 异常路径审计
- [`docs/framework_test_matrix.md`](framework_test_matrix.md) — 测试矩阵
- [`docs/framework_progress_report_v0.1.md`](framework_progress_report_v0.1.md) — 阶段进度报告
- [`docs/strategy_runner_design.md`](strategy_runner_design.md) — v0.2 公共执行模板
- [`docs/plugin_registry_design.md`](plugin_registry_design.md) — v0.2 半自动注册
- [`docs/framework_test_report_v0.2.md`](framework_test_report_v0.2.md) — v0.2 测试报告
- [`docs/framework_hardening_v0.2_report.md`](framework_hardening_v0.2_report.md) — v0.2 Hardening 工程报告
- [`metadata/metadata_schema.md`](../metadata/metadata_schema.md)
- [`STABLE_H3N2_HA_PIPELINE.md`](../STABLE_H3N2_HA_PIPELINE.md)
- [`docs/migration_plan.md`](migration_plan.md)
