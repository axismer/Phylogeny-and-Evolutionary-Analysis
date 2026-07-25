# Engineering Report

> Framework v0.3 Hardening — **P1 Error Contract**  
> 日期：2026-07-24  
> 状态：P1 完成；**停止，不进入 P2**（等待确认）

---

## 1. 本次目标

建立统一 error contract：

- `error`：必须含 `error_code` + `error_message`
- `not_implemented`：`error_code = UNSUPPORTED_ORGANISM`
- `success` / `partial`：**禁止**出现 `error_code` 键
- exit：`0` success/partial；`1` error；`2` not_implemented

---

## 2. 完成情况

| 任务 | 状态 | 文件 |
|------|------|------|
| 集中定义 error_code | ✅ | `core/error_codes.R` |
| result_writer 契约 | ✅ | `core/result_writer.R` |
| strategy_runner 传码 | ✅ | `core/strategy_runner.R` |
| virus 映射 | ✅ | `strategies/virus/virus_strategy.R` |
| bacteria 映射 | ✅ | `strategies/bacteria/bacteria_strategy.R` |
| 未知 organism → exit 2 | ✅ | `runners/run_analysis.R` |
| v0.2 回归 | ✅ 13/13 | `scripts/runners/run_framework_regression.R` |
| v0.3 P1 回归 | ✅ 5/5 | `scripts/runners/run_framework_v03_p1_regression.R` |
| P1 工程报告 | ✅ | `docs/framework_v03_p1_report.md` |

---

## 3. 修改文件

路径: `core/result_writer.R`  
原因: success/partial 剥离 `error_code`；error / not_implemented 写入码；新增 `write_not_implemented_result`

路径: `core/strategy_runner.R`  
原因: `fail` / tip 失败携带 `error_code`；捕获 `framework_error`

路径: `runners/run_analysis.R`  
原因: 未知 `--type` 写 `not_implemented` + `UNSUPPORTED_ORGANISM` + exit 2；兜底 JSON 带码

路径: `strategies/virus/virus_strategy.R`  
原因: 业务失败改 `raise_framework_error` / `helpers$fail(..., error_code=)`

路径: `strategies/bacteria/bacteria_strategy.R`  
原因: 同上；empty 消息兼容 v0.2 子串「至少需要 3」

---

## 4. 新增文件

路径: `core/error_codes.R`  
作用: 错误码常量、`raise_framework_error`、消息→码启发式映射

路径: `scripts/runners/run_framework_v03_p1_regression.R`  
作用: P1 契约回归（valid 无码、empty/tip/unknown）

路径: `docs/framework_v03_p1_report.md`  
作用: 本报告

路径: `output/tasks/framework_v03_p1_regression/`  
作用: P1 测试产物与 `summary.json`

---

## 5. 架构影响

engine:  
**否**（未修改）

virus:  
**是（错误路径）** — 校验/失败映射 error_code；**成功路径字段兼容**（无 error_code 键）

bacteria:  
**是（错误路径）** — 同上；成功路径兼容

core:  
**是** — error_codes + result_writer + strategy_runner

plugin registry:  
**否**（未修改；未知 type 在 runner 侧检测）

Spring Boot:  
**否**

frontend:  
**否**

---

## 6. 异常处理变化

旧方式:  
`stop("中文消息")` → tryCatch 写 JSON（仅 `error_message`）→ exit 1；未知 type 亦 exit 1

新方式:  
`raise_framework_error(code, msg)` 或 `helpers$fail(..., error_code=)`  
→ 写 `analysis_result.json`（error 含 `error_code`）  
→ success/partial **无** `error_code` 键  
→ 未知 organism：`not_implemented` + `UNSUPPORTED_ORGANISM` + exit **2**

error_code 列表:

- `EMPTY_FASTA`
- `INVALID_DNA`
- `TOO_FEW_SEQUENCE`
- `MISSING_METADATA_ARGUMENT`
- `METADATA_FILE_NOT_FOUND`
- `MISSING_METADATA_FIELDS`
- `TIP_METADATA_MISMATCH`
- `TREE_BUILD_FAILED`
- `VISUALIZATION_FAILED`
- `UNSUPPORTED_ORGANISM`

---

## 7. 测试

命令:

```bash
cd r-analysis
Rscript scripts/runners/run_framework_regression.R
Rscript scripts/runners/run_framework_v03_p1_regression.R
```

结果:

| 套件 | exit | 通过 | 失败 |
|------|------|------|------|
| framework_v02_regression | **0** | **13** | **0** |
| framework_v03_p1_regression | **0** | **5** | **0** |

P1 案验证:

| case | expect | 结果 |
|------|--------|------|
| virus valid | success；无 error_code | PASS |
| bacteria valid | success；无 error_code | PASS |
| empty fasta | error + EMPTY_FASTA | PASS |
| tip mismatch | error + TIP_METADATA_MISMATCH | PASS |
| unknown organism | not_implemented + exit 2 + UNSUPPORTED_ORGANISM | PASS |

---

## 8. 输出产物

JSON:

- `output/tasks/framework_v03_p1_regression/summary.json`
- 各 case 目录下 `analysis_result.json`

图片:  
无新增（本阶段未跑可视化基准刷新）

文档:

- `docs/framework_v03_p1_report.md`
- （既有）`docs/framework_v03_baseline_report.md`

---

## 9. 当前风险

高:  
无（P1 范围可控；双回归绿）

中:

- 部分「格式无效 FASTA」亦映射为 `EMPTY_FASTA`（码表无独立 INVALID_FASTA）
- 未知 type 与 archaea stub 同为 `not_implemented` + `UNSUPPORTED_ORGANISM`（靠 organism_type / 文案区分）
- `error_codes.R` 由 result_writer 自举加载（未改 registry）；P3 插件化时应正式列入 core 加载列表

低:

- 消息启发式兜底可能误映射；优先路径已用显式 `raise_framework_error`

---

## 10. Git diff摘要

修改:

- `core/result_writer.R` — error_code 契约
- `core/strategy_runner.R` — 传码 / 捕获
- `runners/run_analysis.R` — 未知 organism exit 2
- `strategies/virus/virus_strategy.R` — 框架错误
- `strategies/bacteria/bacteria_strategy.R` — 框架错误

新增:

- `core/error_codes.R`
- `scripts/runners/run_framework_v03_p1_regression.R`
- `docs/framework_v03_p1_report.md`
- `output/tasks/framework_v03_p1_regression/**`（测试产物）

删除:  
无

未改:  
`engine/`、`strategies/strategy_registry.R`、benchmark、Boot、前端

---

**P1 完成。请确认后再开始 P2（core IO 抽取）。**
