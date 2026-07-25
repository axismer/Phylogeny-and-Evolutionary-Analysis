# Plugin Contract Audit Report

> Framework v0.3 P4  
> generated_at: 2026-07-24T23:57:46+0800  
> overall: **PASS**

## Discovery

- registered: `archaea`, `bacteria`, `eukaryote`, `fungi`, `virus`
- expected: `virus`, `bacteria`, `archaea`, `eukaryote`, `fungi`
- discovery_ok: TRUE

## Per-plugin contract

| organism_type | status | contract | path | notes |
|---------------|--------|----------|------|-------|
| virus | production | VALID | `D:/Projects/phylo-platform/r-analysis/strategies/virus/plugin.R` | PASS |
| bacteria | production | VALID | `D:/Projects/phylo-platform/r-analysis/strategies/bacteria/plugin.R` | PASS |
| archaea | stub | VALID | `D:/Projects/phylo-platform/r-analysis/strategies/archaea/plugin.R` | PASS |
| eukaryote | stub | VALID | `D:/Projects/phylo-platform/r-analysis/strategies/eukaryote/plugin.R` | PASS |
| fungi | production | VALID | `D:/Projects/phylo-platform/r-analysis/strategies/fungi/plugin.R` | PASS |

## Checks performed

1. `validate_plugin_contract` on plugin env
2. `get_status()` matches expected (production vs stub)
3. `get_metadata_schema()` / `get_default_config()` shape
4. `extra_columns` vs `TYPE_EXTRA_COLUMNS` fallback alignment

## Summary

- passed: 5 / 5
- failed: 0

