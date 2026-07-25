# Organism Extension Guide

> Framework v0.3 P4  
> 日期：2026-07-24  
> 目的：新增 `organism_type` 的标准接入流程（**仅加目录 + plugin**，不改 registry / core / runner）  
> 相关：[`error_code_reference.md`](error_code_reference.md)、[`plugin_contract.R`](../core/plugin_contract.R)、[`analysis_result_contract.md`](analysis_result_contract.md)

---

## 0. 原则

| 做 | 不做 |
|----|------|
| 新增 `strategies/<type>/` | 修改 `engine/` |
| 实现 `plugin.R`（五函数契约） | 修改 Spring Boot / frontend |
| 复用 `core/io`、`result_writer`、`strategy_runner` | 改 virus/bacteria 成功 JSON 字段 |
| 增加 fixtures + regression | 为实现新类型而改 `strategy_registry.R` 硬编码列表 |

当前生产：`virus`、`bacteria`、**`fungi`（v0.3 P5 ITS）**。  
`archaea` / `eukaryote` 仅为 **stub plugin**（`get_status() = "stub"`），**禁止**在本指南流程中当作已实现管线。

---

## 1. 创建 `strategies/{type}/`

```text
r-analysis/strategies/<type>/
├── plugin.R                 # 必须：插件契约入口
├── <type>_strategy.R        # 必须：create_<type>_strategy()
├── <type>_annotation.R      # 必须：rings / 列映射
└── <type>_visualization.R   # 推荐：类型专用可视化（或明确复用 legacy）
```

目录名必须与 `get_organism_type()` 返回值一致（小写）。

---

## 2. 实现 `plugin.R`

必须提供（由 `validate_plugin_contract()` 校验）：

| 函数 | 返回 |
|------|------|
| `get_organism_type()` | 小写类型名，如 `"fungi"` |
| `get_status()` | `"production"` 或 `"stub"` |
| `get_metadata_schema()` | `list(extra_columns=..., required_core=..., strict_default=...)` |
| `get_default_config()` | `list(tree=..., distance=..., visualization=...)` |
| `get_strategy()` | 返回 `PhyloAnalysisStrategy` 实例 |

示例骨架：

```r
get_organism_type <- function() "fungi"
get_status <- function() "production"

get_metadata_schema <- function() {
  list(
    organism_type = "fungi",
    extra_columns = c("taxonomy", "habitat"),
    required_core = c("sample_id", "organism_type"),
    shared_optional = c("collection_date", "location", "host"),
    strict_default = FALSE
  )
}

get_default_config <- function() {
  list(
    tree = list(method = "Maximum Likelihood", model = "JC69", ...),
    distance = list(model = "K80", pairwise_deletion = TRUE),
    visualization = list(layout = "circular", ring_fields = c("taxonomy"), ...)
  )
}

get_strategy <- function() {
  dirs <- .get_framework_dirs()
  sf <- file.path(dirs$strategies, "fungi", "fungi_strategy.R")
  if (!exists("create_fungi_strategy", mode = "function")) {
    source(sf, local = FALSE)
  }
  create_fungi_strategy()
}
```

框架会自动扫描 `strategies/*/plugin.R`，**无需**修改 registry。

---

## 3. 实现 strategy

实现 `create_<type>_strategy()`，通过 `new_phylo_strategy()` 填方法槽：

| 方法 | 要求 |
|------|------|
| `validate_input` | FASTA / 序列规则；失败用 `raise_framework_error` |
| `parse_metadata` | 读 CSV（优先 `core/io/metadata_io.R`）；schema 校验 |
| `tree_params` | 可基于 `default_tree_params(type)` / plugin config |
| `annotation_config` | 调本类型 annotation |
| `output_spec` | 通常 `default_output_spec(type)` |
| `run` | 经 `run_strategy_pipeline`；成功用 `write_analysis_output` |

约束：

- 建树优先委托 `invoke_legacy_tree_engine()`（**不改** `engine/phylogenetic_tree.R`）
- tip 对齐用 `helpers$assert_tips`
- 成功 JSON：**禁止**带 `error_code` 键

参考：`strategies/virus/virus_strategy.R`、`strategies/bacteria/bacteria_strategy.R`（只读参考，勿改其 `run` 组装）。

---

## 4. 定义 metadata schema

1. 在 `plugin.R` → `get_metadata_schema()$extra_columns` 声明类型扩展列  
2. 更新 `metadata/metadata_schema.md` 文档表  
3. 提供 `input/templates/<type>_metadata.csv` 表头模板  
4. **不必**再改 `TYPE_EXTRA_COLUMNS`（P3 起 plugin 优先；该表仅为 deprecated fallback）

核心列始终：`sample_id`、`organism_type`（与 CLI `--type` 一致）。

---

## 5. 定义 annotation

在 `<type>_annotation.R`：

- 环字段 / 调色 / tip id 列（通常映射出 `label`）
- `map_<type>_metadata_for_viz(meta)` → 与 tree tip 对齐的表

可视化：

- 推荐独立 `*_visualization.R` CLI  
- 或短期复用 `invoke_legacy_ggtree_viz()`（须映射兼容列）  
- **禁止**修改 `engine/ggtree_visualization.R` 迁就新类型

---

## 6. 增加 fixtures

```text
test-data/<type>/
├── valid/              # FASTA + metadata，tip 对齐
├── empty/              # 空 FASTA（可选）
├── illegal_dna/        # 非法碱基（若适用）
├── too_few/            # < 最少序列数
├── tip_mismatch/       # metadata 与 tip 不对齐
└── missing_fields/     # 缺扩展列 / 必需列
```

---

## 7. 增加 regression

最低要求：

1. 在 `scripts/runners/` 增加或扩展 case：`--type <type> --fasta ... --output ...`  
2. 断言：
   - valid → exit 0；`status` ∈ {success, partial}；**无** `error_code`
   - 错误路径 → exit 1；对应 `error_code`（见 [`error_code_reference.md`](error_code_reference.md)）
   - stub → exit 2；`UNSUPPORTED_ORGANISM`
3. 跑兼容套件确认未破坏既有：

```bash
cd r-analysis
Rscript scripts/runners/run_framework_regression.R
Rscript scripts/runners/run_framework_v03_p1_regression.R
Rscript scripts/runners/run_framework_v03_p2_regression.R
Rscript scripts/runners/run_framework_v03_p3_regression.R
Rscript scripts/runners/run_framework_v03_p4_regression.R
```

---

## 8. 验收清单

- [ ] `strategies/<type>/plugin.R` 通过 `validate_plugin_contract`
- [ ] 目录名 == `get_organism_type()`
- [ ] `Rscript runners/run_analysis.R --type <type> ...` 可发现（无需改 registry）
- [ ] valid / 错误 / tip 不匹配夹具齐全
- [ ] 成功 JSON 无 `error_code`；失败 JSON 含 `error_code` + `error_message`
- [ ] 未修改 `engine/`、Boot、frontend、H3N2 benchmark、virus/bacteria `run` 组装

---

## 9. stub vs production

| `get_status()` | 含义 | CLI 期望 |
|----------------|------|----------|
| `production` | 完整 pipeline | exit 0（成功）或 1（业务错误） |
| `stub` | 仅骨架 | 通常 exit 2 + `not_implemented` + `UNSUPPORTED_ORGANISM` |

新增生产类型请用 `production`；不要把未完成管线标为 production。
