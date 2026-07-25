# 输入约定（input/）

统一任务输入布局：

```text
input/
├── sequence.fasta
└── metadata.csv
```

本目录提供：

| 路径 | 用途 |
|------|------|
| `templates/*.csv` | 各生物类型 metadata 表头模板 |
| `examples/` | 预留小型示例（不含大规模基准数据） |

大规模 H3N2 基准仍使用：

- `data/benchmarks/h3n2_ha/`
- `output/benchmarks/h3n2_ha/`

字段定义见 [`../metadata/metadata_schema.md`](../metadata/metadata_schema.md)。

CLI 示例：

```bash
Rscript runners/run_analysis.R \
  --type virus \
  --fasta input/sequence.fasta \
  --metadata input/metadata.csv \
  --output output/tasks/demo_run
```
