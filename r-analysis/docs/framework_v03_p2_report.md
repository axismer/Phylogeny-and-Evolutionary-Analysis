# Engineering Report

> Framework v0.3 Hardening — **P2 Core IO 抽取**  
> 日期：2026-07-24  
> 状态：P2 完成；**停止，不进入 P3**

---

## 1. 本次目标

抽取公共 IO 层，消除 virus/bacteria 重复的 FASTA/metadata/output 读写，且：

- FASTA 迁移前后 tip 语义不变（count / id 集合 / 顺序 / metadata 匹配）
- IO 层不含生物学规则（IUPAC、min seq、长度）
- 不覆盖 `metadata_validator.R::validate_metadata_file()`
- output 为薄包装，最终仍调用 `result_writer.R`
- 旧本地 `read_fasta_records` 保留为 deprecated fallback
- 跑通 v02 + P1 + P2 回归后停止

---

## 2. 完成情况

| 任务 | 状态 | 文件 |
|------|------|------|
| 公共 FASTA IO | ✅ | `core/io/fasta_io.R` |
| 公共 Metadata IO | ✅ | `core/io/metadata_io.R` |
| 公共 Output IO 薄包装 | ✅ | `core/io/output_io.R` |
| result_writer / strategy_runner 自举加载 io | ✅ | `core/result_writer.R`, `core/strategy_runner.R` |
| virus 改调 core/io + deprecated fallback | ✅ | `strategies/virus/virus_strategy.R` |
| bacteria 改调 core/io + deprecated fallback | ✅ | `strategies/bacteria/bacteria_strategy.R` |
| 不覆盖 `validate_metadata_file` | ✅ | 仍仅在 `metadata/metadata_validator.R` |
| v0.2 回归 | ✅ 13/13 | `scripts/runners/run_framework_regression.R` |
| v0.3 P1 回归 | ✅ 5/5 | `scripts/runners/run_framework_v03_p1_regression.R` |
| v0.3 P2 回归（含 tip parity） | ✅ 10/10 | `scripts/runners/run_framework_v03_p2_regression.R` |
| P2 工程报告 | ✅ | `docs/framework_v03_p2_report.md` |

---

## 3. 修改文件

路径: `core/result_writer.R`  
原因: 自举 `source` `core/io/{fasta,metadata,output}_io.R`（不改 registry）

路径: `core/strategy_runner.R`  
原因: 兜底自举 core/io，保证 pipeline 内 `read_fasta` / `write_analysis_output` 可用

路径: `strategies/virus/virus_strategy.R`  
原因: `validate_fasta_basic` + `read_fasta` + `read_metadata` + `write_analysis_output`；保留 `.read_fasta_records_deprecated`

路径: `strategies/bacteria/bacteria_strategy.R`  
原因: 同上；`require_metadata_argument` + bacteria 专属 empty 文案；IUPAC/长度/min=3 仍在 strategy

路径: `docs/framework_v03_p2_plan.md`  
原因: 状态改为已完成

---

## 4. 新增文件

路径: `core/io/fasta_io.R`  
作用: `read_fasta` / `validate_fasta_basic` / `write_fasta`（无 organism/IUPAC/min/长度规则）

路径: `core/io/metadata_io.R`  
作用: `read_metadata` / `require_metadata_argument` / `ensure_metadata_readable`（不做 schema）

路径: `core/io/output_io.R`  
作用: `write_analysis_output` → 委托 `write_analysis_result`；`safe_write_json` 通用薄写

路径: `scripts/runners/run_framework_v03_p2_regression.R`  
作用: P2 回归（tip/metadata parity + 6 条 pipeline case）

路径: `docs/framework_v03_p2_report.md`  
作用: 本报告

路径: `output/tasks/framework_v03_p2_regression/`  
作用: P2 测试产物与 `summary.json`

---

## 5. 架构影响

engine:  
**否**

virus:  
**是（IO 路径）** — 改调 core/io；成功字段兼容；生物学校验未搬迁

bacteria:  
**是（IO 路径）** — 同上；taxonomy / 长度启发式仍在 strategy

core:  
**是** — 新增 `core/io/*`；result_writer / strategy_runner 自举加载

registry:  
**否**（按确认：本阶段不改 `source_framework_core` 列表）

Spring Boot:  
**否**

frontend:  
**否**

---

## 6. 异常处理变化

旧:  
strategy 内联 `file.exists` / `readLines` / `utils::read.csv` / `write_analysis_result`；失败已用 `raise_framework_error`（P1）

新:  
路径/空文件/缺参经 `validate_fasta_basic` / `require_metadata_argument` / `read_metadata` 统一抛既有码（`EMPTY_FASTA`、`METADATA_FILE_NOT_FOUND`、`MISSING_METADATA_ARGUMENT`）；schema 仍走 validator；成功写出经 `write_analysis_output` → `write_analysis_result`（success 仍无 `error_code`）

---

## 7. 测试

命令:

```bash
cd r-analysis
Rscript scripts/runners/run_framework_regression.R
Rscript scripts/runners/run_framework_v03_p1_regression.R
Rscript scripts/runners/run_framework_v03_p2_regression.R
```

结果:

| 套件 | 结果 |
|------|------|
| v0.2 | Passed 13 / 13 |
| v0.3 P1 | Passed 5 / 5 |
| v0.3 P2 | Passed 10 / 10 |

通过:

- v02：virus/bacteria valid + 错误路径 + archaea not_implemented
- P1：error_code 契约（valid 无码、EMPTY_FASTA、TIP_METADATA_MISMATCH、UNSUPPORTED_ORGANISM）
- P2 tip parity：virus tip_count=4、bacteria tip_count=6；集合/顺序/序列一致
- P2 metadata read parity + valid tip match（virus 4 / bacteria 6）
- P2 pipeline：virus_valid / virus_bad_fasta / virus_missing_metadata / bacteria_valid / bacteria_bad_metadata / bacteria_missing_fasta

失败:

- 无

---

## 8. 输出产物

JSON:

- `output/tasks/framework_v02_regression/summary.json`
- `output/tasks/framework_v03_p1_regression/summary.json`
- `output/tasks/framework_v03_p2_regression/summary.json`
- 各 case 下 `analysis_result.json`

图片:

- valid case 下既有 `circular_tree_final.png` / `tree.png`（行为未改）

文档:

- `docs/framework_v03_p2_plan.md`（状态更新）
- `docs/framework_v03_p2_report.md`（本报告）

---

## 9. 当前风险

高:

- 无（本次 tip parity 与三套回归均绿）

中:

- 旧 `.read_fasta_records_deprecated` 仍双份存在于 virus/bacteria；清理前需再确认无外部依赖
- `validate_fasta_basic(require_header=)` 在 virus=`first` / bacteria=`none` 以保行为；若日后统一为 `any` 需单独回归

低:

- registry 尚未登记 `core/io`（靠自举）；P3 plugin 化时需纳入加载列表
- `safe_write_json` 目前无生产调用方（对称 API）

---

## 10. Git diff摘要

新增:

- `r-analysis/core/io/fasta_io.R`
- `r-analysis/core/io/metadata_io.R`
- `r-analysis/core/io/output_io.R`
- `r-analysis/scripts/runners/run_framework_v03_p2_regression.R`
- `r-analysis/docs/framework_v03_p2_report.md`

修改:

- `r-analysis/core/result_writer.R` — io 自举
- `r-analysis/core/strategy_runner.R` — io 兜底自举
- `r-analysis/strategies/virus/virus_strategy.R` — 改调 core/io + deprecated fallback
- `r-analysis/strategies/bacteria/bacteria_strategy.R` — 同上
- `r-analysis/docs/framework_v03_p2_plan.md` — 完成状态

未改:

- `engine/**`、benchmark 产物目录、Spring Boot、前端、`metadata_validator.R::validate_metadata_file`、registry 插件机制

---

## 11. Known Limitations

1. 旧本地 FASTA 解析函数未删除（按约束保留 deprecated fallback）；删除属后续清理，非 P2。
2. `core/io` 未进入 `source_framework_core()` 显式列表，依赖 result_writer/strategy_runner 自举。
3. archaea / eukaryote 未迁移到 core/io（仍为 stub / 未实现）。
4. 未进入 P3（plugin 注册硬化 / registry 显式加载 io）。
