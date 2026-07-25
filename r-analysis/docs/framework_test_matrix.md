# Framework Test Matrix — v0.1

> 日期：2026-07-24  
> 入口：`runners/run_analysis.R`  
> 回归脚本：`scripts/runners/run_framework_regression.R`  
> 契约：[`analysis_result_contract.md`](analysis_result_contract.md)

说明：

- `expected status`：`analysis_result.json.status`
- `expected exit`：进程码
- **Coverage**：`yes` = 已在框架回归六案；`fixture` = 有夹具未进六案；`gap` = 无自动化；`n/a` = 类型不适用

---

## 1. 主矩阵

| type | case | expected status | expected exit | error_message 含 | Coverage |
|------|------|-----------------|---------------|------------------|----------|
| virus | valid | success（或 partial） | 0 | （空） | **yes** |
| virus | bad fasta / invalid fasta | error | 1 | `FASTA` | **yes** |
| virus | metadata mismatch / tip mismatch | error | 1 | `不匹配` | **yes** |
| virus | fasta missing | error | 1 | `不存在` | gap |
| virus | fasta empty | error | 1 | `FASTA` / 格式 | fixture* |
| virus | metadata file missing | error | 1 | `metadata 不存在` | gap |
| virus | metadata optional omitted | success/partial | 0 | （空） | gap |
| virus | illegal DNA | error 或 success† | 1 或 0 | （engine 依赖） | gap |
| virus | too few sequences | error 或 engine 失败 | 1 | （未统一） | gap |
| virus | tree engine fail | error | 1 | `建树失败` | gap |
| virus | visualization fail | **partial** | **0** | （空） | gap |
| bacteria | valid | success（或 partial） | 0 | （空） | **yes** |
| bacteria | metadata missing fields | error | 1 | `resistance` 等 | **yes** |
| bacteria | tip mismatch | error | 1 | `不匹配` | **yes** |
| bacteria | fasta missing | error | 1 | `不存在` | gap |
| bacteria | fasta empty | error | 1 | `至少需要 3` | **fixture** |
| bacteria | illegal DNA | error | 1 | `DNA 字符合法性` | **fixture** |
| bacteria | too few sequences | error | 1 | `至少需要 3` | **fixture** |
| bacteria | metadata file missing | error | 1 | `metadata 不存在` | gap |
| bacteria | metadata omitted | error | 1 | `要求提供 --metadata` | gap |
| bacteria | tree engine fail | error | 1 | `建树失败` | gap |
| bacteria | visualization fail | **partial** | **0** | （空） | gap |
| archaea | any run | not_implemented | 2 | （空） | gap |
| eukaryote | any run | not_implemented | 2 | （空） | gap |

\* empty 对 virus：用 `invalid_fasta` 近似（非空但无 `>`）；真正 0 字节文件未单列。  
† virus 不对碱基做 strategy 预检，见 [`error_handling_audit.md`](error_handling_audit.md)。

---

## 2. 契约形状断言（所有 error / success 案）

无论 case，最终 JSON **必须**含：

`status`, `organism_type`, `input`, `tree`, `visualization`, `metadata`, `statistics`, `error_message`

| 条件 | 额外断言 |
|------|----------|
| status=error | `error_message` 非空；`statistics` 为 object（非 `[]`） |
| status=success/partial | `error_message==""`；通常 `tree=="tree.nwk"` |
| status=partial | 常有 `visualization==""` |
| status=not_implemented | exit 2 |

回归脚本已对六案做形状检查。

---

## 3. 夹具路径

| type | case | fasta | metadata |
|------|------|-------|----------|
| virus | valid | `test-data/virus/valid/sequences.fasta` | `.../metadata.csv` |
| virus | bad fasta | `test-data/virus/invalid_fasta/bad.fasta` | — |
| virus | tip mismatch | `test-data/virus/metadata_mismatch/sequences.fasta` | `.../metadata.csv` |
| bacteria | valid | `test-data/bacteria/valid/valid.fasta` | `.../metadata.csv` |
| bacteria | metadata missing | `test-data/bacteria/missing_fields/sequences.fasta` | `.../metadata.csv` |
| bacteria | tip mismatch | `test-data/bacteria/tip_mismatch/sequences.fasta` | `.../metadata.csv` |
| bacteria | empty | `test-data/bacteria/empty/empty.fasta` | `.../metadata.csv` |
| bacteria | illegal DNA | `test-data/bacteria/illegal_dna/sequences.fasta` | `.../metadata.csv` |
| bacteria | too few | `test-data/bacteria/too_few/sequences.fasta` | `.../metadata.csv` |

---

## 4. 当前自动化结果（冻结回归）

来源：`output/tasks/framework_v01_regression/summary.json`（2026-07-24）

| type | case | expected | result |
|------|------|----------|--------|
| virus | valid | success / exit 0 | **PASS** |
| virus | bad fasta | error / exit 1 | **PASS** |
| virus | metadata mismatch | error / exit 1 | **PASS** |
| bacteria | valid | success / exit 0 | **PASS** |
| bacteria | metadata missing | error / exit 1 | **PASS** |
| bacteria | tip mismatch | error / exit 1 | **PASS** |

**Passed 6 / 6**

复跑：

```bash
cd r-analysis
Rscript scripts/runners/run_framework_regression.R
```

---

## 5. Hardening 建议增补（不改生产 strategy 语义）

按优先级把 **fixture → yes**：

1. bacteria `empty` / `illegal_dna` / `too_few`  
2. archaea / eukaryote `not_implemented` smoke（exit 2 + JSON）  
3. virus 无 metadata 的 valid  
4. （可选）只读 output 目录模拟磁盘失败  

实现方式：只扩 `run_framework_regression.R` 与夹具，避免改 `engine/` / virus / bacteria strategy。
