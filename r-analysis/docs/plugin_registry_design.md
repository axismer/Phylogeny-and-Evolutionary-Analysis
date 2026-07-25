# Plugin Registry Design — Framework v0.2

> 日期：2026-07-24  
> 实现：`strategies/strategy_registry.R`（`register_strategy` + 半自动 plugin）  
> 目标：未来 `strategies/fungi/` 可不改 registry **核心分发逻辑**

---

## 1. 现状问题（v0.1）

`get_strategy()` 内硬编码双重 `switch`（路径 + factory 名）。新增类型必须改 registry 源码 → 违反 OCP。

---

## 2. 方案选择

| 方案 | 优点 | 风险 | 结论 |
|------|------|------|------|
| A. 全自动扫描 `strategies/*/` | 零登记 | 误加载实验目录、命名冲突、难审计 | **不采用** |
| B. 半自动：`register_strategy` + 可选 `plugin.R` | 显式、可审计、核心 get 不变 | 新类型需加一个小文件 | **采用** |
| C. 仅配置 YAML 列表 | 清晰 | 仍要改配置；factory 仍需约定 | 可作后续增强 |

---

## 3. API

### 3.1 `register_strategy(organism_type, factory = NULL, strategy_file = NULL, overwrite = FALSE)`

登记到进程内环境 `.strategy_registry_env`。

- `factory`：零参函数，返回 Strategy  
- `strategy_file`：首次 `get_strategy` 时 source，再解析 `create_<type>_strategy`

### 3.2 `list_registered_strategies()`

返回已注册类型名。

### 3.3 `get_strategy(type)`（核心逻辑稳定）

```text
source_framework_core()
register_builtin_strategies()   # virus/bacteria/archaea/eukaryote
load_strategy_plugins()         # strategies/*/plugin.R
lookup registry[type]
resolve factory (source file if needed)
factory() → assert_phylo_strategy
```

**新增 fungi 时：不修改上述步骤代码**，只新增：

```text
strategies/fungi/
  fungi_strategy.R
  fungi_annotation.R
  plugin.R          # register_strategy("fungi", strategy_file = <path>)
```

示例 `plugin.R`：

```r
dirs <- .get_framework_dirs()
register_strategy(
  "fungi",
  strategy_file = file.path(dirs$strategies, "fungi", "fungi_strategy.R"),
  overwrite = FALSE
)
```

---

## 4. 内置类型

仍由 `register_builtin_strategies()` 登记（本仓库维护），避免空注册表。  
内置列表变更（极少）才需改 registry；**第三方类型走 plugin.R**。

---

## 5. 为何不全自动扫描 `*_strategy.R`

1. archaea/eukaryote stub 与实验目录可能并存  
2. 文件名/factory 约定被破坏时失败模式不清晰  
3. Windows / 路径大小写与重复 type 难处理  
4. 安全：任意目录 source 扩大攻击面（本地工具仍建议显式 opt-in）

`plugin.R` = 显式 opt-in 扫描点（仅当文件存在才 source）。

---

## 6. 与新类型指南的关系

见 [`new_organism_development_guide.md`](new_organism_development_guide.md)。  
v0.2 起注册步骤改为：

1. 实现 `strategies/<type>/`  
2. 添加 `plugin.R` 调用 `register_strategy`  
3. 更新 metadata schema / config / 测试  
4. **不必**改 `get_strategy` 的 switch（已无）

仍可能需改：`PHYLO_ORGANISM_TYPES`、`TYPE_EXTRA_COLUMNS`、`default_*_params`（后续可再硬化）。

---

## 7. 验收

- [x] `register_strategy` 存在  
- [x] builtins 经注册表加载  
- [x] `get_strategy` 无 type 名 `switch`  
- [x] `strategies/*/plugin.R` 钩子就位（当前可无 plugin 文件）  
- [ ] 真实 fungi 示例（本阶段不做）
