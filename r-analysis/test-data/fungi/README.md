# Fungi ITS regression fixtures

> Framework v0.3 P5

| case | 说明 |
|------|------|
| `valid/` | 5 条公开 RefSeq ITS + 对齐 metadata |
| `empty/` | 空 FASTA |
| `illegal_dna/` | 含非法碱基 |
| `too_few/` | 仅 2 条序列 |
| `tip_mismatch/` | metadata sample_id 与 tip 不对齐 |

Benchmark（>=30）：`data/benchmarks/fungi_its/`
