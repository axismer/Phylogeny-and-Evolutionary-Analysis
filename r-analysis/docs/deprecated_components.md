# Deprecated Components — Framework v0.3

> P4 文档化：标记仍保留的兼容层。**禁止在本阶段删除。**  
> 日期：2026-07-24

---

## 1. `register_builtin_strategies()`

| 项 | 内容 |
|----|------|
| 位置 | `strategies/strategy_registry.R` |
| 状态 | **deprecated**（P3）：空实现 + `warning` |
| 替代 | `discover_and_register_plugins()` |
| 为何保留 | 旧脚本 / 文档仍可能调用；避免硬失败 |
| 未来迁移 | 确认无外部调用后，下一清理阶段可删除符号；新增类型不得再依赖 builtins 表 |

---

## 2. 旧 FASTA reader（strategy 内）

| 项 | 内容 |
|----|------|
| 位置 | `strategies/virus/virus_strategy.R`、`strategies/bacteria/bacteria_strategy.R` 内 `.read_fasta_records_deprecated` |
| 状态 | **deprecated fallback**（P2）：仅当 `read_fasta` 未加载时使用 |
| 替代 | `core/io/fasta_io.R::read_fasta` |
| 为何保留 | tip 语义金标准副本；回滚与 parity 对照 |
| 未来迁移 | v0.3 全套回归长期绿且无旁路 source 后，可删本地副本，只保留 `core/io` |

---

## 3. defaults / schema 硬编码 fallback

| 符号 | 位置 | 状态 |
|------|------|------|
| `default_tree_params` 内 `switch` | `core/tree_builder.R` | plugin `get_default_config()$tree` 优先；switch = fallback |
| `default_distance_params` 内 `switch` | `core/distance.R` | 同上（`$distance`） |
| `default_viz_params` 内 `switch` | `core/visualization.R` | 同上（`$visualization`） |
| `TYPE_EXTRA_COLUMNS` | `metadata/metadata_validator.R` | plugin `get_metadata_schema()` 优先 |
| `PHYLO_ORGANISM_TYPES` | `core/strategy_base.R` | 文档/兼容表；新类型以 plugin 注册为准 |

| 为何保留 | 无 plugin 或早期加载顺序下仍可解析四类型；virus/bacteria 数值兼容 |
| 未来迁移 | 断言「plugin 声明 ≡ fallback」的审计长期绿后，可删 switch/表，仅留 plugin |

---

## 4. 其它兼容别名

| 符号 | 说明 |
|------|------|
| `load_strategy_plugins` | → `discover_and_register_plugins(reset=FALSE)` |
| `register_strategy` | 低层登记；生产路径应走 `plugin.R` |
| `.strategy_registry_env` | 别名指向 `.plugin_registry_env` |

---

## 5. 迁移计划（非本阶段）

1. **现在（P4）**：文档 + 源码注释标明 deprecated；不删除  
2. **下一清理窗口**：统计调用点；扩展 audit 对比 plugin vs fallback 值  
3. **再下一窗口**：删除 builtins 空函数、strategy 内 FASTA 副本、硬编码 switch/表（需单独评审 + 全回归）

**P4 停止条件：不删除上述任何符号。**
