# Framework Hardening v0.2 Report

> 日期：2026-07-24  
> 仓库：`r-analysis` Multi-Organism Framework

---

## 1. Goal

降低新增 organism 成本，提高生产稳定性：

- 抽取公共 Strategy 执行模板（错误处理 / 日志 / 输出目录）
- 统一 tip ↔ metadata 校验
- Runner 最高层异常兜底写 `analysis_result.json`
- 扩展回归矩阵
- 半自动 `register_strategy` 插件注册设计与落地

**禁止项（本阶段遵守）：** 不实现 archaea/eukaryote 生产管线；不改 `engine/`；不改变 virus/bacteria **成功路径输出语义**；不接 Spring Boot。

---

## 2. Modified Files

| file | change | reason |
|------|--------|--------|
| `core/`（见 New Files） | 新增 runner / tip 模块 | 公共横切能力 |
| `strategies/strategy_registry.R` | `register_strategy` + plugin 加载；去掉 type `switch` | 降低新类型注册成本 |
| `strategies/virus/virus_strategy.R` | 改用 `run_strategy_pipeline` + `assert_tips`；边缘预检 empty/DNA/too_few | 去重系统错误处理；对齐测试矩阵 |
| `strategies/bacteria/bacteria_strategy.R` | 同上（生物学校验逻辑保留） | 去重；tip 走公共模块 |
| `runners/run_analysis.R` | 最高层 tryCatch + `write_runner_error_json` | 参数/加载/权限失败仍落盘 JSON |
| `scripts/runners/run_framework_regression.R` | 扩至 13 案；输出 `framework_v02_regression` | v0.2 测试矩阵 |
| `scripts/prep/prepare_virus_regression_fixtures.R` | 增加 empty/too_few/illegal_dna | virus 新案夹具 |
| `docs/multi_organism_framework.md` | （可选交叉链接，若已更新） | 文档导航 |

---

## 3. New Files

| file | purpose |
|------|---------|
| `core/strategy_runner.R` | `run_strategy_pipeline` / `fail_with_error_json` |
| `core/tip_validator.R` | `assert_tip_match` |
| `docs/strategy_runner_design.md` | 执行模板设计 |
| `docs/plugin_registry_design.md` | 半自动注册设计 |
| `docs/framework_test_report_v0.2.md` | 测试报告 |
| `docs/framework_hardening_v0.2_report.md` | 本报告 |
| `test-data/virus/empty/` | empty fasta |
| `test-data/virus/too_few/` | 2 条序列 |
| `test-data/virus/illegal_dna/` | 含非法碱基 X |

---

## 4. Architecture Impact

| 区域 | 是否影响 | 说明 |
|------|----------|------|
| `engine/` | **否** | 未修改任何引擎算法脚本 |
| `virus` | **是（编排）** | 系统错误处理外提；valid 成功字段/status 规则不变；新增边缘预检 |
| `bacteria` | **是（编排）** | 同上；生物学校验/可视化逻辑保留 |
| `core/` | **是（增强）** | 新增 tip_validator、strategy_runner；registry 加载之 |
| Spring Boot / 前端 | **否** | 未接入 |

```text
run_analysis (兜底 JSON)
  → get_strategy (register_strategy / plugin.R)
    → strategy$run
      → run_strategy_pipeline
        → biology pipeline + helpers$assert_tips / helpers$fail
          → engine (unchanged)
```

---

## 5. Test Result

**Command:**

```bash
cd r-analysis
Rscript scripts/runners/run_framework_regression.R
```

| item | value |
|------|-------|
| suite exit code | **0** |
| result | **Passed 13 / 13** |
| summary | `output/tasks/framework_v02_regression/summary.json` |

详见 [`framework_test_report_v0.2.md`](framework_test_report_v0.2.md)。

---

## 6. Regression

### virus

| case | exit | status | notes |
|------|------|--------|-------|
| valid | 0 | success | PASS |
| invalid_fasta | 1 | error | PASS |
| metadata_mismatch | 1 | error | PASS |
| empty | 1 | error | PASS（新） |
| illegal_dna | 1 | error | PASS（新） |
| too_few | 1 | error | PASS（新） |

### bacteria

| case | exit | status | notes |
|------|------|--------|-------|
| valid | 0 | success | PASS |
| invalid_metadata | 1 | error | PASS |
| tip_mismatch | 1 | error | PASS |
| empty | 1 | error | PASS（新） |
| illegal_dna | 1 | error | PASS（新） |
| too_few | 1 | error | PASS（新） |

### not_implemented

| case | exit | status | notes |
|------|------|--------|-------|
| archaea | 2 | not_implemented | PASS（仅 stub，未实现管线） |

---

## 7. Generated Docs

- `docs/strategy_runner_design.md`
- `docs/plugin_registry_design.md`
- `docs/framework_test_report_v0.2.md`
- `docs/framework_hardening_v0.2_report.md`（本文件）

相关既有文档：`analysis_result_contract.md`、`framework_architecture_audit.md`、`new_organism_development_guide.md`、`error_handling_audit.md`、`framework_test_matrix.md`。

---

## 8. Remaining Risk

| ID | risk | level |
|----|------|-------|
| R1 | `PHYLO_ORGANISM_TYPES` / `TYPE_EXTRA_COLUMNS` / `default_*_params` 仍硬编码 | 中 |
| R2 | virus/bacteria 仍各有一份 `read_fasta_records`（可再抽 fasta_io） | 低 |
| R3 | virus 新增边缘预检改变「以前可能进 engine 的坏输入」行为 | 低（有意 hardening） |
| R4 | runner 在 `--output` 缺失时无法写 JSON | 低（CLI 契约要求必填） |
| R5 | `plugin.R` 误注册覆盖需纪律（默认 overwrite=FALSE） | 低 |
| R6 | archaea/eukaryote 仍为 stub | 预期 |

---

## 9. Next Recommendation

1. 将 `PHYLO_ORGANISM_TYPES` / metadata extras / default params 改为「注册时声明」或配置驱动  
2. 抽取共享 `fasta_io`（消 virus/bacteria 读入重复）  
3. Boot 旁路接入 `run_analysis.R`（另立任务）  
4. 用真实 `strategies/fungi/plugin.R` 做一次注册演练（不必实现完整生物学）  
5. **仍不要**急于实现 archaea/eukaryote 生产管线
