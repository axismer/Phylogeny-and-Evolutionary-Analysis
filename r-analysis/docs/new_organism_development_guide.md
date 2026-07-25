# New Organism Development Guide

> **注意（v0.3 P4）：** 请优先阅读更新版 [`organism_extension_guide.md`](organism_extension_guide.md)  
> （plugin.R 契约 + 仅增目录、不改 registry）。下文为 v0.1 历史清单，部分步骤（改 `TYPE_EXTRA_COLUMNS` / `PHYLO_ORGANISM_TYPES`）已降为 deprecated fallback。

> 版本：`v0.1-hardening`（superseded by organism_extension_guide for v0.3）  
> 日期：2026-07-24  
> 目的：定义**第三方 / 新生物类型**接入规范  
> 原则：旁路扩展；**禁止**为接新类型而改写冻结生产路径

相关：[`framework_architecture_audit.md`](framework_architecture_audit.md)、[`analysis_result_contract.md`](analysis_result_contract.md)

---

## 1. 何时使用本指南

在 **不实现** archaea/eukaryote 完整算法的前提下，若未来要新增 `organism_type`（例如 `archaea`、`fungi`、或实验性类型），按本清单交付。

当前生产已冻结：

- `virus` → `strategies/virus/`
- `bacteria` → `strategies/bacteria/`

新类型必须以**新目录 + 新 Strategy** 接入，复用 `engine/` 与 `core/result_writer.R` 契约。

---

## 2. 需要新增的文件

以类型名 `newt`（示例）为例：

```text
r-analysis/
├── strategies/newt/
│   ├── newt_strategy.R          # 必须：create_newt_strategy()
│   ├── newt_annotation.R        # 必须：字段映射 / rings / tip 列
│   └── newt_visualization.R     # 推荐：类型专用环图（或明确复用 legacy ggtree）
├── metadata/
│   └── （更新）metadata_schema.md 中 newt 扩展列
│   └── （更新）metadata_validator.R TYPE_EXTRA_COLUMNS$newt
├── input/templates/
│   └── newt_metadata.csv        # 必须：表头模板
├── config/
│   └── analysis_config.yaml     # 必须：strategies.newt 段
├── test-data/newt/
│   ├── valid/                   # FASTA + metadata 对齐
│   ├── invalid_metadata/        # 缺必需列
│   └── tip_mismatch/            # sample_id 与 tip 不对齐
└── docs/（可选）
    └── newt_notes.md
```

### 2.1 `newt_strategy.R`（必须）

实现 `PhyloAnalysisStrategy`：

| 方法 | 要求 |
|------|------|
| `validate_input` | FASTA 存在；类型专属序列规则 |
| `parse_metadata` | 读 CSV；调用统一 validator（可 `strict=TRUE`） |
| `tree_params` | 声明 method/model；**建树委托** `invoke_legacy_tree_engine()` 或未来公共接口 |
| `annotation_config` | 调 `newt_annotation_config()` |
| `output_spec` | 通常 `default_output_spec("newt")` |
| `run` | 编排；失败必须 `write_error_analysis_result` |

工厂名约定：`create_newt_strategy`。

### 2.2 `newt_annotation.R`（必须）

- 扩展列常量
- `newt_annotation_config(ctx)` → rings / column_map / tip_id_column
- `map_newt_metadata_for_viz(meta)` → 可视化所需列（至少含 tip 对齐列，如 `label`）

### 2.3 `newt_visualization.R`（推荐）

- 独立 CLI：`Rscript newt_visualization.R <tree> <metadata> <output_dir>`
- 产出约定文件名：`circular_tree_final.png`（与 `default_output_spec` 一致）
- **禁止**修改 `engine/ggtree_visualization.R` 来迁就新类型

若短期复用 virus ggtree：在 strategy 内调用 `invoke_legacy_ggtree_viz()`，并保证 metadata 已映射为 `label,Country,Year` 兼容列；在 annotation 中注明“过渡复用”。

### 2.4 Metadata schema

在 `metadata/metadata_schema.md` 增加：

| 字段 | 说明 |
|------|------|
| 核心 | 仍为 `sample_id` + `organism_type` |
| 公共可选 | `collection_date` / `location` / `host` |
| newt 扩展 | 类型专属列（文档 + validator 同步） |

模板：`input/templates/newt_metadata.csv`（仅表头即可）。

### 2.5 Config

`config/analysis_config.yaml`：

```yaml
strategies:
  newt:
    enabled: true
    status: "production_via_legacy_engine"   # 或实验状态字符串
    tree:
      method: "Maximum Likelihood"
      model: "JC69"
    annotation:
      rings: ["..."]
```

### 2.6 测试夹具（最低集）

| 目录 | 期望 |
|------|------|
| `test-data/newt/valid/` | exit 0；`status` ∈ {success, partial} |
| `test-data/newt/invalid_metadata/` | exit 1；`status=error`；有 `error_message` |
| `test-data/newt/tip_mismatch/` | exit 1；`status=error`；消息含 tip 不匹配 |

并入回归：扩展 `scripts/runners/run_framework_regression.R`（或类型专用 runner）。

---

## 3. 注册步骤（当前实现下必需的“触碰面”）

v0.1 registry 为硬编码 `switch`。新增类型时**当前必须**改：

| 文件 | 改动 |
|------|------|
| `strategies/strategy_registry.R` | 增加路径 + `create_*_strategy` |
| `core/strategy_base.R` | `PHYLO_ORGANISM_TYPES` 增加 `"newt"` |
| `metadata/metadata_validator.R` | `TYPE_EXTRA_COLUMNS$newt` |
| `core/tree_builder.R` / `distance.R` / `visualization.R` | （现状）`default_*_params` 增加分支；Hardening 后应改为可选 |

> Hardening 目标：未来改为 `register_strategy("newt", factory)`，使上表 core 改动降到 0–1 处。在完成插件注册前，按上表操作。

**不要**为新类型修改：

- `engine/**`
- `strategies/virus/**`
- `strategies/bacteria/**`（除非修严重跨类型 bug，且先报告）

---

## 4. 禁止修改清单（冻结）

| 路径 | 原因 |
|------|------|
| `engine/phylogenetic_tree.R` | 生产建树算法冻结 |
| `engine/ggtree_visualization.R` | Virus 生产可视化冻结 |
| `engine/add_bootstrap_labels_only.R` 等 | 基准/工具链稳定 |
| `strategies/virus/` | 已验证生产 Strategy；扩展用新目录 |
| `strategies/bacteria/` | 同上 |
| `core/result_writer.R` 的**契约字段语义** | 破坏 v0.1 JSON 契约需升版；bugfix 除外 |
| Spring Boot / 前端（本仓库阶段约定） | 另立迁移任务 |

`core/` 允许在 Hardening 中**增加**共享辅助（错误包装、tip 校验），但：

- 禁止把某类型专属生物学规则写进 core 默认路径
- 禁止改写委托到 engine 的算法语义

---

## 5. 输出契约（所有新类型必须遵守）

见 [`analysis_result_contract.md`](analysis_result_contract.md)。

最低要求：

```json
{
  "status": "success|partial|error|not_implemented",
  "organism_type": "newt",
  "input": "",
  "tree": "",
  "visualization": "",
  "metadata": "",
  "statistics": {},
  "error_message": ""
}
```

失败：`status=error`，`error_message` 非空，进程 exit `1`，且必须落盘 `analysis_result.json`。

---

## 6. 推荐实现顺序

1. 写 schema + template + validator 条目  
2. 写 `newt_annotation.R`  
3. 写 `newt_strategy.R`（先 `not_implemented` 也可，但接入生产前必须完整 `run`）  
4. 注册 + config  
5. 夹具 + 回归三案  
6. （可选）`newt_visualization.R`  
7. 更新 `framework_test_matrix.md`

---

## 7. 验收清单

- [ ] 仅新增 `strategies/newt/`（及 schema/config/test），未改 virus/bacteria/engine 算法  
- [ ] `Rscript runners/run_analysis.R --type newt ...` 可分发  
- [ ] valid / invalid_metadata / tip_mismatch 行为符合契约  
- [ ] 失败必有 `analysis_result.json`  
- [ ] 文档与 `TYPE_EXTRA_COLUMNS` 一致  

---

## 8. 明确不做

- 不为新类型复制 JC69 / MAFFT 实现进 strategy  
- 不在 `engine/ggtree_visualization.R` 增加 `if (type==...)`  
- 不把 Boot/前端切换绑进本指南的最小交付  
