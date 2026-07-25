# Bacteria `taxonomy_level` 配置设计

> 版本：`v0.1`  
> 日期：2026-07-24  
> 范围：仅 bacteria 可视化环 1 字段选择；**不**实现分类鉴定；**不**改 `engine/`；**不**影响 virus。

---

## 1. 目标

在不改变现有默认 annotation 行为的前提下，允许用户通过配置选择环图分类粒度。

| 约束 | 说明 |
|------|------|
| 默认行为不变 | 环 1 默认仍用 metadata 列 `taxonomy` |
| 可选层级列 | metadata 可含 `phylum` / `class` / `order` / `family` / `genus` / `species` |
| 配置驱动 | `analysis_config.yaml` → `strategies.bacteria.taxonomy_level` |
| 旧表兼容 | 无层级列时回退 `taxonomy` |
| 非目标 | 分类算法、GTDB/NCBI 自动注释、engine / virus 改动 |

---

## 2. 配置

```yaml
# config/analysis_config.yaml
strategies:
  bacteria:
    taxonomy_level: genus   # 推荐值；代码缺省（无本键）为 taxonomy
    annotation:
      rings: ["taxonomy_level", "environment", "resistance"]
```

允许值：`phylum` | `class` | `order` | `family` | `genus` | `species` | `taxonomy`。

| 来源 | 缺省 |
|------|------|
| 代码（无 yaml 键 / 非法值） | `taxonomy` |
| 仓库自带 yaml | `genus`（推荐） |

---

## 3. 字段解析（环 1）

```text
requested = normalize(taxonomy_level)

if requested == "taxonomy":
    field = "taxonomy"
elif requested in metadata.columns:
    field = requested
elif "taxonomy" in metadata.columns:
    field = "taxonomy"          # fallback；旧 metadata
else:
    error
```

`bacteria_visualization.R` 与 `bacteria_annotation.R` 共用同一规则；strategy `run()` 把解析后的 `taxonomy_level` 传给可视化 CLI 第 4 参。

---

## 4. Metadata 契约

**必需（不变）**：`sample_id`, `taxonomy`, `environment`, `source`, `resistance`  
（统一 schema 另需 `organism_type`。）

**可选**：`phylum`, `class`, `order`, `family`, `genus`, `species`  
— 用户自备；校验不强制；框架不填充。

旧 CSV（仅有 `taxonomy`）在 `taxonomy_level: genus` 下仍成功：环 1 = `taxonomy`，`taxonomy_ring_fallback=true`。

模板：`input/templates/bacteria_metadata.csv`（含可选层级列头）。

---

## 5. 模块职责

| 模块 | 职责 |
|------|------|
| `config/analysis_config.yaml` | 声明 `taxonomy_level` |
| `strategies/bacteria/bacteria_annotation.R` | resolve / map / annotation_config |
| `strategies/bacteria/bacteria_strategy.R` | 读配置 → 写出 metadata → 调 viz |
| `strategies/bacteria/bacteria_visualization.R` | 按 level 选环 1 fill 字段 |
| `metadata/metadata_validator.R` | 层级列可选、不进 strict 必需集 |
| `engine/*` | **不动** |
| `strategies/virus/*` | **不动** |

---

## 6. 结果字段

`analysis_result.json` / `visualization_report.json` 可含：

- `statistics.taxonomy_level` — 请求的粒度  
- `statistics.taxonomy_ring_field` — 实际环 1 列名  
- `taxonomy_ring_fallback`（viz report）— 是否回退到 `taxonomy`

---

## 7. 验收要点

1. 旧 metadata（无 genus 等）+ 默认流水线 → 环 1 仍为 `taxonomy`，任务成功。  
2. 新 metadata（含 `genus`）+ `taxonomy_level: genus` → 环 1 为 `genus`。  
3. `taxonomy_level: taxonomy` → 强制用 `taxonomy`。  
4. virus 路径与 `engine/` 行为不变。  
5. 无任何自动分类推断。
