# Engineering Report

> Framework v0.3 Hardening — **P0 Baseline（实施前）**  
> 日期：2026-07-24  
> 状态：**待确认 — 本文件生成时未修改任何业务代码**  
> 关联：[`framework_v03_implementation_plan.md`](framework_v03_implementation_plan.md)

---

## 1. 本次目标

将 Virus + Bacteria 双 Strategy MVP **进一步工程化**，使未来新增 organism 时：

- **只增加** `strategies/{organism}/plugin.R` + strategy / annotation（及测试夹具）
- **不修改** registry 主逻辑、core 内 `if virus / if bacteria` 分支、engine、Boot、前端

本阶段（v0.3）分 P1–P6 小步执行；**P0 仅建基线，不改代码**。

硬约束：

| 禁止 | 必须保持 |
|------|----------|
| 改 `engine/` | virus success 输出字段兼容 |
| 改 H3N2 / bacteria benchmark 数据与结果 | bacteria success 输出字段兼容 |
| 改 Spring Boot / 前端 | v0.2 regression 全部通过后再前进 |
| 实现 archaea / eukaryote 生产管线 | 失败契约可增量 `error_code`（见下） |

**P1 错误契约（已按本轮指示锁定）：**

- `success` / `partial`：**不输出** `error_code` 键  
- `error`：必须含 `error_code` + `error_message`  
- `not_implemented`：`error_code = UNSUPPORTED_ORGANISM`（含未知 organism）  
- exit：`0` success/partial；`1` error；`2` not_implemented  

---

## 2. 当前架构状态

### 2.1 能力成熟度（v0.2 完成态）

| 组件 | 状态 |
|------|------|
| Virus Strategy | 生产可用（委托 legacy engine + ggtree） |
| Bacteria Strategy | 生产可用（委托 legacy engine + bacteria viz） |
| `core/strategy_runner.R` | 公共 tryCatch / error JSON / tip helper |
| `core/tip_validator.R` | 统一 tip 对齐 |
| `runners/run_analysis.R` | CLI + 顶层兜底 JSON |
| Plugin Registry | **初版**：有 `register_strategy` + 可选扫 `plugin.R`，但仍有 **builtins 硬编码** |
| Regression | `framework_v02_regression`：**13/13 PASS**（2026-07-24） |

### 2.2 调用链（现状）

```text
runners/run_analysis.R
  → strategy_registry.R
       register_builtin_strategies()     # 硬编码 virus/bacteria/archaea/eukaryote
       load_strategy_plugins()           # 扫 strategies/*/plugin.R（当前目录下尚无 plugin.R）
  → strategy$run
       → run_strategy_pipeline
       → invoke_legacy_tree_engine / viz
  → core/result_writer.R → analysis_result.json
  → engine/*（冻结，子进程）
```

### 2.3 与 v0.3 目标的差距

| 差距 | 说明 |
|------|------|
| G1 | registry 仍 `register_builtin_*`；无完整 plugin 声明（schema/tree/viz） |
| G2 | `metadata_validator.R` 硬编码 `TYPE_EXTRA_COLUMNS` |
| G3 | `default_tree_params` / `default_viz_params` / `default_distance_params` 按 organism `switch` |
| G4 | virus/bacteria 各有 `read_fasta_records` 重复实现 |
| G5 | 无统一 `error_code`；成功/失败 JSON 字段策略待按 P1 落地 |
| G6 | 未知 `--type` 当前多为 exit **1**；v0.3 要求 exit **2** + `not_implemented` |
| G7 | 尚无 fake organism 证明「不改 registry 可加载」 |

---

## 3. 修改前文件结构

```text
r-analysis/
├── engine/                          # ★ 禁止修改
│   ├── phylogenetic_tree.R
│   └── ggtree_visualization.R
├── core/
│   ├── strategy_base.R              # PHYLO_ORGANISM_TYPES 硬编码
│   ├── strategy_runner.R
│   ├── tip_validator.R
│   ├── result_writer.R              # 尚无 error_code 协议
│   ├── alignment.R / distance.R
│   ├── tree_builder.R               # default_* 按 type switch
│   └── visualization.R
├── metadata/
│   ├── metadata_validator.R         # TYPE_EXTRA_COLUMNS 硬编码
│   └── metadata_schema.md
├── strategies/
│   ├── strategy_registry.R          # builtins + 可选 plugin 扫描
│   ├── virus/   (strategy + annotation；无 plugin.R)
│   ├── bacteria/(strategy + annotation + visualization；无 plugin.R)
│   ├── archaea/ (stub)
│   └── eukaryote/(stub)
├── runners/run_analysis.R
├── config/analysis_config.yaml
├── scripts/runners/run_framework_regression.R   # v0.2
├── test-data/{virus,bacteria}/
├── output/tasks/framework_v02_regression/       # 基线测试产物
└── docs/  (含 v0.1/v0.2 报告与 v0.3 implementation_plan)
```

**基线测试锚点：**

- 命令：`Rscript scripts/runners/run_framework_regression.R`
- 结果：Passed **13 / 13**，exit **0**
- 摘要：`output/tasks/framework_v02_regression/summary.json`

---

## 4. 当前风险

### 高

- **插件化改加载路径**：virus/bacteria 迁 `plugin.R` 后若 factory/source 失败，生产入口直接不可用。  
  缓解：P3 后立刻跑 virus/bacteria valid + 全量 v0.2/v0.3 回归；可回滚至 builtins。

- **FASTA IO 抽取改变 tip label**：header 解析细微差别会导致 tip mismatch 假阳性。  
  缓解：P2 后对比 tip 集合；规则与现实现逐行对齐后再替换。

### 中

- **未知 organism 与 archaea stub 共用 `not_implemented` + exit 2**：消费者难区分「未注册」与「已注册未实现」。  
  缓解：用 `error_code`（未知 → `UNSUPPORTED_ORGANISM` / 或文档约定同一码）；本阶段按任务书执行。

- **success 不输出 `error_code`**：消费者需按 status 分支读字段（error 才有键）。  
  缓解：契约文档写清；回归断言 success JSON **不含** `error_code` 键。

- **core defaults / validator 去硬编码**：P4 若一次改太多易回归失败。  
  缓解：严格按 P 阶段；每阶段只动一类文件。

### 低

- fake plugin 残留污染生产扫描。缓解：放 `strategies/_fixtures_fake_*/` 或测试时临时目录 + 清理。  
- yaml 与 plugin `tree_config` 双源。缓解：yaml 仅覆盖；plugin 为声明默认。

---

## 5. 本阶段修改计划

| 阶段 | 内容 | 测试门槛 | 编码？ |
|------|------|----------|--------|
| **P0** | 本基线报告 | 人工确认 | **否（当前）** |
| **P1** | `core/error_codes.R` + result_writer / runner / strategy_runner 接协议 | v0.2 回归 13/13；success **无** error_code 键；error **有** error_code | 确认后 |
| **P2** | `core/fasta_io.R`、`core/metadata_io.R`；strategy 改调用 | virus valid + bacteria valid（及 v0.2 冒烟） | 确认后 |
| **P3** | `virus/plugin.R`、`bacteria/plugin.R`（+ stub）；registry 去 builtins switch；fake plugin 加载测试 | fake 可加载；旧回归通过 | 确认后 |
| **P4** | validator / defaults 读 plugin；core 禁止 `if virus/bacteria` | metadata 相关案 | 确认后 |
| **P5** | `framework_v03_regression` 全矩阵 + `summary.json` | 全案 PASS | 确认后 |
| **P6** | `docs/framework_hardening_v03_report.md` | 与聊天报告一致 | 确认后 |

**P1 error_code 枚举（按本轮指示）：**

`UNKNOWN_ORGANISM`, `EMPTY_FASTA`, `INVALID_DNA`, `TOO_FEW_SEQUENCE`, `MISSING_METADATA_ARGUMENT`, `METADATA_FILE_NOT_FOUND`, `MISSING_METADATA_FIELDS`, `TIP_METADATA_MISMATCH`, `TREE_BUILD_FAILED`, `VISUALIZATION_FAILED`，以及 not_implemented 用的 `UNSUPPORTED_ORGANISM`。

**P5 矩阵（按本轮指示）：**

- virus: valid / empty / illegal dna / metadata missing / tip mismatch  
- bacteria: valid / empty / illegal dna / metadata missing / tip mismatch  
- unknown: not_implemented  
- fake plugin: load success  

**明确不改：** `engine/`、H3N2/bacteria benchmark、Spring Boot、前端、archaea/eukaryote 算法实现。

---

## 6. 回滚方案

| 级别 | 动作 |
|------|------|
| 单阶段失败 | 还原该阶段改动文件；保留文档；重跑 v0.2 回归须 13/13 |
| P2 tip 漂移 | 回滚 `fasta_io`/`metadata_io` 与 strategy 引用；恢复内联读取 |
| P3 插件加载失败 | 临时恢复 `register_builtin_strategies()`；保留已写 plugin.R 作对照 |
| 全量回滚 | 回到 v0.2 Hardening 完成提交；保留本 baseline + implementation_plan |

回滚验证命令：

```bash
cd r-analysis
Rscript scripts/runners/run_framework_regression.R
# 期望：Passed 13/13，exit 0
```

---

## 确认清单（请回复后开始 P1）

请确认以下后，再进入编码：

1. **同意** success/partial **不输出** `error_code` 键（本轮 P1 规则）。  
2. **同意** 未知 organism → exit **2** + `status=not_implemented` + `error_code=UNSUPPORTED_ORGANISM`（或 `UNKNOWN_ORGANISM`，实现时二选一并写进契约）。  
3. **同意** virus/bacteria 迁入 `plugin.R`，registry 只扫描、去掉 builtins 硬编码列表。  
4. **同意** 按 P1→P6 小步：每阶段改代码 → 跑测试 → 阶段小结 → 再继续。  
5. **同意** 不改 engine / benchmark / Boot / 前端。

**当前停在 P0。未修改任何业务代码。** 回复「确认，开始 P1」或提出修订即可。
