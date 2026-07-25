# Bacteria strategy validation fixtures

Used by `docs/bacteria_validation_report.md` and Framework v0.1 regression
(`scripts/runners/run_framework_regression.R`; CLI: `runners/run_analysis.R --type bacteria`).

| Case | Intent |
|------|--------|
| `valid/` | Matching FASTA + metadata (6 real 16S tips) |
| `tip_mismatch/` | Metadata `sample_id` does not match FASTA tips |
| `missing_fields/` | Metadata missing required `resistance` column |
| `illegal_dna/` | Illegal DNA characters (`X`) in FASTA |
| `empty/` | Empty FASTA file |
| `too_few/` | Fewer than 3 sequences |
