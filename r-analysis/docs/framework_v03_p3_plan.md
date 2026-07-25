# Framework v0.3 P3 Plan — Plugin Registry Refactor

> 日期：2026-07-24  
> 状态：**已完成（2026-07-24）— 不进入 P4；等待人工评审**  
> 前置：P0 ✅ · P1 ✅（5/5）· P2 ✅（10/10）· v0.2 回归 13/13  
> 回归：v02 13/13 + P1 5/5 + P2 10/10 + P3 7/7  
> 范围：Plugin Contract + Discovery + Dynamic Registry（契约 API 以实施确认版为准）  
> **本阶段结束后停止；不实现 archaea/eukaryote 生产管线；不进入 P4**

---

## 1. 当前问题

### 1.1 注册仍半硬编码

`strategies/strategy_registry.R` 虽已有 `register_strategy` / `load_strategy_plugins`，但生产路径仍依赖：

```text
register_builtin_strategies()   # 硬编码 virus/bacteria/archaea/eukaryote 路径表
load_strategy_plugins()         # 扫描 strategies/*/plugin.R（当前仓库无 plugin.R）
```

结果：

| 现象 | 影响 |
|------|------|
| 内置类型写死在 registry | 新增生产类型仍可能改 `register_builtin_strategies` |
| 尚无 `strategies/*/plugin.R` | 「只加目录」路径未落地 |
| `create_<type>_strategy` 命名约定隐含在 registry | 工厂解析与 type 字符串耦合 |

`runners/run_analysis.R` 亦显式调用 `register_builtin_strategies()` + `load_strategy_plugins()`，与 registry 重复，强化硬编码依赖。

### 1.2 core / metadata 中的 organism 白名单与 switch

| 位置 | 硬编码内容 |
|------|------------|
| `core/strategy_base.R` | `PHYLO_ORGANISM_TYPES <- c(virus, bacteria, archaea, eukaryote)`；`new_phylo_strategy` 拒绝表外类型 |
| `core/tree_builder.R` | `default_tree_params` 按 type `switch` |
| `core/distance.R` | `default_distance_params` 按 type `switch` |
| `core/visualization.R` | `default_viz_params` 按 type `switch` |
| `metadata/metadata_validator.R` | `TYPE_EXTRA_COLUMNS` 按四类型硬编码 |

因此即便 registry 不再列类型，**新 organism 仍可能因 base/validator/defaults 白名单失败** — 未达「只增 `strategies/new_organism/`」。

### 1.3 与最终目标的差距

目标（确认后实现）：

```text
新增 organism → 只新增 strategies/<name>/（含 plugin.R + strategy）
不改：registry / core / runner
```

当前：半自动钩子已在，但 builtins + 白名单 + 无 plugin 契约，**OCP 未闭合**。

### 1.4 本阶段明确不做

- 不修改 `engine/**`
- 不修改 H3N2 benchmark
- **不实现** archaea / eukaryote 生产算法（仅允许 stub 的 `plugin.R` 以保持 v0.2 `archaea_not_implemented`）
- 不修改 Spring Boot / frontend
- 不改变 virus/bacteria **成功** `analysis_result.json` 字段语义
- 不删除 P2 deprecated FASTA fallback
- 不进入 P4（validator 彻底去硬编码若超出本阶段最小接线，则保留 fallback 并文档化）

---

## 2. 设计方案

### 2.0 总体架构（目标态）

```text
run_analysis.R
      │
      ▼
strategy_registry.R
  source_framework_core()          # 含 plugin_contract.R（及既有 core/io 自举）
  discover_and_register_plugins()  # 仅扫描 strategies/*/plugin.R
      │
      ▼
strategies/<type>/plugin.R         # 声明契约函数并 register
strategies/<type>/*_strategy.R     # 既有业务实现（virus/bacteria 行为不变）
```

目录（本阶段落地）：

```text
strategies/
├── virus/
│   ├── plugin.R
│   └── virus_strategy.R
├── bacteria/
│   ├── plugin.R
│   └── bacteria_strategy.R
├── archaea/          # stub only：plugin.R 指向既有 not_implemented strategy
│   ├── plugin.R
│   └── archaea_strategy.R
└── eukaryote/        # stub only：同上
    ├── plugin.R
    └── eukaryote_strategy.R
```

新增未来类型：只加目录 + `plugin.R`，**不改** registry / runner / core 白名单（见 §2.4 放宽策略）。

### 2.1 P3.1 Plugin Contract — `core/plugin_contract.R`

每个 `plugin.R` 在注册前必须能提供（直接定义或返回 list）：

| 函数 | 职责 |
|------|------|
| `plugin_info()` | `list(organism_type, version, status, strategy_file, ...)`；`status` ∈ `production` \| `not_implemented` |
| `create_strategy()` | 零参工厂 → `PhyloAnalysisStrategy`（可内部 `source` strategy 文件后调既有 `create_*_strategy`） |
| `get_metadata_schema()` | 类型扩展列 / 是否 strict 等；供 validator 查询（P3 先接线 + fallback） |
| `get_tree_defaults()` | 建树默认参数（替代/优先于 core `switch`） |
| `get_visualization_defaults()` | 可视化默认参数 |

契约校验（建议）：

```r
assert_plugin_contract(env_or_list)   # 缺任一入口 → PLUGIN_ERROR
register_strategy_plugin(manifest)     # 幂等：同 type 同来源跳过；不同来源重复 → PLUGIN_ERROR
```

**错误码：** 在 `error_codes.R` 增加 `PLUGIN_ERROR`（仅插件加载/重复注册；不改 success JSON）。

**命名空间隔离：** 每个 `plugin.R` 用局部环境 `source(local = new.env(...))` 再抽取五函数，避免多 plugin 全局互相覆盖；registry 只保存闭包/manifest。

### 2.2 P3.2 Plugin Discovery

```r
discover_and_register_plugins(dirs) {
  files <- sort(Sys.glob(file.path(dirs$strategies, "*", "plugin.R")))
  for (pf in files) {
    # source into isolated env → assert_plugin_contract → register_strategy_plugin
  }
}
```

规则：

1. **仅**识别 `strategies/*/plugin.R`（不扫任意 `*_strategy.R`）
2. 目录名与 `plugin_info()$organism_type` 不一致 → `PLUGIN_ERROR`（防漂移）
3. 同进程二次 `get_strategy`：已注册同 type 且同源 → 幂等；**不同 plugin 文件争同一 type** → `PLUGIN_ERROR`
4. 删除 / 停用 `register_builtin_strategies()` 硬编码表（或改为空操作 + 警告 deprecated，回归绿后可删）

### 2.3 P3.3 Dynamic Registry

`get_strategy(type)` 简化为：

```text
source_framework_core()
discover_and_register_plugins()   # 唯一登记来源
lookup → create_strategy() → assert_phylo_strategy
```

`run_analysis.R`：

- 去掉对 `register_builtin_strategies()` 的依赖
- 未知 type：保持 P1 行为 → `not_implemented` + `UNSUPPORTED_ORGANISM` + exit 2
- 插件加载失败（契约/重复）：`error` + `PLUGIN_ERROR` + exit 1（写出 JSON）
- `print_usage` 的 type 列表改为 `list_registered_strategies()`（动态），避免 usage 再硬编码四类型

### 2.4 解开 core 白名单（最小必要，保证「新类型不改 core」）

| 组件 | P3 动作 |
|------|---------|
| `PHYLO_ORGANISM_TYPES` / `new_phylo_strategy` | 改为：允许任意非空 type，**或**「已注册 types ∪ 兼容四类型」；禁止再因未列入四常量而 `stop` |
| `default_tree_params` / `default_viz_params` / `default_distance_params` | **优先**查 registry 中该 type 的 `get_tree_defaults` / `get_visualization_defaults`（及 distance 若 schema 提供）；查不到再 fallback 现有 `switch`（virus/bacteria 数值必须一致） |
| `TYPE_EXTRA_COLUMNS` | **优先** `get_metadata_schema()`；无则 fallback 现表（virus/bacteria 校验结果不变） |

说明：P3 完成「可插拔 + 默认值/ schema 可被 plugin 覆盖」；硬编码 `switch`/表可作为 **deprecated fallback** 保留（与 P2 FASTA 策略一致），全删留给后续清理，不阻塞「新增目录」主路径。

### 2.5 virus / bacteria plugin 适配（行为不变）

`strategies/virus/plugin.R` / `strategies/bacteria/plugin.R`：

- `create_strategy()` → 调用既有 `create_virus_strategy` / `create_bacteria_strategy`（先 source strategy 文件）
- `get_*_defaults()` / `get_metadata_schema()` → **从当前生产默认原样搬出**（与现 `default_*` / `TYPE_EXTRA_COLUMNS` 一致）
- **不改** strategy 成功路径组装与写出字段

archaea / eukaryote：仅加 `plugin.R` 声明 `status = "not_implemented"`，工厂仍返回现有 stub strategy（exit 2 路径保持）。**不实现**生产建树/可视化。

### 2.6 与 P2 IO 的关系

- `source_framework_core` 可显式加入 `plugin_contract.R`；`core/io` 继续由 result_writer 自举（P3 可选一行登记 io，非必须）
- 不回退 P2 tip 语义

### 2.7 分步实施（确认后编码顺序）

| 子步 | 内容 | 门槛 |
|------|------|------|
| P3.1 | `plugin_contract.R` + `PLUGIN_ERROR` | 单元级契约断言可测 |
| P3.2 | virus/bacteria/archaea/eukaryote `plugin.R` | 扫描可注册四类型 |
| P3.3 | registry 去 builtins；discovery-only；runner 对齐 | get_strategy(virus/bacteria) 冒烟 |
| P3.4 | 放宽 `new_phylo_strategy`；defaults/schema 优先 plugin + fallback | valid JSON 字段兼容 |
| P3.5 | P3 回归 + 重跑 v02/P1/P2 | 全部绿 |
| P3.6 | `docs/framework_v03_p3_report.md` | **停止** |

---

## 3. 修改文件列表

| 文件 | 改动要点 |
|------|----------|
| `strategies/strategy_registry.R` | 移除/废弃 `register_builtin_strategies` 硬编码；`discover_and_register_plugins`；`register_strategy_plugin`；factory 优先 `create_strategy()`；重复 → `PLUGIN_ERROR` |
| `runners/run_analysis.R` | 仅 discovery；usage 动态；插件错误映射 exit 1 + `PLUGIN_ERROR` |
| `core/strategy_base.R` | 放宽 `PHYLO_ORGANISM_TYPES` 门禁（见 §2.4） |
| `core/tree_builder.R` | `default_tree_params` 优先 plugin defaults，fallback 现 switch |
| `core/visualization.R` | 同上（viz） |
| `core/distance.R` | 同上（distance；若 schema 未声明则 fallback） |
| `metadata/metadata_validator.R` | `expected_metadata_columns` 优先 plugin schema，fallback `TYPE_EXTRA_COLUMNS` |
| `core/error_codes.R` | 新增 `PLUGIN_ERROR` |
| `core/result_writer.R` 或 `source_framework_core` | 加载 `plugin_contract.R` |
| `docs/plugin_registry_design.md` | 状态更新为 v0.3 P3（编码后） |
| `docs/new_organism_development_guide.md` | 改为「仅增目录 + plugin.R」（编码后，可选同 PR） |

**明确不修改：** `engine/**`、H3N2 benchmark、Spring Boot、frontend、virus/bacteria **成功组装逻辑**（仅加载路径经 plugin）。

---

## 4. 新增文件列表

| 文件 | 作用 |
|------|------|
| `core/plugin_contract.R` | 契约断言、`register_strategy_plugin` 辅助、manifest 结构 |
| `strategies/virus/plugin.R` | virus 插件声明（生产） |
| `strategies/bacteria/plugin.R` | bacteria 插件声明（生产） |
| `strategies/archaea/plugin.R` | stub 插件（not_implemented，保 v0.2） |
| `strategies/eukaryote/plugin.R` | stub 插件（not_implemented） |
| `scripts/runners/run_framework_v03_p3_regression.R` | P3 回归 |
| `docs/framework_v03_p3_report.md` | 完成后工程报告（编码后写） |

测试夹具（回归用，可选）：

| 路径 | 作用 |
|------|------|
| `test-data/plugin/duplicate_*` 或临时目录 | 复制两份争用同一 type 的 plugin 场景（也可用 runner 内 tempfile） |

---

## 5. 风险分析

| 风险 | 等级 | 缓解 |
|------|------|------|
| plugin 加载失败导致 virus/bacteria 工厂找不到 | **高** | `create_strategy` 显式 source 既有 strategy 文件；P3 后立刻跑 v02+P1+P2+P3 |
| 成功 JSON 字段漂移 | **高** | 禁止改 success 组装；P1/P2 forbid `error_code`；抽查 `status/tree/visualization/statistics` |
| 多 plugin 全局函数名互相覆盖 | 中 | `source(local = env)` 隔离；registry 只存闭包 |
| `new_phylo_strategy` 放宽后非法 type 混入 | 中 | 仍须经 registry 注册才能被 CLI 调用；未注册 → exit 2 |
| defaults/schema fallback 与 plugin 声明不一致 | 中 | virus/bacteria plugin 数值从现 switch/表**原样拷贝**；回归对比 valid |
| archaea/eukaryote 加 plugin 被误解为「已实现」 | 低 | `plugin_info()$status = "not_implemented"`；文档写明 |
| 同进程重复 discover | 低 | 幂等注册；仅跨文件 type 冲突报 `PLUGIN_ERROR` |
| usage/帮助文案动态化影响脚本解析 | 低 | 仅 message；CLI 参数不变 |

回滚：

1. 恢复 `register_builtin_strategies` 调用  
2. 删除或停用 `strategies/*/plugin.R`  
3. 还原 registry / runner / strategy_base 门禁  
4. 重跑 v02 + P1 + P2  

---

## 6. 测试方案

### 6.1 兼容回归（必须全绿）

```bash
cd r-analysis
Rscript scripts/runners/run_framework_regression.R           # 期望 13/13
Rscript scripts/runners/run_framework_v03_p1_regression.R    # 期望 5/5
Rscript scripts/runners/run_framework_v03_p2_regression.R    # 期望 10/10
```

### 6.2 新增 `framework_v03_p3_regression`

输出：`output/tasks/framework_v03_p3_regression/summary.json`

| case | expect |
|------|--------|
| virus_valid | exit 0；success/partial；**无** `error_code` |
| bacteria_valid | 同上 |
| archaea_not_implemented | exit 2；`not_implemented`；`UNSUPPORTED_ORGANISM`（或既有 stub 码表兼容） |
| unknown_organism | exit 2；`not_implemented`；`UNSUPPORTED_ORGANISM` |
| plugin_discovery | `list_registered_strategies()` 含 `virus`,`bacteria`（及 stub 类型） |
| plugin_duplicate | 构造重复 type 注册 → `PLUGIN_ERROR`；exit 1；message 含 duplicate |
| plugin_contract_missing | 故意缺 `plugin_info` 的临时 plugin → `PLUGIN_ERROR` |

### 6.3 成功路径不变证明

对 virus_valid / bacteria_valid：

- `status` ∈ {success, partial}
- 无 `error_code` 键
- 存在 `tree` / `statistics`（object）
- tip 匹配仍通过（复用 P2 tip 断言精神，可选轻量抽查）

### 6.4 验收标准（P3 Done）

- [ ] 无 `register_builtin_strategies` 硬编码路径表（或明确 deprecated 空实现）
- [ ] virus/bacteria/archaea/eukaryote 均经 `plugin.R` 发现
- [ ] `core/plugin_contract.R` 五函数契约强制
- [ ] 重复 plugin → `PLUGIN_ERROR`
- [ ] 未知 type → exit 2（P1 不变）
- [ ] v02 13/13 · P1 5/5 · P2 10/10 · P3 全绿
- [ ] 未改 engine / Boot / frontend / H3N2 benchmark
- [ ] 输出 `docs/framework_v03_p3_report.md`
- [ ] **停止，不进入 P4**

---

## 7. 请确认

1. **同意** 删除 builtins 硬编码，四类型（含 archaea/eukaryote **stub**）全部改 `plugin.R` 发现？  
2. **同意** P3.1 契约五函数：`plugin_info` / `create_strategy` / `get_metadata_schema` / `get_tree_defaults` / `get_visualization_defaults`？  
3. **同意** core defaults / metadata schema：**优先 plugin，硬编码作 deprecated fallback**（不在本阶段强删 switch）？  
4. **同意** 重复/坏 plugin → `PLUGIN_ERROR` + exit 1；未知 type 仍 exit 2？  
5. **同意** 按 §6 回归矩阵？  

回复「确认，开始 P3 编码」或修订意见后，再改代码。
