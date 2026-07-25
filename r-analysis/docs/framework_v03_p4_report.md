# Engineering Report

> Framework v0.3 Hardening — **P4 Stabilization & Docs**  
> 日期：2026-07-24  
> 状态：P4 完成；**停止，等待评审**（不实现新 organism / 不进下一清理阶段）

---

## 1. 本次目标

框架稳定化与文档完善：

- 插件扩展规范
- error_code 参考
- deprecated 组件标注（**不删除** fallback）
- plugin contract audit
- 框架级 P4 回归

**不是**新增 organism；**禁止**实现 archaea/eukaryote pipeline。

---

## 2. 完成情况

| 任务 | 状态 | 文件 |
|------|------|------|
| 插件开发规范 | ✅ | `docs/organism_extension_guide.md` |
| error 文档 | ✅ | `docs/error_code_reference.md` |
| deprecated 清单 + 源码注释 | ✅ | `docs/deprecated_components.md` + 多处源码 |
| plugin contract audit | ✅ 4/4 | `scripts/runners/run_plugin_contract_audit.R` → `docs/plugin_contract_audit_report.md` |
| P4 回归 | ✅ 7/7 | `scripts/runners/run_framework_v03_p4_regression.R` |
| 兼容回归 | ✅ | v02 13/13 · P1 5/5 · P2 10/10 · P3 7/7 |
| P4 工程报告 | ✅ | `docs/framework_v03_p4_report.md` |

---

## 3. 修改文件

路径: `strategies/strategy_registry.R`  
原因: 强化 `register_builtin_strategies` deprecated 说明与迁移指引

路径: `strategies/virus/virus_strategy.R` / `strategies/bacteria/bacteria_strategy.R`  
原因: `.read_fasta_records_deprecated` 注释标明 P4 禁止删除 + 迁移计划

路径: `core/tree_builder.R` / `core/distance.R` / `core/visualization.R`  
原因: fallback `switch` 标注 deprecated（不删）

路径: `core/strategy_base.R`  
原因: `PHYLO_ORGANISM_TYPES` 标明 deprecated 兼容表

路径: `metadata/metadata_validator.R`  
原因: `TYPE_EXTRA_COLUMNS` 标明 deprecated fallback

路径: `docs/new_organism_development_guide.md`  
原因: 顶部指向新版 `organism_extension_guide.md`

---

## 4. 新增文件

路径: `docs/organism_extension_guide.md`  
作用: 新增 organism 七步流程（目录 → plugin → strategy → schema → annotation → fixtures → regression）

路径: `docs/error_code_reference.md`  
作用: 全部 error_code 的含义 / 触发 / exit / status

路径: `docs/deprecated_components.md`  
作用: builtins / FASTA 副本 / switch·表 fallback 的保留理由与未来迁移计划

路径: `docs/plugin_contract_audit_report.md`  
作用: 四 plugin 契约审计结果（由 audit runner 生成）

路径: `scripts/runners/run_plugin_contract_audit.R`  
作用: 契约审计入口

路径: `scripts/runners/run_framework_v03_p4_regression.R`  
作用: discovery / contract / invalid / duplicate / virus·bacteria pipeline / unknown

路径: `docs/framework_v03_p4_report.md`  
作用: 本报告

---

## 5. 架构影响

engine:  
**否**

virus:  
**否**（仅 deprecated 注释；`run` 未改）

bacteria:  
**否**（同上）

Spring Boot:  
**否**

frontend:  
**否**

---

## 6. 异常处理变化

无行为变化。仅文档化既有码表（含 P3 `PLUGIN_*`）。  
成功 JSON 字段不变；失败仍须 `error_code` + `error_message`。

---

## 7. 测试

命令:

```bash
cd r-analysis
Rscript scripts/runners/run_plugin_contract_audit.R
Rscript scripts/runners/run_framework_v03_p4_regression.R
Rscript scripts/runners/run_framework_v03_p3_regression.R
Rscript scripts/runners/run_framework_regression.R
Rscript scripts/runners/run_framework_v03_p1_regression.R
Rscript scripts/runners/run_framework_v03_p2_regression.R
```

结果:

| 套件 | 结果 |
|------|------|
| plugin contract audit | Passed **4 / 4** |
| v0.3 P4 | Passed **7 / 7** |
| v0.3 P3 | Passed **7 / 7** |
| v0.2 | Passed **13 / 13** |
| v0.3 P1 | Passed **5 / 5** |
| v0.3 P2 | Passed **10 / 10** |

通过:

- 四 plugin discovery + contract VALID（virus/bacteria=production，archaea/eukaryote=stub）
- invalid → `PLUGIN_CONTRACT_INVALID`；duplicate → `PLUGIN_DUPLICATE_TYPE`
- virus/bacteria pipeline success（无 error_code）；unknown → exit 2

失败:

- 无

---

## 8. 输出产物

JSON:

- `output/tasks/framework_v03_p4_regression/summary.json`
- `output/tasks/plugin_contract_audit/summary.json`

图片:

- 无新增（pipeline 复用既有 valid 夹具产物）

文档:

- `docs/organism_extension_guide.md`
- `docs/error_code_reference.md`
- `docs/deprecated_components.md`
- `docs/plugin_contract_audit_report.md`
- `docs/framework_v03_p4_report.md`

---

## 9. 当前风险

高:  
无

中:

- plugin 声明与 deprecated fallback 若日后漂移，依赖 audit 捕获（本轮已对齐）
- 旧 `new_organism_development_guide.md` 仍含历史步骤，读者需看顶部指引

低:

- deprecated 符号仍在代码中（按 P4 故意保留）

---

## 10. Git diff摘要

新增:

- `docs/organism_extension_guide.md`
- `docs/error_code_reference.md`
- `docs/deprecated_components.md`
- `docs/plugin_contract_audit_report.md`
- `docs/framework_v03_p4_report.md`
- `scripts/runners/run_plugin_contract_audit.R`
- `scripts/runners/run_framework_v03_p4_regression.R`

修改:

- deprecated 注释：registry / virus·bacteria strategy / tree·distance·viz / strategy_base / metadata_validator
- `docs/new_organism_development_guide.md`（指向新指南）

删除:

- 无（明确未删任何 fallback）

未改:

- `engine/**`
- H3N2 benchmark
- Spring Boot / frontend
- virus/bacteria `run` 业务组装
- 成功 JSON 字段语义

---

## 11. 下一步建议

1. 人工评审 P4 文档与 audit 报告  
2. 可选：在 README 增加 v0.3 文档索引（extension / error / deprecated）  
3. 清理窗口（非本阶段）：删除 builtins 空函数、FASTA 本地副本、硬编码 switch——须单独评审 + 全回归  
4. **不**在本阶段实现 archaea/eukaryote 生产管线  

---

**停止条件已满足：P4 完成，等待评审。**
