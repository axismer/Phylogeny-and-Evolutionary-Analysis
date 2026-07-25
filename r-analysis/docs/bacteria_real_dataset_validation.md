# Bacteria 真实用户数据验证报告

**日期:** 2026-07-24  
**目标:** 验证 bacteria pipeline 不仅能跑内部 benchmark，还能以「真实用户提交」形态的 16S 数据完整跑通。  
**约束:** 未修改建树 / 可视化算法（未改 `engine/`、virus strategy、tree builder 算法）。

---

## 1. 结论

| 检查项 | 结果 |
|--------|------|
| Exit code | **0** |
| `analysis_result.json` `status` | **success** |
| `organism_type` | **bacteria** |
| `tree.nwk` | 已生成（35 tips，含有效 branch length） |
| `circular_tree_final.png` | 已生成（≈586 KB） |
| tip ↔ metadata 匹配率 | **100%**（0 missing / 0 extra） |

**总评:** 真实 NCBI RefSeq 16S 数据以用户风格 `sample_id`（`S001`…）提交后，统一 CLI `--type bacteria` 可完整成功运行。

---

## 2. 数据来源与准备

### 2.1 下载

| 项 | 值 |
|----|-----|
| 来源 | NCBI Nucleotide（RefSeq 16S rRNA） |
| 接口 | E-utilities `efetch` |
| URL | `https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nuccore&id=…&rettype=fasta&retmode=text` |
| 原始文件 | `data/real/bacteria_16s_user/_ncbi_download.fasta` |
| 下载条数 | **35** |

### 2.2 用户数据形态（与 benchmark 的区别）

| 对比 | 内部 benchmark (`data/benchmarks/bacteria_16s`) | 本真实用户集 |
|------|-----------------------------------------------|--------------|
| Tip / sample_id | NCBI accession（如 `NR_074540`） | 用户风格 **`S001`…`S035`** |
| 路径 | benchmark 目录 | `data/real/bacteria_16s_user/` |
| 用途 | 回归基准 | 模拟真实用户上传 |

准备脚本（仅数据整理，不改算法）:

```text
scripts/prep/prepare_bacteria_16s_user_real.R
```

产出:

```text
data/real/bacteria_16s_user/
  _ncbi_download.fasta   # NCBI 原始下载
  sequences.fasta        # 用户提交 FASTA（header = sample_id）
  metadata.csv           # 用户提交 metadata
  SOURCE.txt             # 溯源说明
```

### 2.3 Metadata 字段

用户要求最低字段 + pipeline 必需扩展:

| 字段 | 是否具备 | 说明 |
|------|----------|------|
| `sample_id` | 是 | 与 FASTA tip 1:1 |
| `taxonomy` | 是 | 属级（自 NCBI header 解析） |
| `environment` | 是 | clinical / environmental / food / marine / soil |
| `source` | 是 | `isolate` |
| `resistance` | 是 | BacteriaStrategy schema 必需；由物种启发式标注 |
| `organism_type` | 是 | 固定 `bacteria` |
| `accession` | 是 | 保留 NCBI 号便于溯源（非建树必需） |

环境分布（35 条）:

| environment | n |
|-------------|---|
| environmental | 22 |
| clinical | 6 |
| soil | 3 |
| food | 2 |
| marine | 2 |

序列长度: min=1369，median=1501，max=1646 bp（典型近全长 16S）。

---

## 3. 运行命令

```bash
cd r-analysis

Rscript runners/run_analysis.R \
  --type bacteria \
  --fasta data/real/bacteria_16s_user/sequences.fasta \
  --metadata data/real/bacteria_16s_user/metadata.csv \
  --output output/tasks/bacteria_real_user_run
```

运行日志要点:

```text
[BacteriaStrategy] 16S 长度启发式通过（median=1501 bp）；未做物种分类鉴定。
[run_analysis] status=success
```

---

## 4. 结果检查

### 4.1 Exit / JSON

| 项 | 值 |
|----|-----|
| Exit code | `0` |
| `status` | `success` |
| `organism_type` | `bacteria` |
| `tree_file` | `tree.nwk` |
| `visualization` | `circular_tree_final.png` |
| `metadata` | `metadata.csv` |
| `sequence_count` | `35` |
| `method` / `model` | Maximum Likelihood / JC69 |

`analysis_result.json` 摘录:

```json
{
  "status": "success",
  "organism_type": "bacteria",
  "tree_file": "tree.nwk",
  "visualization": "circular_tree_final.png",
  "metadata": "metadata.csv",
  "statistics": {
    "sequence_count": 35,
    "method": "Maximum Likelihood",
    "model": "JC69",
    "annotation_rings": ["taxonomy", "environment", "resistance"]
  }
}
```

### 4.2 产物文件

```text
output/tasks/bacteria_real_user_run/
  analysis_result.json
  tree.nwk
  tree.png
  distance_matrix.csv
  metadata.csv
  circular_tree_final.png
  circular_tree_final.pdf
  visualization_report.json
```

### 4.3 Metadata 匹配率

| 指标 | 值 |
|------|-----|
| tips | 35 |
| metadata 行（对齐后） | 35 |
| tip 在 metadata 中缺失 | 0 |
| metadata 多余 id | 0 |
| **匹配率** | **100%** |

### 4.4 树与可视化

| 检查 | 结果 |
|------|------|
| `tree.nwk` 可读 | 是 |
| `edge.length` 有效 | 是 |
| `circular_tree_final.png` | 存在（≈586148 bytes） |
| `circular_tree_final.pdf` | 存在 |
| 环图字段 | taxonomy / environment / resistance |

---

## 5. 与 benchmark 验证的关系

| 验证 | 路径 | 结论 |
|------|------|------|
| Benchmark / 负向夹具 | `docs/bacteria_validation_report.md` | 生产接口与错误状态 |
| **真实用户数据（本报告）** | `data/real/bacteria_16s_user/` | 非 accession tip、真实 NCBI 序列可跑通 |

两者互补：前者证明契约与失败语义；本报告证明 **真实公开 16S + 用户 sample_id** 可走完整 success pipeline。

---

## 6. 复现步骤

```bash
cd r-analysis

# （可选）重新下载并整理用户数据
# PowerShell: Invoke-WebRequest 至 data/real/bacteria_16s_user/_ncbi_download.fasta
Rscript scripts/prep/prepare_bacteria_16s_user_real.R

Rscript runners/run_analysis.R \
  --type bacteria \
  --fasta data/real/bacteria_16s_user/sequences.fasta \
  --metadata data/real/bacteria_16s_user/metadata.csv \
  --output output/tasks/bacteria_real_user_run
```

---

## 7. 验收对照

| 需求 | 状态 |
|------|------|
| 下载或准备真实 16S dataset | 完成（NCBI RefSeq，35 条） |
| FASTA + metadata.csv | 完成 |
| metadata 含 sample_id / taxonomy / environment / source | 完成（另含 resistance 以满足 strategy schema） |
| `run_analysis.R --type bacteria` 完整 pipeline | 完成，`exit=0`，`status=success` |
| 检查 tree / png / JSON / 匹配率 | 全部通过（匹配率 100%） |
| 生成本报告 | 完成 |
| 不修改算法 | 遵守 |
