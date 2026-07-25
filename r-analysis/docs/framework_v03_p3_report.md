# Engineering Report

> Framework v0.3 Hardening — **P3 Plugin Registry Refactor**  
> 日期：2026-07-24  
> 状态：P3 完成；**停止，不进入 P4**（等待人工评审）

---

## 1. 本次目标

将 organism 注册从 builtins 硬编码改为真正的插件发现：

- Plugin Contract（可校验）
- 扫描 `strategies/*/plugin.R`
- Dynamic Registry：`get_strategy(type)` 无 type `switch`
- defaults / schema：**plugin 优先，硬编码 fallback**
- **不**重写 virus/bacteria 业务 `run` 流程；成功 JSON 字段不变

---

## 2. 完成情况

| 任务 | 状态 | 文件 |
|------|------|------|
| Plugin Contract + validate | ✅ | `core/plugin_contract.R` |
| PLUGIN_* error codes | ✅ | `core/error_codes.R` |
| virus/bacteria/archaea/eukaryote plugin.R | ✅ | `strategies/*/plugin.R` |
| Registry discovery-only（去 builtins 硬编码） | ✅ | `strategies/strategy_registry.R` |
| Runner 改 discovery | ✅ | `runners/run_analysis.R` |
| defaults/schema plugin 优先 + fallback | ✅ | tree/distance/viz + metadata_validator + strategy_base |
| P3 回归 | ✅ 7/7 | `scripts/runners/run_framework_v03_p3_regression.R` |
| v02 / P1 / P2 兼容 | ✅ 13/13 · 5/5 · 10/10 | 既有 runners |
| P3 工程报告 | ✅ | `docs/framework_v03_p3_report.md` |

---

## 3. 修改文件

路径: `strategies/strategy_registry.R`  
原因: 删除 builtins 硬编码路径表；扫描 plugin；`get_strategy` 调 `plugin$get_strategy()`；修复 `scripts/runners` 下 `.get_framework_dirs`

路径: `runners/run_analysis.R`  
原因: 仅 `discover_and_register_plugins`；插件错误 → exit 1 + PLUGIN_*；usage 动态列出已注册 type

路径: `core/error_codes.R`  
原因: 新增 `PLUGIN_NOT_FOUND` / `PLUGIN_LOAD_FAILED` / `PLUGIN_CONTRACT_INVALID` / `PLUGIN_DUPLICATE_TYPE`

路径: `core/strategy_base.R`  
原因: `PHYLO_ORGANISM_TYPES` 保留作 fallback；新类型不再硬 stop（warn）

路径: `core/tree_builder.R` / `core/distance.R` / `core/visualization.R`  
原因: `default_*_params` 优先 `lookup_plugin_default_config`，否则旧 switch

路径: `metadata/metadata_validator.R`  
原因: `resolve_type_extra_columns` plugin schema 优先，`TYPE_EXTRA_COLUMNS` fallback

路径: `docs/framework_v03_p3_plan.md`  
原因: 状态改为已完成

---

## 4. 新增文件

路径: `core/plugin_contract.R`  
作用: 五函数契约 + `validate_plugin_contract` + manifest / lookup 辅助

路径: `strategies/virus/plugin.R`  
作用: 包装既有 `create_virus_strategy`（production）

路径: `strategies/bacteria/plugin.R`  
作用: 包装既有 `create_bacteria_strategy`（production）

路径: `strategies/archaea/plugin.R`  
作用: stub；`get_status()=stub`；不实现 pipeline

路径: `strategies/eukaryote/plugin.R`  
作用: stub；同上

路径: `scripts/runners/run_framework_v03_p3_regression.R`  
作用: discovery / contract / duplicate / valid / archaea stub / unknown

路径: `docs/framework_v03_p3_report.md`  
作用: 本报告

---

## 5. 架构影响

是否影响:

engine:  
**否**

virus:  
**仅加载路径**（经 plugin 包装）；`run` / 成功 JSON **未改**

bacteria:  
**同上**

core:  
**是** — contract、defaults 查询优先级、错误码

registry:  
**是** — discovery-only

Spring Boot:  
**否**

frontend:  
**否**

---

## 6. 异常处理变化

旧:  
`register_builtin_strategies` 硬编码四类型；未知 type → `UNSUPPORTED_ORGANISM` exit 2；无插件契约错误码

新:  
扫描 `plugin.R` → 契约校验 / 重复注册失败写 error JSON；未知 type 行为不变（exit 2）

新增 error_code:

- `PLUGIN_NOT_FOUND`
- `PLUGIN_LOAD_FAILED`
- `PLUGIN_CONTRACT_INVALID`
- `PLUGIN_DUPLICATE_TYPE`

---

## 7. 测试

命令:

```bash
cd r-analysis
Rscript scripts/runners/run_framework_regression.R
Rscript scripts/runners/run_framework_v03_p1_regression.R
Rscript scripts/runners/run_framework_v03_p2_regression.R
Rscript scripts/runners/run_framework_v03_p3_regression.R
```

结果:

| 套件 | 结果 |
|------|------|
| v0.2 | Passed **13 / 13** |
| v0.3 P1 | Passed **5 / 5** |
| v0.3 P2 | Passed **10 / 10** |
| v0.3 P3 | Passed **7 / 7** |

通过:

- plugin_discovery（四类型；virus/bacteria=production，archaea=stub）
- plugin_contract_invalid → `PLUGIN_CONTRACT_INVALID`
- plugin_duplicate_type → `PLUGIN_DUPLICATE_TYPE`
- virus/bacteria plugin valid（success，无 error_code）
- archaea stub / unknown → exit 2 + `UNSUPPORTED_ORGANISM`

失败:

- 无

---

## 8. 输出产物

图片:  
valid case 既有树图（行为未改）

JSON:

- `output/tasks/framework_v03_p3_regression/summary.json`
- 各 case `analysis_result.json`

文档:

- `docs/framework_v03_p3_plan.md`
- `docs/framework_v03_p3_report.md`

---

## 9. 当前风险

高:  
无（全回归绿；成功路径未改业务组装）

中:

- `default_*` / `TYPE_EXTRA_COLUMNS` 硬编码仍作 fallback；与 plugin 声明若日后漂移需对齐测试
- 新 organism 若忘记写 `plugin.R` 则不可发现（有意设计）

低:

- `register_builtin_strategies` 保留为 deprecated 警告空实现
- archaea/eukaryote stub 仍可被 CLI 调用并 exit 2

---

## 10. Git diff摘要

新增:

- `core/plugin_contract.R`
- `strategies/{virus,bacteria,archaea,eukaryote}/plugin.R`
- `scripts/runners/run_framework_v03_p3_regression.R`
- `docs/framework_v03_p3_report.md`

修改:

- `strategies/strategy_registry.R`
- `runners/run_analysis.R`
- `core/error_codes.R` / `strategy_base.R` / `tree_builder.R` / `distance.R` / `visualization.R`
- `metadata/metadata_validator.R`
- `docs/framework_v03_p3_plan.md`

删除:

- 无（builtins 函数改为 deprecated，未物理删除符号）

未改:

- `engine/**`
- H3N2 benchmark
- Spring Boot / frontend
- virus/bacteria `run` 业务组装逻辑

---

## 11. 下一步建议

1. 人工评审本报告与 `plugin.R` 契约是否满足产品预期  
2. 可选：更新 `docs/new_organism_development_guide.md` 为「只增目录 + plugin.R」  
3. P4（若需要）：彻底移除 defaults/schema 硬编码 fallback；validator 只读 plugin  
4. **本阶段停止，不进入 P4**

---

**停止条件已满足：P3 完成，等待人工评审。**
