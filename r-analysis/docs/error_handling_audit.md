# Error Handling Audit — Framework v0.1

> 日期：2026-07-24  
> 阶段：Framework Hardening（只读）  
> 契约：[`analysis_result_contract.md`](analysis_result_contract.md)  
> 要求核对：失败 → `exit != 0` + 落盘 `analysis_result.json`（`status=error`）

---

## 1. 统一失败契约（期望）

```json
{
  "status": "error",
  "organism_type": "<type>",
  "input": "<fasta basename or \"\">",
  "tree": "",
  "visualization": "",
  "metadata": "",
  "statistics": {},
  "error_message": "<non-empty>"
}
```

| 进程 exit | 条件 |
|-----------|------|
| `1` | `status=error` 或未捕获异常 |
| `2` | `status=not_implemented` |
| `0` | **仅** `success` / `partial` |

实现机制（virus / bacteria）：

1. `fail_with_error_json` 或 `run()` 外层 `tryCatch` → `write_error_analysis_result`
2. `stop(msg)` → `runners/run_analysis.R` 外层 `quit(1)`

---

## 2. 路径审计矩阵

图例：

- **Y** = 符合（exit≠0 且 error JSON）
- **P** = 部分 / 类型间不一致
- **N** = 不符合或未覆盖
- **S** = 软失败（设计为 `partial` + exit 0，**不是** error）

| # | 场景 | Virus | Bacteria | 备注 |
|---|------|-------|----------|------|
| 1 | FASTA 不存在 | **Y** | **Y** | `stop` → tryCatch 写 JSON |
| 2 | FASTA 为空 | **Y** | **Y** | virus：判为格式无效；bacteria：`n<3` |
| 3 | DNA 字符错误 | **N**（未校验） | **Y** | virus 依赖 engine；非法碱基可能到建树阶段才失败 |
| 4 | 序列数量不足 | **P** | **Y** | bacteria `<3` 硬失败；virus 无最少条数策略校验 |
| 5 | metadata 不存在 | **Y**（若传了路径） | **Y** | virus 未传 metadata 合法；bacteria 强制要求 |
| 6 | metadata 字段缺失 | **P** | **Y** | bacteria `assert_*` + strict；virus unified schema `strict=FALSE` 仅 warning |
| 7 | tip mismatch | **Y** | **Y** | 覆盖 legacy success JSON |
| 8 | tree 生成失败 | **Y** | **Y** | `invoke_legacy_tree_engine` exit≠0 → fail JSON |
| 9 | visualization 失败 | **S** | **S** | warning → `status=partial`，**exit 0**（有意软失败） |
| 10 | 磁盘写入失败 | **P** | **P** | `write_*` 无专门兜底；写 JSON 本身失败时可能无文件 |

### 2.1 补充场景

| 场景 | Virus | Bacteria | 说明 |
|------|-------|----------|------|
| 缺少 `--fasta` / 空路径 | Y | Y | |
| metadata 与 `--type` 不一致 | Y（unified+validator） | Y | |
| archaea/eukaryote 调用 | exit **2** + `not_implemented` JSON | — | 非 error，符合冻结契约 |
| runner 在 `get_strategy` 前失败 | exit 1，**可能无 JSON** | | 输出目录可能尚未创建 |
| `output_dir` 为空 | fail_with_error_json 直接 stop，**无 JSON** | 同左 | 正常 CLI 总会传 `--output` |

---

## 3. 分场景说明

### 3.1 FASTA 不存在 / 为空 / 格式坏

| 类型 | 检测点 | error_message 特征 |
|------|--------|-------------------|
| virus | `validate_input` | `FASTA 不存在` / `FASTA 格式无效` |
| bacteria | `validate_input` | `FASTA 不存在` / `至少需要 3 条` |

空文件：virus 与 bacteria 均会失败并写 JSON（回归已覆盖 virus invalid；bacteria 有 `test-data/bacteria/empty/` 夹具但未进 v0.1 六案回归）。

### 3.2 DNA 字符错误

- **bacteria**：IUPAC 外字符 → error JSON（夹具 `illegal_dna/`）。
- **virus**：strategy **不做**碱基校验；依赖 engine。若 engine 失败 → 路径 8（Y）。若 engine 容忍异常字符 → 可能“成功”产出树（风险，见 §5）。

### 3.3 序列数量不足

- bacteria：硬门禁 `n < 3`。
- virus：无对等门禁；极少序列时可能 engine 失败（Y）或产生退化树（风险）。

### 3.4 Metadata 缺失 / 字段缺失

| | virus | bacteria |
|--|-------|----------|
| 不传 `--metadata` | 允许；跳过 tip/viz | **error** |
| 路径不存在 | error | error |
| 缺扩展列 | unified 时 `strict=FALSE` → **warning 继续** | `assert_bacteria_metadata_columns` → **error** |

→ **类型策略故意不对称**；测试矩阵需分开期望。

### 3.5 Tip mismatch

两者均在建树后、可视化前检查；写 `status=error` 并覆盖可能残留的 legacy `success` JSON。  
回归：`virus_metadata_mismatch`、`bacteria_tip_mismatch` = PASS。

### 3.6 Tree 生成失败

`tree_res$exit_code != 0` → `fail_with_error_json("…建树失败…")`。符合。

### 3.7 Visualization 失败（**契约例外：软失败**）

设计意图：

- 树已产出 → 对上游仍有价值
- `status=partial`，`visualization=""`，**exit 0**

与“所有失败 exit≠0”的字面要求**不一致**，但是 v0.1 **有意**行为（见 contract 中 `partial`）。  
Hardening **不建议**改为硬错误，除非产品明确要求“无环图即失败”。

### 3.8 磁盘写入失败

`write_analysis_result` / `dir.create` 失败时：

- 可能抛错到 runner → exit 1
- **不保证**存在可读的 `analysis_result.json`

缺口：无只读介质 / 权限不足专项测试。

---

## 4. Runner 层缺口

`runners/run_analysis.R` 外层：

```r
error = function(e) {
  message("ERROR: ", ...)
  quit(save = "no", status = 1)
}
```

- **不会**在 runner 层补写 JSON。
- 依赖 strategy `run()` 已写。对 virus/bacteria 主路径成立。
- 若未来 strategy 漏写，会出现 “exit 1 但无 JSON” 回归洞。

建议（下阶段，非本阶段改码）：runner 在 catch 时若缺 JSON 则调用 `write_error_analysis_result`（需已知 organism_type / output）。

---

## 5. 风险与缺口汇总

| ID | 风险 | 严重度 | 建议 |
|----|------|--------|------|
| E1 | virus 无 DNA / 最少序列预检 | 中 | Hardening 后抽共享预检或 virus 对齐最低条数 |
| E2 | virus metadata 缺列仅 warning | 低 | 文档化；或提供 `--strict-metadata` |
| E3 | viz 失败 = partial/exit0 | 低（产品） | 保持；在矩阵标为 soft |
| E4 | 磁盘写失败可能无 JSON | 中 | runner 兜底 + 测试只读目录 |
| E5 | registry/策略加载失败无 JSON | 低 | runner 兜底 |
| E6 | bacteria/virus `fail_with_error_json` 重复 | 中 | 抽 core（架构审计 D1） |

**未发现**需立即改 `engine/` 或 virus/bacteria strategy 的严重 bug（错误主路径与 tip mismatch 覆盖已验证）。

---

## 6. 与回归覆盖的对应

| 审计场景 | 是否在 `run_framework_regression.R` |
|----------|-------------------------------------|
| virus valid | 是 |
| virus bad fasta | 是 |
| virus tip mismatch | 是 |
| bacteria valid | 是 |
| bacteria metadata missing | 是 |
| bacteria tip mismatch | 是 |
| empty / illegal_dna / too_few | 夹具有，**未**纳入六案 |
| tree/viz/disk 专项 | 否 |

完整期望表见 [`framework_test_matrix.md`](framework_test_matrix.md)。

---

## 7. 结论

- virus / bacteria **主失败路径**（存在性、格式、metadata 强制项、tip、建树）满足：`exit=1` + `status=error` + `error_message` + `statistics` object。
- **可视化失败**按 `partial` 设计，不视为硬错误。
- **类型不对称**（DNA/条数/metadata 严格度）需在文档与测试矩阵中显式列出，避免误判为缺陷。
- Hardening 优先：runner JSON 兜底、共享错误包装、把 bacteria 已有夹具纳入矩阵；**无需**为接 archaea 先改生产 strategy。
