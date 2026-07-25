# Strategy Runner Design — Framework v0.2

> 日期：2026-07-24  
> 实现：`core/strategy_runner.R`  
> 目标：消灭 virus/bacteria 重复的系统级错误处理，Strategy 只保留生物学逻辑

---

## 1. 问题（v0.1）

`virus_strategy.R` 与 `bacteria_strategy.R` 重复：

| 重复块 | 说明 |
|--------|------|
| `tryCatch` 外层 | 捕获后写 error JSON / 再抛 |
| `fail_with_error_json` | 覆盖 legacy success 残留 |
| tip `setdiff` | tip ↔ metadata |
| `dir.create(output_dir)` | 输出目录 |
| `input_basename` | FASTA 基名 |

生物学逻辑（校验规则、annotation、viz 脚本）本应不同，系统横切不该复制。

---

## 2. API

### 2.1 `run_strategy_pipeline(strategy, ctx, pipeline)`

```r
run_strategy_pipeline(
  strategy,   # list/Strategy，至少含 organism_type
  ctx,        # new_analysis_context(...)
  pipeline    # function(ctx, helpers) → analysis_result list
)
```

职责：

1. 统一日志（start / finish / ERROR）
2. `ensure_strategy_output_dir(ctx)`
3. 调用 `pipeline(ctx, helpers)`
4. `tryCatch`：若尚无本类型 error JSON，则 `write_error_analysis_result` 后 `stop`

### 2.2 Helpers（注入给 pipeline）

| helper | 作用 |
|--------|------|
| `fail(msg, tree=, metadata=, visualization=)` | 写 error JSON + stop |
| `ensure_dir()` | 创建 output |
| `input_basename()` | FASTA 基名 |
| `assert_tips(tree, metadata, id_column, message_prefix, ...)` | 调用 `tip_validator`；失败走 `fail` |

### 2.3 独立函数

- `fail_with_error_json(ctx, organism_type, error_message, ...)`
- `assert_tips_or_fail(...)`（内部）
- `strategy_input_basename` / `ensure_strategy_output_dir`

---

## 3. Strategy 职责边界

**Strategy 负责（生物学）：**

- `validate_input` / `parse_metadata`
- `tree_params` / `annotation_config` / `output_spec`
- 调用 `invoke_legacy_tree_engine` / 类型专用 viz
- 组装成功/partial `build_analysis_result` / `upgrade_legacy_result`
- 对外错误**文案前缀**（如 `VirusStrategy: ...`）以保持输出语义

**Strategy 禁止再实现：**

- 外层 tryCatch + error JSON 兜底
- 手写 tip `setdiff` 循环
- 复制 `fail_with_error_json` 闭包

---

## 4. 调用示意

```text
strategy$run(ctx)
  └─ run_strategy_pipeline(strategy, ctx, function(ctx, helpers) {
         validate_input(ctx)
         ...
         helpers$assert_tips(..., message_prefix = "VirusStrategy: ...缺失: ")
         ...
         write_analysis_result(result, ...)
         result
     })
```

---

## 5. 语义兼容

- tip 失败仍使用各 Strategy 既有中文前缀（经 `message_prefix`）
- 建树失败 / 校验失败文案保持 `VirusStrategy:` / `BacteriaStrategy:` 前缀
- valid 路径字段与 status 规则不变（success / partial）

---

## 6. 与 tip_validator / runner 的关系

```text
runners/run_analysis.R          # 进程级兜底 JSON + exit
        │
        ▼
run_strategy_pipeline           # Strategy 级 tryCatch + error JSON
        │
        ├─ helpers$assert_tips → core/tip_validator.R::assert_tip_match
        └─ helpers$fail        → core/result_writer.R::write_error_analysis_result
```

---

## 7. 非目标

- 不把建树 / 可视化算法迁入 runner
- 不实现 archaea/eukaryote pipeline
- 不改变 engine/
