# Virus strategy regression fixtures

Used by `scripts/runners/run_framework_regression.R` (Framework v0.2).

| Case | Intent |
|------|--------|
| `valid/` | 4-tip FASTA + matching unified metadata |
| `invalid_fasta/` | Non-FASTA content (no `>` header) |
| `metadata_mismatch/` | Metadata `sample_id` does not match tree tips |
| `empty/` | Empty FASTA file |
| `too_few/` | Fewer than 3 sequences |
| `illegal_dna/` | Illegal DNA characters (`X`) |

Regenerate:

```bash
Rscript scripts/prep/prepare_virus_regression_fixtures.R
```
