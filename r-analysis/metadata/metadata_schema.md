# Metadata Schema — 多生物类型统一规范

> 版本：`v0.1-framework`  
> 日期：2026-07-24  
> 状态：架构约定（Virus 生产路径仍兼容旧列 `label,Country,Year[,Host]`）

---

## 1. 输入目录约定

推荐任务输入布局：

```text
input/
├── sequence.fasta
└── metadata.csv
```

Spring Boot / CLI 也可分别传入绝对路径（不必物理放在 `input/`）。

---

## 2. 核心必需字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `sample_id` | string | 与 FASTA tip / header（去 `>`）对齐的唯一 ID |
| `organism_type` | enum | `virus` \| `bacteria` \| `archaea` \| `eukaryote` |

约束：

- 同一文件内 `organism_type` 必须唯一且与 CLI `--type` 一致
- `sample_id` 非空、唯一
- `sample_id` 应能映射到树 tip label（Virus 迁移期可用 `virus_annotation.R` 映射到 `label`）

---

## 3. 公共可选字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `collection_date` | string | 推荐 ISO `YYYY-MM-DD`；也可 `YYYY` |
| `location` | string | 地理/采样地（国家、区域、站点等） |
| `host` | string | 宿主；环境样本可为 `NA` / `environmental` |

---

## 4. 类型扩展字段

### 4.1 Virus

| 字段 | 类型 | 说明 |
|------|------|------|
| `segment` | string | 节段（如 `HA`, `NA`）；非节段病毒可空 |
| `variant` | string | 谱系 / clade / 变异标签 |

**与现有 H3N2 可视化兼容映射**（`strategies/virus/virus_annotation.R`）：

| 统一字段 | 旧 ggtree 列 |
|----------|--------------|
| `sample_id` | `label` |
| `location` | `Country` |
| `collection_date` | `Year`（取前 4 位） |
| `host` | `Host` |

现有基准 `output/benchmarks/h3n2_ha/metadata.csv`（`label,Country,Year,Host`）**无需立刻改写**；统一 schema 用于新上传任务。

### 4.2 Bacteria

| 字段 | 类型 | 说明 |
|------|------|------|
| `taxonomy` | string | **默认 / 兼容** annotation 字段；旧 metadata 必需；可为属名或任意分类标签 |
| `environment` | string | 采样环境（soil / clinical / marine …） |
| `source` | string | 样本来源（isolate / metagenome …） |
| `resistance` | string | 抗性相关标注（可空） |

**可选分类层级列**（框架不推断、不跑分类算法；由用户自备）：

| 字段 | 类型 | 说明 |
|------|------|------|
| `phylum` / `class` / `order` / `family` / `genus` / `species` | string | 可选 |

配置 `strategies.bacteria.taxonomy_level`（见 `config/analysis_config.yaml`，推荐 `genus`）选择环 1 字段：

| `taxonomy_level` | 环 1 行为 |
|------------------|-----------|
| （缺省 / 未配置） | `taxonomy`（保持现有默认 annotation） |
| `taxonomy` | 使用 `taxonomy` |
| `phylum`…`species` | 若列存在用该列；否则回退 `taxonomy` |

详见 [`docs/bacteria_taxonomy_level.md`](../docs/bacteria_taxonomy_level.md)。
### 4.3 Archaea

| 字段 | 类型 | 说明 |
|------|------|------|
| `taxonomy` | string | 分类 |
| `habitat` | string | 生境 |
| `temperature` | number/string | 最适/采样温度（℃） |
| `salinity` | number/string | 盐度 |

### 4.4 Eukaryote

| 字段 | 类型 | 说明 |
|------|------|------|
| `taxonomy` | string | 分类 |
| `location` | string | 与公共字段同名；建议填写更细粒度地点 |
| `host` | string | 寄生/共生宿主（若适用） |
| `life_stage` | string | 生活史阶段 |

> 注：Eukaryote 的 `location` / `host` 同时属于公共字段与扩展语义；CSV 中只出现一次即可。

---

## 5. 示例 CSV

### Virus

```csv
sample_id,organism_type,collection_date,location,host,segment,variant
A_New_Mexico_02_2024,virus,2024-01-15,Americas,Human,HA,3C.2a1b
A_Gyeonggi_USAFSAM_14892_2024,virus,2024-02-01,Asia,Human,HA,3C.2a1b
```

### Bacteria

```csv
sample_id,organism_type,collection_date,location,host,taxonomy,phylum,class,order,family,genus,species,environment,source,resistance
ISO_001,bacteria,2023-06-01,Hospital_A,Human,Escherichia coli,Pseudomonadota,Gammaproteobacteria,Enterobacterales,Enterobacteriaceae,Escherichia,Escherichia coli,clinical,isolate,ESBL
ENV_014,bacteria,2023-07-12,River_X,NA,Pseudomonas sp.,Pseudomonadota,Gammaproteobacteria,Pseudomonadales,Pseudomonadaceae,Pseudomonas,,aquatic,metagenome,
```

旧表可仅含 `taxonomy`（无层级列），与 `taxonomy_level: genus` 兼容（环 1 回退 `taxonomy`）。

### Archaea

```csv
sample_id,organism_type,collection_date,location,host,taxonomy,habitat,temperature,salinity
ARC_01,archaea,2022-08-01,Yellowstone,NA,Sulfolobus,hot_spring,80,low
```

### Eukaryote

```csv
sample_id,organism_type,collection_date,location,host,taxonomy,life_stage
EUK_01,eukaryote,2021-05-20,Amazon,NA,Plasmodium falciparum,blood_stage
```

---

## 6. 校验规则（`metadata_validator.R`）

| 规则 | 级别 |
|------|------|
| 存在 `sample_id`, `organism_type` | error |
| `sample_id` 唯一非空 | error |
| `organism_type` 单值且匹配 `--type` | error |
| 类型扩展列缺失 | warning（`strict=TRUE` 时为 error） |
| 未知列 | 允许保留（透传） |

---

## 7. 与 `analysis_result.json` 的关系

成功任务在输出目录写入：

```json
{
  "status": "success",
  "organism_type": "virus",
  "tree_file": "tree.nwk",
  "visualization": "circular_tree_final.png",
  "metadata": "metadata.csv",
  "statistics": { }
}
```

`metadata` 字段指向输出目录内规范化后的 metadata 文件名（通常即 `metadata.csv`）。
