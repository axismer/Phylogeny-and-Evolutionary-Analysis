# Error Code Reference

> Framework v0.3 P4  
> 日期：2026-07-24  
> 源码：`core/error_codes.R`  
> 契约：`success` / `partial` **禁止**出现 `error_code` 键；`error` / `not_implemented` 必须含 `error_code` + `error_message`

---

## 总览

| error_code | status | exit | 含义（一句话） |
|------------|--------|------|----------------|
| `EMPTY_FASTA` | error | 1 | FASTA 缺失 / 空 / 基础格式无效 |
| `INVALID_DNA` | error | 1 | 序列含非法碱基（相对 IUPAC） |
| `TOO_FEW_SEQUENCE` | error | 1 | 序列数不足或过短等数量/长度规则失败 |
| `MISSING_METADATA_ARGUMENT` | error | 1 | 需要 `--metadata` 但未提供 |
| `METADATA_FILE_NOT_FOUND` | error | 1 | metadata 路径不存在或不可读 |
| `MISSING_METADATA_FIELDS` | error | 1 | metadata 缺列 / schema 失败 |
| `TIP_METADATA_MISMATCH` | error | 1 | tree tip 与 metadata id 不对齐 |
| `TREE_BUILD_FAILED` | error | 1 | 建树子进程失败 |
| `VISUALIZATION_FAILED` | error | 1 | 可视化失败（若策略映射为硬错误） |
| `PLUGIN_NOT_FOUND` | error | 1 | 指定 plugin 文件不存在 |
| `PLUGIN_LOAD_FAILED` | error | 1 | plugin source / get_strategy 失败 |
| `PLUGIN_CONTRACT_INVALID` | error | 1 | plugin 缺契约函数或返回值非法 |
| `PLUGIN_DUPLICATE_TYPE` | error | 1 | 两个 plugin 争用同一 organism_type |
| `UNSUPPORTED_ORGANISM` | not_implemented | 2 | 未知 type 或 stub 未实现 |

---

## 明细

### EMPTY_FASTA

| 项 | 内容 |
|----|------|
| 含义 | 输入 FASTA 不可用或基础格式检查失败 |
| 触发条件 | 缺少 `--fasta`；文件不存在；空文件；virus 首行非 `>`；解析后 0 条记录等 |
| status | `error` |
| exit | `1` |
| 典型来源 | `validate_fasta_basic` / strategy `validate_input` |

### INVALID_DNA

| 项 | 内容 |
|----|------|
| 含义 | DNA 字符不在允许的 IUPAC 集合内 |
| 触发条件 | strategy 校验（virus/bacteria）发现非法碱基 |
| status | `error` |
| exit | `1` |
| 说明 | **不**在 `core/io/fasta_io.R` 抛出；生物学规则留在 strategy |

### TOO_FEW_SEQUENCE

| 项 | 内容 |
|----|------|
| 含义 | 序列数量或长度不满足策略规则 |
| 触发条件 | 例如少于 3 条；bacteria 存在 `<50 bp` 等 |
| status | `error` |
| exit | `1` |

### MISSING_METADATA_ARGUMENT

| 项 | 内容 |
|----|------|
| 含义 | 策略要求提供 metadata，但 CLI 未传 |
| 触发条件 | `require_metadata_argument`（如 bacteria） |
| status | `error` |
| exit | `1` |
| 说明 | virus metadata 可选，通常不触发本码 |

### METADATA_FILE_NOT_FOUND

| 项 | 内容 |
|----|------|
| 含义 | metadata 路径无效或不可读 |
| 触发条件 | `ensure_metadata_readable` / `read_metadata`；路径不存在或读失败 |
| status | `error` |
| exit | `1` |

### MISSING_METADATA_FIELDS

| 项 | 内容 |
|----|------|
| 含义 | metadata 缺少必需列或类型扩展列（strict） |
| 触发条件 | `validate_metadata` / bacteria `assert_bacteria_metadata_columns` 等 |
| status | `error` |
| exit | `1` |

### TIP_METADATA_MISMATCH

| 项 | 内容 |
|----|------|
| 含义 | Newick tip 与 metadata id（如 `label`）集合不匹配 |
| 触发条件 | `assert_tips_or_fail` / `assert_tip_match` 失败 |
| status | `error` |
| exit | `1` |

### TREE_BUILD_FAILED

| 项 | 内容 |
|----|------|
| 含义 | 建树引擎子进程非 0 退出 |
| 触发条件 | `invoke_legacy_tree_engine` 失败后 `helpers$fail(..., error_code=TREE_BUILD_FAILED)` |
| status | `error` |
| exit | `1` |

### VISUALIZATION_FAILED

| 项 | 内容 |
|----|------|
| 含义 | 可视化失败被映射为硬错误时使用 |
| 触发条件 | 当前 virus/bacteria 成功路径多为 warning + `partial`；码表预留 |
| status | `error` |
| exit | `1` |
| 说明 | 生产路径常见为 `partial`（有树无图），不一定写本码 |

### PLUGIN_NOT_FOUND

| 项 | 内容 |
|----|------|
| 含义 | 请求加载的 `plugin.R` 路径不存在 |
| 触发条件 | `load_plugin_file` 文件缺失 |
| status | `error` |
| exit | `1` |

### PLUGIN_LOAD_FAILED

| 项 | 内容 |
|----|------|
| 含义 | plugin 加载或 `get_strategy()` 执行失败 |
| 触发条件 | `source(plugin.R)` 异常；strategy 文件缺失；工厂函数找不到 |
| status | `error` |
| exit | `1` |

### PLUGIN_CONTRACT_INVALID

| 项 | 内容 |
|----|------|
| 含义 | plugin 未满足统一契约 |
| 触发条件 | 缺五函数之一；`get_status` 非 `production|stub`；schema/config 非 list；目录名与 type 不一致 |
| status | `error` |
| exit | `1` |

### PLUGIN_DUPLICATE_TYPE

| 项 | 内容 |
|----|------|
| 含义 | 多个 plugin 声明同一 `organism_type` |
| 触发条件 | `register_plugin_manifest` 发现不同路径争用同 type |
| status | `error` |
| exit | `1` |

### UNSUPPORTED_ORGANISM

| 项 | 内容 |
|----|------|
| 含义 | 未知 organism，或已注册 stub 未实现生产管线 |
| 触发条件 | CLI `--type` 不在已注册表；archaea/eukaryote stub `run` → `not_implemented` |
| status | `not_implemented` |
| exit | `2` |

---

## Exit 码约定

| exit | 含义 |
|------|------|
| 0 | `success` 或 `partial` |
| 1 | `error`（含 PLUGIN_* 与业务错误） |
| 2 | `not_implemented` / `UNSUPPORTED_ORGANISM` |

---

## 消费者提示

- 读 JSON：先看 `status`，再看 `error_code`（仅 error / not_implemented）
- 成功路径字段稳定：`status`, `organism_type`, `input`, `tree`, `visualization`, `metadata`, `statistics`, `error_message`（空串）
- 详细字段见 [`analysis_result_contract.md`](analysis_result_contract.md)
