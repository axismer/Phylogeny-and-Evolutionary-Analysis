# Multi-Organism Framework v0.1 冻结报告

> 日期：2026-07-24  
> 范围：统一 **virus** 与 **bacteria** 生产契约；**不实现** archaea / eukaryote；**不修改** Spring Boot / 前端；**不修改** `engine/phylogenetic_tree.R`、`engine/ggtree_visualization.R`

相关文档：

- [`docs/analysis_result_contract.md`](analysis_result_contract.md) — 冻结 JSON / status / exit code
- [`docs/multi_organism_framework.md`](multi_organism_framework.md) — 框架设计总览

---

## 1. 当前架构

```text
runners/run_analysis.R          # 统一 CLI（--type / --fasta / --metadata / --output）
        │
        ▼
strategies/strategy_registry.R  # get_strategy(type)
        │
        ├─ virus/virus_strategy.R      # 生产：委托 legacy engine + ggtree
        ├─ bacteria/bacteria_strategy.R # 生产：委托 legacy engine + bacteria viz
        ├─ archaea/*                   # 骨架 → not_implemented (exit 2)
        └─ eukaryote/*                 # 骨架 → not_implemented (exit 2)
        │
        ▼
core/
  strategy_base.R               # PhyloAnalysisStrategy 契约
  tree_builder.R / visualization.R
  result_writer.R               # analysis_result.json v0.1 写出 / 升级
        │
        ▼
engine/                         # ★ 冻结算法（本阶段禁止改写）
  phylogenetic_tree.R
  ggtree_visualization.R
```

双入口并存：

| 入口 | 用途 |
|------|------|
| `engine/phylogenetic_tree.R` | 现有 Spring Boot 配置（保持） |
| `runners/run_analysis.R` | Framework 统一入口（本冻结主契约） |

---

## 2. 已完成能力

### 2.1 契约冻结

| 项 | 冻结值 |
|----|--------|
| `status` | `success` \| `partial` \| `error` \| `not_implemented` |
| exit `0` | `success` / `partial` |
| exit `1` | `error` |
| exit `2` | `not_implemented` |
| 必须字段 | `status`, `organism_type`, `input`, `tree`, `visualization`, `metadata`, `statistics`, `error_message` |

实现：`core/result_writer.R` + `runners/run_analysis.R`。

### 2.2 Virus（生产）

- 委托 `engine/phylogenetic_tree.R`（不复制 JC69）
- 可选 `engine/ggtree_visualization.R`（有 metadata 时）
- 失败必须写出 `analysis_result.json`（`status=error` + `error_message`），与 bacteria 对齐
- tip ↔ metadata 不匹配时覆盖 legacy 中间成功 JSON

### 2.3 Bacteria（生产）

- 委托同一 legacy 建树引擎
- 独立 `bacteria_visualization.R` + taxonomy 环配置
- metadata 强校验；tip mismatch / 缺列均写 error JSON
- `taxonomy_level` 可配置（见 `docs/bacteria_taxonomy_level.md`）

### 2.4 回归测试（本冻结验收）

脚本：`scripts/runners/run_framework_regression.R`  
产物：`output/tasks/framework_v01_regression/summary.json`

| Case | Exit | status | 结果 |
|------|------|--------|------|
| `virus_valid` | 0 | success | PASS |
| `virus_invalid_fasta` | 1 | error | PASS |
| `virus_metadata_mismatch` | 1 | error | PASS |
| `bacteria_valid` | 0 | success | PASS |
| `bacteria_invalid_metadata` | 1 | error | PASS |
| `bacteria_tip_mismatch` | 1 | error | PASS |

**Passed 6 / 6**（2026-07-24）。

---

## 3. 未完成能力（明确不在 v0.1）

| 项 | 状态 |
|----|------|
| Archaea / Eukaryote 完整 pipeline | 仅骨架 / `not_implemented` |
| Spring Boot 切换到 `run_analysis.R` | 未改（按要求本阶段禁止） |
| 前端 organism type 选择 / metadata 表单 | 未改 |
| 将 JC69 / 可视化算法从 engine 抽为可测函数库 | 未做（需 H3N2 回归后再议） |
| Bacteria 专用距离模型 / 真正 16S 分类鉴定 | 不做；仅启发式 warning |
| 旧 `output/**/analysis_result.json` 历史文件批量回写 | 不回写；新跑次遵循契约 |

---

## 4. 审计结论（字段差异 → 冻结）

| 来源 | 主要缺口（冻结前） | 冻结后处理 |
|------|-------------------|------------|
| Legacy engine 直出 | 无 `organism_type`/`tree`/`visualization`/`metadata`/`statistics`/`error_message`；失败用 `failed` | Strategy 经 `upgrade_legacy_result()` 升级；engine 本身不改 |
| Virus 旧产物 | 缺 `tree`、`error_message` | `build_analysis_result()` 强制写出 |
| Bacteria 旧错误产物 | 缺 `input`/`tree`；`statistics` 偶发 `[]` | `write_error_analysis_result()` 统一 object + 全字段 |

详见 [`analysis_result_contract.md`](analysis_result_contract.md) §1。

---

## 5. 下一阶段建议

1. **Boot 旁路接入（不破坏现状）**  
   增加 `phylo.r.entrypoint=runners/run_analysis.R`，传 `--type`；DTO 优先读 v0.1 必须字段，旧字段 fallback。

2. **契约消费方测试**  
   Java 侧对 `status=error` + exit=1、`not_implemented` + exit=2 做显式映射。

3. **H3N2 基准挂到统一入口**  
   用 `--type virus` 跑通 `data/benchmarks/h3n2_ha`，对比 `tree.nwk` / 统计字段，再考虑抽函数库。

4. **Archaea / Eukaryote**  
   仅在 metadata schema + 小样本 + 同样 error JSON 契约就绪后再开 strategy 实现（仍委托 engine，禁止复制算法）。

5. **历史产物**  
   保留旧 JSON 作考古；新任务一律写 `output/tasks/<runId>/`。

---

## 6. 冻结检查清单

- [x] 审计 virus / bacteria / legacy `analysis_result.json` 字段差异  
- [x] 写入 `docs/analysis_result_contract.md`  
- [x] 未修改 `engine/phylogenetic_tree.R`、`engine/ggtree_visualization.R`  
- [x] Virus 失败写出 `status=error` + `error_message`  
- [x] 回归：virus ×3 + bacteria ×3  
- [x] 本报告 `docs/framework_freeze_report.md`  
- [x] 未实现 archaea/eukaryote；未改 Spring Boot / 前端  

**结论：Multi-Organism Framework v0.1（virus + bacteria 统一生产契约）可冻结。**
