# Bacteria Strategy 生产接口验证报告

**日期:** 2026-07-24  
**范围:** `BacteriaPhyloStrategy` 统一 CLI（`runners/run_analysis.R --type bacteria`）  
**约束:** 未修改 `engine/`、`strategies/virus/`、tree builder 算法；本报告仅记录测试与评估结论。

---

## 1. 结论摘要

| 项 | 结果 |
|----|------|
| 生产 CLI 入口可用 | **通过** — `--type bacteria` 可独立调度，非仅依赖 H3N2/benchmark 硬编码路径 |
| Happy path（valid） | **通过** — `exit=0`，`status=success`，树 / 距离矩阵 / 环图齐全 |
| tip ↔ metadata 100% 匹配 | **通过**（valid） |
| 负向输入拒绝 | **通过** — tip 不匹配、缺字段、非法 DNA、空文件、序列过少均 `exit=1` |
| Virus / H3N2 隔离 | **通过** — virus smoke `exit=0`；H3N2 benchmark PNG mtime 未变 |
| 已知生产风险 | **有** — tip 不匹配失败时，目录内可能残留 legacy `analysis_result.json` 且 `status=success`（见 §5） |

**总评:** Bacteria 模块已具备可调用的生产接口能力（统一 CLI + 校验 + 建树委托 + 独立可视化）。负向用例拦截正确；需注意 tip 对齐失败时的结果 JSON 残留问题。

---

## 2. 测试数据

根目录: `r-analysis/test-data/bacteria/`

| 用例目录 | 意图 | 内容 |
|----------|------|------|
| `valid/` | 合法 FASTA + metadata | 6 条真实 RefSeq 16S（自 `data/benchmarks/bacteria_16s` 裁剪）；`sample_id` = tip |
| `tip_mismatch/` | FASTA tip 与 metadata 不匹配 | 相同 FASTA；metadata `sample_id` 全部加 `BAD_` 前缀 |
| `missing_fields/` | 缺少必需 metadata 字段 | 去掉 `resistance` 列 |
| `illegal_dna/` | 非法 DNA 字符 | 第 1 条序列注入 `XXXX` |
| `empty/` | 空 FASTA | 0 字节序列文件 |
| `too_few/` | 少于最小序列数 | 仅 2 条序列 |

输出根目录: `r-analysis/output/tasks/bacteria_validation/<case>/`

---

## 3. CLI 执行矩阵

统一命令形态:

```bash
Rscript runners/run_analysis.R \
  --type bacteria \
  --fasta <fasta> \
  --metadata <metadata.csv> \
  --output output/tasks/bacteria_validation/<case>
```

| Case | Exit code | CLI `status=` | `analysis_result.json` | Error message（核心） |
|------|-----------|---------------|------------------------|----------------------|
| `valid` | **0** | `success` | 存在；`status=success`，`organism_type=bacteria` | （无） |
| `tip_mismatch` | **1** | （未打印 success） | **残留** legacy JSON，`status=success`（建树阶段写出，失败后未覆盖） | `BacteriaStrategy: metadata sample_id/label 与 tree tip 不匹配，缺失: NR_044887, …` |
| `missing_fields` | **1** | — | 缺失（未进入建树） | `Bacteria metadata 缺少必需列: resistance` |
| `illegal_dna` | **1** | — | 缺失 | `BacteriaStrategy: DNA 字符合法性失败，发现: X` |
| `empty` | **1** | — | 缺失 | `BacteriaStrategy: 至少需要 3 条序列，当前: 0` |
| `too_few` | **1** | — | 缺失 | `BacteriaStrategy: 至少需要 3 条序列，当前: 2` |

### 3.1 valid — `analysis_result.json`（摘录）

```json
{
  "status": "success",
  "organism_type": "bacteria",
  "tree_file": "tree.nwk",
  "visualization": "circular_tree_final.png",
  "metadata": "metadata.csv",
  "statistics": {
    "sequence_count": 6,
    "method": "Maximum Likelihood",
    "model": "JC69",
    "annotation_rings": ["taxonomy", "environment", "resistance"]
  },
  "matrix_file": "distance_matrix.csv",
  "image_file": "tree.png"
}
```

### 3.2 tip_mismatch — 残留 JSON（问题证据）

进程以 `exit=1` 失败，但输出目录中仍有引擎写出的:

```json
{
  "input": "sequences.fasta",
  "sequence_count": 6,
  "method": "Maximum Likelihood",
  "model": "JC69",
  "status": "success",
  "tree_file": "tree.nwk",
  "matrix_file": "distance_matrix.csv",
  "image_file": "tree.png"
}
```

**含义:** 若上游（如 Spring Boot）只读 `analysis_result.json.status` 而不看进程 exit code，会误判为成功。建议后续在 tip 校验失败分支写回 `status=error` 的统一结果（本次验证按约束未改代码）。

---

## 4. 成功路径产物校验（valid）

| 检查项 | 结果 |
|--------|------|
| tip label ↔ metadata `label`/`sample_id` 100% 匹配 | **通过**（6/6） |
| `tree.nwk` 生成且含有效 `edge.length` | **通过** |
| `distance_matrix.csv` | **通过** |
| `circular_tree_final.png` | **通过**（≈321 KB） |
| `circular_tree_final.pdf` | **通过** |
| `visualization_report.json` | **通过**；`annotation_rings = taxonomy, environment, resistance`；`geom_fruit` |
| `organism_type` | `bacteria`（非 virus 泄漏） |

产物文件:

```
output/tasks/bacteria_validation/valid/
  analysis_result.json
  circular_tree_final.png
  circular_tree_final.pdf
  distance_matrix.csv
  metadata.csv
  tree.nwk
  tree.png
  visualization_report.json
```

---

## 5. 生产接口能力评估

### 5.1 已具备

1. **统一入口:** `--type bacteria` 经 `strategy_registry` → `create_bacteria_strategy()`，与 virus 同级调度。  
2. **输入契约:** FASTA 存在性、序列数 ≥3、DNA IUPAC、长度启发式（warning）、16S 中位长度 warning（不强制分类）。  
3. **Metadata 契约:** 强制 `--metadata`；必需列 `sample_id, taxonomy, environment, source, resistance`。  
4. **建树:** 委托冻结 `engine/phylogenetic_tree.R`（未复制算法）。  
5. **可视化:** 独立 `strategies/bacteria/bacteria_visualization.R`（未改 virus ggtree）。  
6. **输出契约:** 与 virus 升级后的统一 `analysis_result.json` 字段兼容。

### 5.2 风险与缺口

| 级别 | 项 | 说明 |
|------|----|------|
| **高** | tip 不匹配后的 stale JSON | exit=1，但 JSON 仍可能为 `success`；生产集成必须以 **exit code 优先**，或后续补写 error JSON |
| 中 | tip 校验发生在建树之后 | 浪费算力；可考虑建树前做 FASTA id ∩ metadata 预检（未改） |
| 低 | 空文件与 too_few 共用同一错误文案 | 行为正确，但可区分“空文件 / 格式无效 / 条数不足”以利运维 |

---

## 6. Virus / H3N2 影响检查

| 检查 | 结果 |
|------|------|
| `Rscript runners/run_analysis.R --type virus --fasta test-data/fixtures/h3n2_na_20.fasta --output …/virus_smoke` | `exit=0`，`status=success`，`organism_type=virus` |
| `output/benchmarks/h3n2_ha/circular_tree_final.png` mtime | **未变化**（before = after = `2026-07-24T07:11:50Z`） |
| Bacteria 用例是否写入 H3N2 目录 | **否**（仅写入 `output/tasks/bacteria_validation/`） |

结论: bacteria 验证运行 **不影响** virus pipeline 与冻结 H3N2 benchmark 产物。

---

## 7. Visualization 专业性：taxonomy 层级评估

### 7.1 现状

- 环 1 使用单一字段 `taxonomy`。  
- Benchmark 预处理将 NCBI 头解析为 **属（genus）** 级，避免“1 tip ≈ 1 物种色块”。  
- 在 44 tip 基准上: **unique genus = 39**（比例 ≈ 0.89），图例仍偏长。

### 7.2 是否应增加 phylum / class / genus 三层选择？

| 方案 | 优点 | 缺点 | 建议 |
|------|------|------|------|
| **仅 genus（现状）** | 实现简单；与 tip 分辨率接近 | 多样本时图例爆炸；难读“门级”群落结构 | 适合 ≤15 tip 冒烟 |
| **可选 `taxonomy_level=phylum\|class\|genus`** | 同一批数据可切换环粒度；大树用 phylum/class，细节用 genus | 需 NCBI/GTDB 注释源或额外列；CLI/配置扩展 | **已实现**（见 `docs/bacteria_taxonomy_level.md`） |
| **三环同时画 phylum+class+genus** | 信息密度高 | 与现有 environment/resistance 环冲突（已 3 环）；视觉过载 | 不推荐默认开启 |
| **双模式：粗粒度环 + tip 标签 genus** | 专业微生物组图常见做法 | 实现稍复杂 | 大样本（≥30）首选 |

### 7.3 评估结论

1. **第一版:** `taxonomy` 作为默认 annotation 字段保留；旧 metadata 不改即可跑。  
2. **层级选择（已落地）:**  
   - metadata 可选列: `phylum`, `class`, `order`, `family`, `genus`, `species`；  
   - `strategies.bacteria.taxonomy_level`（yaml 推荐 `genus`；代码缺省 `taxonomy`）；  
   - 可视化环 1 绑定所选列；缺列回退 `taxonomy`。  
3. **不必** 三层同时上环；保留 environment / resistance。  
4. 注释来源仍建议 GTDB / NCBI Taxonomy（框架不自动鉴定）。

---

## 8. 复现步骤

```bash
cd r-analysis

# valid
Rscript runners/run_analysis.R \
  --type bacteria \
  --fasta test-data/bacteria/valid/valid.fasta \
  --metadata test-data/bacteria/valid/metadata.csv \
  --output output/tasks/bacteria_validation/valid

# 负向示例（期望 exit 1）
Rscript runners/run_analysis.R \
  --type bacteria \
  --fasta test-data/bacteria/illegal_dna/sequences.fasta \
  --metadata test-data/bacteria/illegal_dna/metadata.csv \
  --output output/tasks/bacteria_validation/illegal_dna

# virus 隔离冒烟
Rscript runners/run_analysis.R \
  --type virus \
  --fasta test-data/fixtures/h3n2_na_20.fasta \
  --output output/tasks/bacteria_validation/virus_smoke
```

---

## 9. 验收对照

| 需求 | 状态 |
|------|------|
| 创建 `test-data/bacteria/` 多类夹具 | 完成 |
| 每案执行 `--type bacteria` 并记录 exit / status / error / JSON | 完成 |
| tip 100% 匹配、tree.nwk、circular PNG | valid 通过 |
| 不影响 virus | 通过 |
| taxonomy 层级评估 | 见 §7；`taxonomy_level` 已实现（`docs/bacteria_taxonomy_level.md`） |
| 不改 engine / virus / tree builder | 遵守；仅新增测试数据与本报告 |

---

## 10. 后续建议（非本次改动）

1. tip 对齐失败时 **覆盖写入** `analysis_result.json`（`status=error`）。  
2. 建树前做 FASTA id ∩ metadata 预检。  
3. 可视化 `taxonomy_level` 已可选；大样本可配置 `phylum` / `class`。  
4. 将本目录夹具接入 CI（期望 exit code 表驱动）。
