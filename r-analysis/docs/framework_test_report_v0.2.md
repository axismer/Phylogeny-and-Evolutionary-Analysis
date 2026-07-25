# Framework Test Report v0.2

> 日期：2026-07-24  
> 命令：`Rscript scripts/runners/run_framework_regression.R`  
> 输出：`output/tasks/framework_v02_regression/summary.json`  
> 结果：**Passed 13 / 13**（exit 0）

---

## 1. Command

```bash
cd r-analysis
Rscript scripts/runners/run_framework_regression.R
```

- Regression exit code: **0**
- Suite result: **PASS**

---

## 2. Case results

| case_id | type | expect exit | expect status | actual exit | actual status | result |
|---------|------|-------------|---------------|-------------|---------------|--------|
| virus_valid | virus | 0 | success\|partial | 0 | success | PASS |
| virus_invalid_fasta | virus | 1 | error | 1 | error | PASS |
| virus_metadata_mismatch | virus | 1 | error | 1 | error | PASS |
| virus_empty | virus | 1 | error | 1 | error | PASS |
| virus_illegal_dna | virus | 1 | error | 1 | error | PASS |
| virus_too_few | virus | 1 | error | 1 | error | PASS |
| bacteria_valid | bacteria | 0 | success\|partial | 0 | success | PASS |
| bacteria_invalid_metadata | bacteria | 1 | error | 1 | error | PASS |
| bacteria_tip_mismatch | bacteria | 1 | error | 1 | error | PASS |
| bacteria_empty | bacteria | 1 | error | 1 | error | PASS |
| bacteria_illegal_dna | bacteria | 1 | error | 1 | error | PASS |
| bacteria_too_few | bacteria | 1 | error | 1 | error | PASS |
| archaea_not_implemented | archaea | 2 | not_implemented | 2 | not_implemented | PASS |

---

## 3. Assertions per case

对每个 case 验证：

1. 进程 exit code  
2. `analysis_result.json` 存在  
3. 契约必须字段（含 `statistics` object、`error_message`）  
4. `status` 符合期望  
5. error 案：`error_message` 含关键字（FASTA / DNA / 不匹配 / resistance / 至少需要 3）

---

## 4. Regression vs v0.1

| 集合 | v0.1 | v0.2 |
|------|------|------|
| virus valid / bad fasta / tip mismatch | ✓ | ✓ |
| bacteria valid / metadata / tip mismatch | ✓ | ✓ |
| virus empty / illegal_dna / too_few | — | ✓ |
| bacteria empty / illegal_dna / too_few | fixture only | ✓ |
| archaea not_implemented | — | ✓ |

---

## 5. Notes

- virus 边缘预检（empty / DNA / too_few）为 v0.2 hardening 对齐；**valid 成功路径语义不变**。  
- tip mismatch 文案前缀仍为各 Strategy 原有中文前缀（经 `message_prefix`）。  
- archaea 仅验证 stub：`status=not_implemented` + exit 2；**未实现**完整 pipeline。
