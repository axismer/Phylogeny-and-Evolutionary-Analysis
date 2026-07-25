# Engineering Report

> Framework v0.3 Hardening — **P5 Fungi Plugin Validation**  
> 日期：2026-07-24  
> 状态：P5 完成；**停止，不进入下一阶段**

---

## 1. 本次目标

通过新增真实 production organism **fungi（ITS DNA）** 验证 plugin 架构：

- 仅新增 `strategies/fungi/`
- **不改** registry / core / runner / virus / bacteria / engine
- 错误统一 `raise_framework_error` + `analysis_result.json` 契约

---

## 2. 完成情况

| 任务 | 状态 | 文件 |
|------|------|------|
| fungi plugin（五函数，status=production） | ✅ | `strategies/fungi/plugin.R` |
| fungi strategy（ITS 校验 + legacy 建树） | ✅ | `strategies/fungi/fungi_strategy.R` |
| fungi annotation（taxonomy/host） | ✅ | `strategies/fungi/fungi_annotation.R` |
| fungi visualization（独立 circular） | ✅ | `strategies/fungi/fungi_visualization.R` |
| metadata 模板 | ✅ | `input/templates/fungi_metadata.csv` |
| 公开 ITS benchmark（40 条） | ✅ | `data/benchmarks/fungi_its/` |
| regression fixtures | ✅ | `test-data/fungi/` |
| P5 回归 | ✅ 7/7 | `scripts/runners/run_framework_v03_p5_regression.R` |
| contract audit（含 fungi） | ✅ 5/5 | `run_plugin_contract_audit.R` |
| 兼容回归 | ✅ | v02 13/13 · P1–P4 全绿 |
| P5 工程报告 | ✅ | `docs/framework_v03_p5_report.md` |

---

## 3. 修改文件

路径: `scripts/runners/run_plugin_contract_audit.R`  
原因: expected types 增加 `fungi`（production）

路径: `docs/organism_extension_guide.md`  
原因: 生产类型列表加入 fungi

路径: `docs/plugin_contract_audit_report.md`  
原因: 审计重跑产物（含 fungi）

**未修改：** `engine/**`、`strategies/virus/**`、`strategies/bacteria/**`、Spring Boot、frontend、H3N2 benchmark

---

## 4. 新增文件

路径: `strategies/fungi/plugin.R`  
作用: plugin 契约入口

路径: `strategies/fungi/fungi_strategy.R`  
作用: ITS 校验 / metadata / `invoke_legacy_tree_engine` / tip 校验 / 写出结果

路径: `strategies/fungi/fungi_annotation.R`  
作用: rings=taxonomy,host；`map_fungi_metadata_for_viz`

路径: `strategies/fungi/fungi_visualization.R`  
作用: 独立 circular PNG/PDF（不改 engine ggtree）

路径: `input/templates/fungi_metadata.csv`  
作用: fungi metadata 表头

路径: `data/benchmarks/fungi_its/*`  
作用: NCBI RefSeq ITS 公开数据（40 条）+ metadata + SOURCE

路径: `scripts/prep/prepare_fungi_its_benchmark.R` / `prepare_fungi_regression_fixtures.R`  
作用: 基准规范化与夹具生成

路径: `test-data/fungi/**`  
作用: valid/empty/illegal_dna/too_few/tip_mismatch

路径: `scripts/runners/run_framework_v03_p5_regression.R`  
作用: P5 回归

路径: `docs/framework_v03_p5_report.md`  
作用: 本报告

---

## 5. 架构影响

engine:  
**否**

virus:  
**否**

bacteria:  
**否**

Spring Boot:  
**否**

frontend:  
**否**

plugin registry:  
**自动发现** `strategies/fungi/plugin.R`（无需改 registry 源码）

---

## 6. 测试

命令:

```bash
cd r-analysis
Rscript scripts/runners/run_framework_v03_p5_regression.R
Rscript scripts/runners/run_plugin_contract_audit.R
# 兼容：
Rscript scripts/runners/run_framework_regression.R
Rscript scripts/runners/run_framework_v03_p1_regression.R
Rscript scripts/runners/run_framework_v03_p2_regression.R
Rscript scripts/runners/run_framework_v03_p3_regression.R
Rscript scripts/runners/run_framework_v03_p4_regression.R
# 基准冒烟：
Rscript runners/run_analysis.R --type fungi \
  --fasta data/benchmarks/fungi_its/fungi.fasta \
  --metadata data/benchmarks/fungi_its/metadata.csv \
  --output output/tasks/fungi_its_benchmark
```

结果:

| 套件 | 结果 |
|------|------|
| P5 | Passed **7 / 7** |
| contract audit | Passed **5 / 5**（含 fungi） |
| v0.2 | **13 / 13** |
| P1–P4 | **5/5 · 10/10 · 7/7 · 7/7** |
| fungi 40-seq benchmark | exit 0 · status=success · tip matched=40 |

通过:

- fungi_valid → exit 0 / success / 无 error_code
- empty → `EMPTY_FASTA`
- illegal_dna → `INVALID_DNA`
- too_few → `TOO_FEW_SEQUENCE`
- tip_mismatch → `TIP_METADATA_MISMATCH`
- unknown → exit 2 / `UNSUPPORTED_ORGANISM`
- plugin contract audit PASS

失败:

- 无

---

## 7. 输出产物

图片:

- `output/tasks/framework_v03_p5_regression/fungi_valid/circular_tree_final.png`
- `output/tasks/fungi_its_benchmark/circular_tree_final.png`（+ pdf）

JSON:

- `output/tasks/framework_v03_p5_regression/summary.json`
- 各 case `analysis_result.json`
- `output/tasks/fungi_its_benchmark/analysis_result.json`

文档:

- `docs/framework_v03_p5_report.md`
- `data/benchmarks/fungi_its/SOURCE.txt`
- `test-data/fungi/README.md`

---

## 8. 当前风险

高:  
无（P5 + 全兼容回归绿；40 tip 匹配）

中:

- fungi 不在 `PHYLO_ORGANISM_TYPES` 常量中（按设计仅靠 plugin；构造时可能 warning）
- host/substrate 为基准启发式标注，非文献金标准生态注释

低:

- ITS 长度/二级结构未做专门模型（第一版复用 JC69 legacy engine）

---

## 9. 下一步建议

1. 人工评审 fungi plugin 与 ITS 基准图  
2. 可选：将 `PHYLO_ORGANISM_TYPES` 改为纯文档或从 registry 派生（仍属清理，非必须）  
3. 可选：下一 organism 继续只加目录验证 OCP  
4. **本阶段停止**

---

## 10. Git diff摘要

新增:

- `strategies/fungi/**`
- `data/benchmarks/fungi_its/**`
- `test-data/fungi/**`
- `input/templates/fungi_metadata.csv`
- prep + P5 runners
- `docs/framework_v03_p5_report.md`

修改:

- `scripts/runners/run_plugin_contract_audit.R`（期望含 fungi）
- `docs/organism_extension_guide.md` / audit report 重生成

删除:

- 无

未改:

- `engine/**`
- `strategies/virus/**`
- `strategies/bacteria/**`
- Spring Boot / frontend / H3N2

---

**停止条件已满足：P5 完成，等待评审。**
