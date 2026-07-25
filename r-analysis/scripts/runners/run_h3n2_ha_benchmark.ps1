# =============================================================================
# run_h3n2_ha_benchmark.ps1
# 真实 H3N2 HA：未比对 FASTA → MUSCLE/MAFFT → ML 树 → metadata → circular ggtree
# =============================================================================
$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $Root

$Fasta = Join-Path $Root "data\benchmarks\h3n2_ha\h3n2_ha_unaligned.fasta"
$NcbiMeta = Join-Path $Root "data\benchmarks\h3n2_ha\ncbi_metadata.csv"
$OutDir = Join-Path $Root "output\benchmarks\h3n2_ha"

if (-not (Test-Path $Fasta)) { throw "缺少 FASTA: $Fasta" }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# 确保 tools 在 PATH（muscle / mafft）
$env:Path = "$(Join-Path $Root 'tools');$(Join-Path $Root 'tools\mafft-win');$env:Path"

Write-Host "======== [1/3] phylogenetic_tree.R ========"
& Rscript (Join-Path $Root "engine\phylogenetic_tree.R") $Fasta $OutDir
if ($LASTEXITCODE -ne 0) { throw "phylogenetic_tree.R failed: $LASTEXITCODE" }

Write-Host "======== [2/3] metadata ========"
$Tree = Join-Path $OutDir "tree.nwk"
$MetaOut = Join-Path $OutDir "metadata.csv"
& Rscript (Join-Path $Root "engine\ncbi_metadata_to_tree_metadata.R") $NcbiMeta $Tree $MetaOut
if ($LASTEXITCODE -ne 0) { throw "metadata conversion failed: $LASTEXITCODE" }

Write-Host "======== [3/3] ggtree circular ========"
& Rscript (Join-Path $Root "engine\ggtree_visualization.R") $Tree $MetaOut $OutDir
if ($LASTEXITCODE -ne 0) { throw "ggtree_visualization.R failed: $LASTEXITCODE" }

Write-Host "======== branch length + distribution report ========"
& Rscript (Join-Path $Root "scripts\prep\report_h3n2_benchmark.R") $OutDir $NcbiMeta
if ($LASTEXITCODE -ne 0) { throw "report failed: $LASTEXITCODE" }

Write-Host "DONE -> $OutDir"
