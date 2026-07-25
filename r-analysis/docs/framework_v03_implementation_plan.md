# Framework v0.3 Implementation Plan

> 日期：2026-07-24  
> 状态：**待确认 — 确认前不修改任何代码**  
> 阶段：生产化架构强化（非新 organism 开发）

---

## 0. 约束（不可违反）

| 禁止项 | 说明 |
|--------|------|
| 不实现 archaea / eukaryote 生产管线 | stub 可保留；仅作 not_implemented / 插件扫描对象 |
| 不修改 `engine/` | 算法与可视化脚本冻结 |
| 不修改 H3N2 benchmark 数据与结果 | `data/benchmarks/h3n2_ha/`、`output/benchmarks/h3n2_ha/` |
| 不接 Spring Boot | 本阶段仅 R 框架 |
| 不改变 virus/bacteria **成功路径**输出协议 | 成功字段语义、文件名、status=success/partial 规则保持 |
| 允许 | 失败 JSON **增量**字段 `error_code`（成功路径可写 `error_code=""` 以保持字段齐全，不改变成功语义） |

---

## 1. 当前架构分析

### 1.1 已具备（v0.2）

```text
runners/run_analysis.R
  → strategies/strategy_registry.R
       register_builtin_strategies()   # 仍硬编码 virus/bacteria/archaea/eukaryote
       load_strategy_plugins()         # 扫描 strategies/*/plugin.R（可选）
  → strategy$run → core/strategy_runner.R
  → tip_validator / result_writer
  → engine/*（子进程，冻结）
```

### 1.2 与 v0.3 目标的差距

| 目标 | 现状 | 缺口 |
|------|------|------|
| 新类型只加 `plugin.R` | builtins 仍在 registry 硬编码；`TYPE_EXTRA_COLUMNS` / `PHYLO_ORGANISM_TYPES` / `default_*_params` 分散硬编码 | 插件声明不完整；validator/defaults 未接插件元数据 |
| 重复注册 → PLUGIN_ERROR | `register_strategy` 仅 `stop()` 字符串 | 无 `error_code`；未统一写入 error JSON 契约 |
| 未知 organism → exit 2 / not_implemented | 当前 `stop("未知 --type")` → runner exit **1** | 与 v0.3 要求（exit 2）不一致 |
| 公共 FASTA IO | virus/bacteria 各有 `read_fasta_records` | 需 `core/io/fasta_io.R` |
| 统一 `error_code` | JSON 仅有 `error_message` | 需扩展契约字段（失败必填；成功空串） |
| v0.3 测试矩阵 | `framework_v02_regression` 13 案 | 缺 taxonomy/environment missing、duplicate plugin、unknown organism |

### 1.3 阻碍点（需确认，不直接大重构）

**问题 A — 「未知 type」语义冲突**

- v0.1/v0.2 契约：`not_implemented` = Strategy 已注册但未实现（archaea stub）。
- v0.3 要求：未知 organism → exit 2 + `status=not_implemented`。
- 影响：未知 type 与 archaea stub **共用同一 status/exit**，消费者无法区分「未注册」vs「已注册未实现」。
- 建议（待确认）：
  - **方案 A1（按字面执行）**：未知 type 写 JSON `status=not_implemented` + `error_code=CONFIG_ERROR`（或 `PLUGIN_ERROR`）+ exit 2。
  - **方案 A2（更清晰）**：未知 type 用 `status=error` + `error_code=CONFIG_ERROR` + exit 1；仅 stub 用 not_implemented + exit 2。  
  - **本计划默认采用 A1**（遵从任务书）；若你更倾向 A2，请在确认时说明。

**问题 B — 成功路径是否允许新增 `error_code` 字段**

- 任务要求失败 JSON 含 `error_code`；成功协议「不改变」通常指语义，字段增空串一般可兼容。
- 建议：成功/partial 也写 `"error_code": ""`，避免消费者 optional 分支；**不改变**既有字段含义与文件产出。
- 若严格禁止成功 JSON 出现新键：仅在 error / not_implemented 写入 `error_code`。请确认。

**问题 C — virus/bacteria 是否改为 plugin.R 声明（推荐）**

- 为达到「新增类型不改 registry」，builtins 应从 `register_builtin_strategies()` 迁到：
  - `strategies/virus/plugin.R`
  - `strategies/bacteria/plugin.R`
  - `strategies/archaea/plugin.R`（stub 元数据）
  - `strategies/eukaryote/plugin.R`（stub）
- registry 只保留：扫描 `strategies/*/plugin.R` → `register_strategy_plugin(manifest)`。
- **风险**：改动 virus/bacteria 加载路径；需用全量回归证明成功路径不变。
- **不**把生物学逻辑搬进 plugin；plugin 仅声明元数据 + 指向既有 strategy 工厂。

**问题 D — `analysis_config.yaml` 是否仍要手改**

- 任务写「只允许新增 plugin.R」。配置中的 `strategies.<type>` 默认参数理想由 plugin `tree_params` 提供；yaml 保留作覆盖层（可选）。
- 建议：新类型可不改 yaml；virus/bacteria yaml 保留以不扰动现网默认值。

---

## 2. 准备修改 / 新增文件

### 2.1 新增

| 路径 | 作用 |
|------|------|
| `core/io/fasta_io.R` | `read_fasta_records()` 等统一 FASTA 读取 |
| `core/io/metadata_io.R` | 统一读 CSV / 列存在性辅助（薄封装） |
| `core/error_model.R` | `error_code` 枚举、`make_framework_error()`、写 JSON 辅助 |
| `strategies/virus/plugin.R` | virus 插件清单 |
| `strategies/bacteria/plugin.R` | bacteria 插件清单 |
| `strategies/archaea/plugin.R` | stub 插件（not_implemented） |
| `strategies/eukaryote/plugin.R` | stub 插件 |
| `scripts/runners/run_framework_v03_regression.R` | v0.3 回归 |
| `test-data/...`（按需） | metadata missing / taxonomy missing / environment missing；duplicate plugin 夹具 |
| `docs/framework_v03_report.md` | 工程报告（实施后） |
| `docs/analysis_result_contract.md` | 增量：`error_code`（实施时更新） |

### 2.2 修改（计划）

| 路径 | 改动要点 |
|------|----------|
| `strategies/strategy_registry.R` | 移除 builtins 硬编码列表；全量扫描 plugin；重复注册 → PLUGIN_ERROR；未知 type → not_implemented + exit 2 路径 |
| `runners/run_analysis.R` | 未知 type / 插件错误映射 exit；兜底 JSON 带 `error_code` |
| `core/result_writer.R` | 增加 `error_code` 字段；statistics 强制 object |
| `core/strategy_runner.R` | `fail` 支持 `error_code` |
| `core/tip_validator.R` / 调用方 | tip 失败映射 `TIP_MISMATCH` |
| `metadata/metadata_validator.R` | 从插件注册表取 extras，而非仅硬编码 `TYPE_EXTRA_COLUMNS`（保留 fallback） |
| `core/strategy_base.R` | `PHYLO_ORGANISM_TYPES` 改为「已注册类型」查询或放宽校验 |
| `core/tree_builder.R` / `distance.R` / `visualization.R` | `default_*_params` 优先读插件声明，硬编码作 fallback |
| `strategies/virus/virus_strategy.R` | 改用 `core/io/fasta_io.R`；失败带 `error_code`；**不改**成功组装逻辑 |
| `strategies/bacteria/bacteria_strategy.R` | 同上 |
| `docs/new_organism_development_guide.md` | 改为「仅 plugin.R + strategy 文件」 |

### 2.3 明确不改

- `engine/**`
- H3N2 benchmark 输入/输出
- Spring Boot / 前端
- archaea/eukaryote **算法实现**（仅 plugin 元数据 / stub）

---

## 3. 分阶段实施（小步 + 每步测试）

| 阶段 | 内容 | 测试门槛 |
|------|------|----------|
| **P0** | 本计划文档（当前） | 人工确认 |
| **P1** | `core/error_model.R` + `result_writer` 增加 `error_code`（成功写 `""`） | 跑现有 v0.2 回归：13/13；抽查 success JSON 多一个空 `error_code` |
| **P2** | `core/io/fasta_io.R` + `metadata_io.R`；virus/bacteria 改调用 | v0.2 回归 + 可选 H3N2 virus valid 冒烟（不改 benchmark 产物目录） |
| **P3** | 真插件化：四类型 `plugin.R`；registry 只扫描；重复注册失败 | 新增 duplicate / unknown 单测；旧回归仍过 |
| **P4** | validator / defaults 读插件元数据 | bacteria metadata 相关案 |
| **P5** | `framework_v03_regression` 全矩阵 + `summary.json` | 全案 PASS |
| **P6** | `docs/framework_v03_report.md` + 更新契约/指南 | 文档与聊天报告一致 |

每阶段结束输出：命令、exit code、通过/失败数。失败则停止并报告，不进入下一阶段。

---

## 4. 修改风险

| 风险 | 等级 | 缓解 |
|------|------|------|
| virus/bacteria 加载路径改为 plugin 导致工厂找不到 | 高 | plugin 显式 `strategy_file` + factory 名；P3 后立即跑全回归 |
| `error_code` 被 Boot 旧 DTO 拒绝 | 中 | 本阶段不接 Boot；字段为增量；成功可为空串 |
| 未知 type exit 从 1→2 改变外部脚本假设 | 中 | 文档标明；仅框架 CLI |
| FASTA IO 抽取改变 tip 字符串 | 高 | 字节级对比 tip label；禁止改 header 解析规则 |
| 重复扫描 plugin 在同一进程二次 `get_strategy` | 中 | registry 清空/幂等：同 manifest 同 type 视为已加载，**不同文件重复 type** 才 PLUGIN_ERROR |
| bacteria 新案 taxonomy/environment missing 与现有 `assert_bacteria_metadata_columns` 行为需对齐 | 中 | 先写夹具期望再改校验；不放宽 valid 路径 |

---

## 5. 测试方案

### 5.1 回归套件

**保留：** `run_framework_regression.R`（v0.2）作为兼容冒烟。  

**新增：** `scripts/runners/run_framework_v03_regression.R` → `output/tasks/framework_v03_regression/summary.json`

| 组 | case | 期望 |
|----|------|------|
| virus | valid | exit 0；success/partial |
| virus | empty fasta | exit 1；INPUT_ERROR |
| virus | illegal dna | exit 1；INPUT_ERROR |
| virus | metadata missing（缺扩展列或强制列，按最终规则） | exit 1；METADATA_ERROR |
| virus | tip mismatch | exit 1；TIP_MISMATCH |
| bacteria | valid | exit 0 |
| bacteria | metadata missing（如缺 resistance） | exit 1；METADATA_ERROR |
| bacteria | taxonomy missing | exit 1；METADATA_ERROR |
| bacteria | environment missing | exit 1；METADATA_ERROR |
| bacteria | tip mismatch | exit 1；TIP_MISMATCH |
| plugin | duplicate plugin | exit 1；PLUGIN_ERROR；message 含 duplicate |
| plugin | unknown organism | exit **2**；not_implemented（若确认 A1） |

### 5.2 成功路径不变证明

- virus valid / bacteria valid：对比 `tree.nwk` tip 集合、`status`、关键产物文件名与 v0.2 跑次一致（允许 JSON 多 `error_code:""`）。
- **不**重写 `output/benchmarks/h3n2_ha/`。

### 5.3 Duplicate plugin 测法

- 测试专用目录或临时复制第二份 `plugin.R` 注册同名 type；或 regression 内 `source` 两次冲突 manifest。
- 不污染生产 `strategies/virus/plugin.R`。

---

## 6. 回滚方案

| 级别 | 动作 |
|------|------|
| 单阶段失败 | `git checkout --` 该阶段改动文件；保留计划文档 |
| P3 插件化失败 | 恢复 `register_builtin_strategies()`；删除新 plugin.R 或改为 no-op |
| FASTA IO 导致 tip 变化 | 立即回滚 `core/io` 与 strategy 引用；恢复内联 `read_fasta_records` |
| 全量回滚 | 回退到 v0.2 标签/提交（hardening 完成态）；保留 `framework_v03_implementation_plan.md` |

回滚后验证：重跑 v0.2 回归 13/13。

---

## 7. 插件清单字段草案（确认后实现）

每个 `strategies/{organism}/plugin.R` 调用例如：

```r
register_strategy_plugin(list(
  organism_type = "virus",
  metadata_schema = list(
    required_core = c("sample_id", "organism_type"),
    extras = c("segment", "variant"),
    strict_extras = FALSE
  ),
  validation_rule = list(min_sequences = 3L, alphabet = "dna_iupac"),
  tree_params = list(method = "Maximum Likelihood", model = "JC69"),
  visualization_handler = "engine/ggtree_visualization.R",  # or bacteria script
  strategy_class = "VirusPhyloStrategy",
  strategy_file = "virus/virus_strategy.R",
  factory = "create_virus_strategy",
  implemented = TRUE   # FALSE → not_implemented stub
))
```

---

## 8. 待你确认的问题（请回复后再编码）

1. **未知 organism**：采用 **A1**（exit 2 + `not_implemented`）还是 **A2**（exit 1 + `error` + CONFIG_ERROR）？  
2. **成功 JSON** 是否允许增加 `"error_code": ""`？  
3. **virus/bacteria** 是否同意迁到 `plugin.R`（推荐，否则「只加 plugin」目标不完整）？  
4. virus「metadata missing」具体指：缺 `--metadata`、缺文件、还是缺统一 schema 扩展列（当前 virus `strict=FALSE`）？  
5. 是否接受分阶段提交（P1→P6），每阶段跑测试再继续？

---

## 9. 确认后执行顺序（摘要）

```text
你确认本计划
  → P1 error_code
  → P2 fasta_io / metadata_io
  → P3 真插件扫描 + virus/bacteria plugin.R
  → P4 validator/defaults 接插件
  → P5 v0.3 回归
  → P6 framework_v03_report.md + 聊天 Engineering Report
```

**当前停在：等待确认。未修改任何业务代码。**
