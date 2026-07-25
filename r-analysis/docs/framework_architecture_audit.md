# Framework Architecture Audit — Multi-Organism v0.1 Hardening

> 日期：2026-07-24  
> 阶段：Framework Hardening（只读审计，**未改代码**）  
> 范围：`strategies/virus`、`strategies/bacteria`、`core/`、`metadata/`、`runners/`  
> 约束：不修改 `engine/`、virus/bacteria strategy（本阶段）

---

## 1. 当前调用关系图

```text
┌─────────────────────────────────────────────────────────────────┐
│  CLI / 未来 Spring Boot                                         │
│  Rscript runners/run_analysis.R                                 │
│    --type --fasta [--metadata] --output                         │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  runners/run_analysis.R                                         │
│  parse args → load yaml → get_strategy(type) → strategy$run()   │
│  map status → exit 0|1|2                                        │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  strategies/strategy_registry.R                                 │
│  source_framework_core() → source *_strategy.R → factory()      │
└──────┬───────────────┬───────────────┬───────────────┬──────────┘
       │               │               │               │
       ▼               ▼               ▼               ▼
   virus/*         bacteria/*      archaea/*      eukaryote/*
   (production)    (production)    (stub)         (stub)
       │               │
       │               │
       ├─ validate_input / parse_metadata / tree_params
       ├─ annotation_config / output_spec
       └─ run() 编排
             │
             ├──────────────────┬──────────────────┐
             ▼                  ▼                  ▼
      core/tree_builder    core/visualization  core/result_writer
      invoke_legacy_       invoke_legacy_      build/write/
      tree_engine()        ggtree_viz() 或     upgrade/error JSON
             │             bacteria_viz 子进程
             ▼                  ▼
      engine/              engine/ggtree_visualization.R
      phylogenetic_tree.R  或 strategies/bacteria/bacteria_visualization.R
             │
             ▼
      (中间) analysis_result.json ← upgrade_legacy_result() 覆盖为 v0.1
```

### 1.1 成功路径（virus / bacteria）

1. `validate_input(ctx)`
2. `parse_metadata(ctx)`（virus 可跳过；bacteria 强制）
3. `invoke_legacy_tree_engine()` → `tree.nwk` + legacy JSON
4. tip ↔ metadata 对齐（有 metadata 时）
5. 可视化子进程（virus→ggtree；bacteria→bacteria_visualization）
6. `upgrade_legacy_result` / `build_analysis_result` → `write_analysis_result`

### 1.2 失败路径

Strategy 内 `tryCatch` → `write_error_analysis_result` → `stop()` → runner 外层 `quit(1)`。

---

## 2. 模块职责

| 模块 | 应有职责 | 实际现状 | 评价 |
|------|----------|----------|------|
| `runners/` | CLI 解析、装配 ctx、exit 映射 | 符合；不写业务校验 | OK |
| `strategies/strategy_registry.R` | 按 type 加载 Strategy | `switch` 硬编码四类型 | 扩展需改注册表 |
| `strategies/<type>/*_strategy.R` | 类型策略：校验、编排、调用 core | virus/bacteria 完整；含大量重复编排 | 偏重 |
| `strategies/<type>/*_annotation.R` | 字段映射 / 环图配置 | virus/bacteria 清晰 | OK |
| `strategies/bacteria/*_visualization.R` | 类型专用可视化 | 独立脚本；与 annotation 有重复 resolve 逻辑 | 可接受但有重复 |
| `core/strategy_base.R` | 接口契约、ctx、output_spec | 符合 | OK |
| `core/alignment.R` / `distance.R` / `tree_builder.R` / `visualization.R` | 阶段薄封装 / 子进程调用 | 契约函数多为 `stop("未实现")`；默认参数按 type `switch` | 半成品；type 知识渗入 core |
| `core/result_writer.R` | 统一 JSON 契约 | 符合 v0.1 冻结 | OK |
| `metadata/` | schema + 校验器 | 公共校验可用；bacteria 另有 `assert_bacteria_metadata_columns` | 双轨校验 |
| `engine/` | 冻结算法 | 不经 Strategy 直接可调（Boot 旧入口） | 双入口并存 |

---

## 3. 重复代码列表

| ID | 位置 | 重复内容 | 严重度 |
|----|------|----------|--------|
| D1 | `virus_strategy.R` ↔ `bacteria_strategy.R` | `fail_with_error_json()` 几乎相同（仅 organism_type 不同） | 高 |
| D2 | 同上 | `run()` 外层 `tryCatch` / “已写 error JSON 则跳过” 逻辑几乎相同 | 高 |
| D3 | 同上 | `input_basename(ctx)` 完全相同 | 中 |
| D4 | 同上 | tip ↔ metadata `setdiff(tips, labels)` + `fail_with_error_json` | 高 |
| D5 | 同上 | 成功收尾：`upgrade_legacy_result` vs `build_analysis_result` 分支结构相同 | 中 |
| D6 | `bacteria_annotation.R` ↔ `bacteria_visualization.R` | `resolve_taxonomy_ring_field` / taxonomy 回退逻辑重复 | 中 |
| D7 | `core/tree_builder.R` / `visualization.R` / `distance.R` | 四类型 `switch` 默认参数表重复形态 | 中 |
| D8 | `metadata_validator.R` `TYPE_EXTRA_COLUMNS$bacteria` ↔ `BACTERIA_EXTRA_COLUMNS` / `BACTERIA_REQUIRED_META_COLUMNS` | 列集合多处定义 | 中 |
| D9 | virus `invoke_legacy_ggtree_viz` ↔ bacteria `invoke_bacteria_viz` | system2 子进程调用样板 | 低（可抽 `invoke_viz_script`） |

---

## 4. 生物类型硬编码

| 位置 | 硬编码内容 | 影响 |
|------|------------|------|
| `strategy_registry.R` | `switch` 路径 + factory 名 | **新增 type 必须改注册表** |
| `core/strategy_base.R` | `PHYLO_ORGANISM_TYPES` | 新 type 必须改常量 |
| `core/*_params` | virus/bacteria/archaea/eukaryote 分支 | 新 type 必须改 core |
| `metadata_validator.R` | `TYPE_EXTRA_COLUMNS` | 新 type 必须改 validator |
| `config/analysis_config.yaml` | 四段 strategies | 预期（配置扩展点） |
| virus/bacteria strategy 内 | `"virus"` / `"bacteria"` 字符串写死在 fail/write | 可接受（策略自知类型） |

**结论：** 扩展新 organism **不能只加目录**；至少要改 registry + PHYLO_ORGANISM_TYPES + metadata extras +（通常）core 默认参数。对 Open-Closed 仅部分满足。

---

## 5. 职责错位

### 5.1 不应存在于 strategy 的逻辑（建议上移/抽取）

| 逻辑 | 当前 | 建议 |
|------|------|------|
| 通用 error JSON + tryCatch 包装 | virus/bacteria 各一份 | `core` 提供 `with_error_result(ctx, organism_type, expr)` |
| tip–metadata 对齐 | 两 strategy 复制 | `core` 或 `metadata` 提供 `assert_tips_match_metadata(tree, meta, id_col)` |
| FASTA 存在性 / 首行 `>` 检查 | virus 轻量；bacteria 重校验 | 共享 `validate_fasta_exists`；类型专属规则留 strategy |
| bacteria 内联 `read_fasta_records` | strategy 私有 | 可选抽到 `core/fasta_io.R`（类型无关 IO） |

### 5.2 不应存在于 core 的逻辑（建议下沉）

| 逻辑 | 当前 | 建议 |
|------|------|------|
| bacteria 专用 `taxonomy_level` / viz 脚本路径 | `default_viz_params("bacteria")` | 默认参数尽量中性；类型细节由 `*_annotation.R` / config 提供 |
| archaea/eukaryote 的 `status=not_implemented` 默认表 | `default_tree_params` | stub strategy 已表达；core 不必维护完整四表亦可 |

### 5.3 边界清晰、应保留在 strategy 的逻辑

- bacteria：DNA IUPAC、最少 3 条、16S 长度启发式、强制 metadata
- virus：legacy `label/Country/Year` 兼容、metadata 可选
- 各类型 annotation 列映射与环图字段

---

## 6. 是否满足 Open-Closed Principle（OCP）

| 维度 | 判定 | 说明 |
|------|------|------|
| 对算法封闭 | **是** | `engine/` 冻结；Strategy 只子进程调用 |
| 对结果契约封闭 | **是** | `result_writer` + `analysis_result_contract.md` |
| 对新增 organism 开放 | **部分** | 可新增 `strategies/<type>/`，但必须改 registry / 枚举 / metadata / 常改 core defaults |
| 对共享编排开放 | **弱** | 成功/失败编排大量复制，未形成可扩展的 pipeline template |

**总评：** v0.1 是可用的 Strategy Pattern **骨架 + 双生产实现**，尚未达到“加目录即接入”的 OCP。Hardening 下一刀应抽 **公共 run 样板** 与 **插件式注册**，而不是先做 archaea/eukaryote。

---

## 7. 潜在重构点（建议优先级，本阶段不实施）

| 优先级 | 重构 | 目的 | 触碰范围 |
|--------|------|------|----------|
| P0 | 抽取 `with_analysis_error_handling()` + 共享 tip 校验 | 消 D1–D4；统一异常契约 | **core**（不改 virus/bacteria 算法语义，可薄包装） |
| P1 | Registry 改为约定扫描 / 显式 register 表 | 新 type 少改核心 | registry + strategy_base |
| P1 | `core/*_params` 改为“默认空 + strategy/config 覆盖” | 减少 core 硬编码 | core |
| P2 | 统一 `invoke_script(rscript, script, args)` | 消 D9 | core/visualization |
| P2 | bacteria taxonomy resolve 单源 | 消 D6 | annotation 为权威；viz source 之 |
| P3 | 填充 `align_sequences_core` 等（仅委托，不改算法） | 减少“空契约” | core |
| — | **不要**为 OCP 改写 virus/bacteria 建树路径 | 保持生产稳定 | — |

---

## 8. 扩展性验证结论

| 问题 | 答案 |
|------|------|
| 当前架构能否支持未来扩展？ | **能**，但成本是“改注册表 + 复制 run 样板”，不是零摩擦 |
| virus/bacteria 是否证明 Strategy 可行？ | **是**（同一 engine、不同 annotation/viz/校验） |
| 最大障碍？ | 编排重复 + 类型枚举散落多处 |
| 是否应立即做 archaea/eukaryote？ | **否**；先 Hardening（公共错误处理 / 注册 / 测试矩阵） |

---

## 9. 相关文档

- [`analysis_result_contract.md`](analysis_result_contract.md)
- [`new_organism_development_guide.md`](new_organism_development_guide.md)
- [`error_handling_audit.md`](error_handling_audit.md)
- [`framework_test_matrix.md`](framework_test_matrix.md)
- [`framework_progress_report_v0.1.md`](framework_progress_report_v0.1.md)
