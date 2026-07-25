# Multi-Organism Framework v0.1 — analysis_result.json 生产契约（冻结）
>
> 版本：`v0.1-freeze`  
> 日期：2026-07-24  
> 范围：`virus` / `bacteria` 统一生产契约；`archaea` / `eukaryote` 仅 `not_implemented`  
> 约束：**不修改** `engine/phylogenetic_tree.R`、`engine/ggtree_visualization.R`

---

## 1. 审计摘要（冻结前字段差异）

对仓库内现有 `analysis_result.json`（legacy engine / virus strategy / bacteria strategy）抽样审计如下。

### 1.1 Legacy engine（`engine/phylogenetic_tree.R` 直出）

代表文件：

- `output/benchmarks/h3n2_ha/analysis_result.json`
- `archive/2026-07-24/output/root_run/analysis_result.json`
- `output/tasks/migration_verify/analysis_result.json`
- `output/tasks/example/analysis_result.json`（失败样例）

| 字段 | 出现情况 | 说明 |
|------|----------|------|
| `status` | 有 | 成功=`success`；失败=`failed`（**非**冻结枚举 `error`） |
| `input` | 有 | FASTA 基名 |
| `sequence_count` | 有 | 顶层标量 |
| `method` / `model` | 有 | 顶层标量 |
| `tree_file` | 有 | 通常 `tree.nwk` |
| `matrix_file` / `image_file` | 有 | 距离矩阵 / 矩形树图 |
| `bootstrap` | 偶发 | 部分跑次 |
| `organism_type` | **无** | |
| `tree` | **无** | 仅有 `tree_file` |
| `visualization` | **无** | |
| `metadata` | **无** | |
| `statistics` | **无** | 统计散落在顶层 |
| `error_message` | **无** | 失败也不写 |

### 1.2 Virus strategy（`runners/run_analysis.R --type virus`）

代表文件：`output/tasks/bacteria_validation/virus_smoke/analysis_result.json`

| 字段 | 出现情况 | 说明 |
|------|----------|------|
| `status` | 有 | `success` /（设计）`partial` / `error` |
| `organism_type` | 有 | `virus` |
| `input` | 有 | |
| `tree_file` | 有 | 兼容别名 |
| `tree` | **审计时缺失**（旧产物） | 冻结后必须写出 |
| `visualization` | 有 | 可为空串 |
| `metadata` | 有 | 可为空串 |
| `statistics` | 有 | object |
| `error_message` | **审计时缺失**（旧成功产物） | 冻结后必须存在（成功为空串） |
| legacy 顶层 | `sequence_count`/`method`/`model`/`matrix_file`/`image_file` | 过渡兼容，**非必填** |

### 1.3 Bacteria strategy（`--type bacteria`）

代表文件：

- 成功：`output/tasks/bacteria_16s_run/analysis_result.json`
- 错误（旧）：`output/tasks/bacteria_error_status_fix/missing_fields/analysis_result.json`

| 字段 | 成功产物 | 错误产物（冻结前） | 冻结要求 |
|------|----------|-------------------|----------|
| `status` | `success`/`partial` | `error` | 同左 |
| `organism_type` | 有 | 有 | 必须 |
| `input` | 有 | **常缺** | 必须（可为空串仅当无 fasta 上下文） |
| `tree` / `tree_file` | 仅 `tree_file` | 仅 `tree_file` | **`tree` 必须**；`tree_file` 作别名 |
| `visualization` | 有 | 有（常 `""`） | 必须 |
| `metadata` | 有 | 有 | 必须 |
| `statistics` | object | 偶发 `[]` | **必须为 JSON object** |
| `error_message` | **常缺** | 有 | 必须；非 error 为空串 |
| bacteria extras | `annotation_rings`/`taxonomy_level`… | — | 放 `statistics`，非顶层必填 |

### 1.4 差异结论

```text
legacy          → 字段最少；status=failed；无 organism / viz / metadata / statistics / error_message
virus（旧产物） → 接近统一，但缺 tree、error_message
bacteria（旧产物）→ 接近统一；error 路径曾缺 input/tree；statistics 曾序列化为 []
```

**冻结策略：** Strategy 层通过 `core/result_writer.R` 写出完整契约；legacy engine JSON 仅作中间产物，由 `upgrade_legacy_result()` 升级。**不改** engine 算法脚本。

---

## 2. 冻结契约（v0.1）

### 2.1 `status` 枚举（封闭）

| 值 | 含义 |
|----|------|
| `success` | 建树完成，且主可视化（若本类型要求）已产出 |
| `partial` | 建树完成，但可视化未产出或其它非致命缺失 |
| `error` | 分析失败（校验 / 建树 / tip 对齐等） |
| `not_implemented` | Strategy 尚未实现（archaea / eukaryote） |

禁止使用 legacy 的 `failed` 作为 Strategy 最终对外 `status`（升级时映射为 `error`）。

### 2.2 进程 exit code

| Exit | 条件 |
|------|------|
| `0` | `status` ∈ {`success`, `partial`} |
| `1` | `status` = `error`，或未捕获异常 |
| `2` | `status` = `not_implemented` |

入口：`runners/run_analysis.R`。

### 2.3 必须字段

最终 `analysis_result.json` **必须**包含以下键（值可为空串 / 空 object，但键不可缺）：

| 字段 | 类型 | 说明 |
|------|------|------|
| `status` | string | §2.1 枚举 |
| `organism_type` | string | `virus` \| `bacteria` \| `archaea` \| `eukaryote` |
| `input` | string | 输入 FASTA 基名 |
| `tree` | string | 树文件名，通常 `tree.nwk`；失败可为 `""` |
| `visualization` | string | 主可视化文件名，通常 `circular_tree_final.png`；无则为 `""` |
| `metadata` | string | 写出的 metadata 文件名，通常 `metadata.csv`；无则为 `""` |
| `statistics` | object | 统计与扩展信息；**禁止** JSON 数组 `[]` |
| `error_message` | string | `status=error` 时非空；其它状态必须为 `""` |

### 2.4 兼容别名（过渡，非必填）

为兼容现有 Java DTO / 旧产物，允许额外写出：

- `tree_file`（= `tree`）
- `sequence_count` / `method` / `model` / `matrix_file` / `image_file`（可同时出现在顶层与 `statistics`）

消费者应优先读取必须字段；别名仅作 fallback。

### 2.5 最小示例

成功：

```json
{
  "status": "success",
  "organism_type": "virus",
  "input": "sequences.fasta",
  "tree": "tree.nwk",
  "visualization": "circular_tree_final.png",
  "metadata": "metadata.csv",
  "statistics": {
    "sequence_count": 4,
    "method": "Maximum Likelihood",
    "model": "JC69"
  },
  "error_message": "",
  "tree_file": "tree.nwk"
}
```

失败（必须落盘，即使进程 exit=1）：

```json
{
  "status": "error",
  "organism_type": "bacteria",
  "input": "sequences.fasta",
  "tree": "tree.nwk",
  "visualization": "",
  "metadata": "metadata.csv",
  "statistics": {},
  "error_message": "BacteriaStrategy: metadata sample_id/label 与 tree tip 不匹配，缺失: ...",
  "tree_file": "tree.nwk"
}
```

未实现：

```json
{
  "status": "not_implemented",
  "organism_type": "archaea",
  "input": "",
  "tree": "",
  "visualization": "",
  "metadata": "",
  "statistics": {
    "message": "ArchaeaPhyloStrategy 仅完成接口骨架。"
  },
  "error_message": "",
  "tree_file": ""
}
```

---

## 3. 错误行为（virus ≡ bacteria）

1. 任意失败路径必须在 `--output` 目录写出 `analysis_result.json`。
2. `status` 必须为 `error`，且 `error_message` 非空。
3. 若 legacy engine 已写出 `status=success` 的中间 JSON，Strategy 必须**覆盖**为 `error`（禁止残留成功假象）。
4. 实现入口：`write_error_analysis_result()` / `fail_with_error_json()`（virus / bacteria strategy）。

---

## 4. 实现锚点

| 组件 | 路径 |
|------|------|
| 写出 / 升级 | `core/result_writer.R` |
| CLI exit 映射 | `runners/run_analysis.R` |
| Virus | `strategies/virus/virus_strategy.R` |
| Bacteria | `strategies/bacteria/bacteria_strategy.R` |
| 回归 | `scripts/runners/run_framework_regression.R` |

---

## 5. 变更规则

本文件为 **v0.1 冻结契约**。破坏性字段变更需升版（v0.2+）并同步回归测试与 Boot DTO。算法脚本（`engine/*` 建树/可视化）不在本契约修改范围内。
