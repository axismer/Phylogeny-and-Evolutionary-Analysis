# 真实数据测试：合并平台 data/raw → test-data/fixtures/platform_16s.fasta → test-data/output
$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $Root

$Rscript = "Rscript"
if (Test-Path "D:\R-4.4.2\bin\Rscript.exe") {
  $Rscript = "D:\R-4.4.2\bin\Rscript.exe"
}

$InputFasta = Join-Path $Root "test-data\input.fasta"
$PlatformFasta = Join-Path $Root "test-data\fixtures\platform_16s.fasta"
$OutDir = Join-Path $Root "test-data\output"

# 优先使用用户放置的 input.fasta；否则从平台 raw 合并
if (Test-Path $InputFasta) {
  $Fasta = $InputFasta
  Write-Host "=== real-data test using test-data\input.fasta ==="
} else {
  Write-Host "=== prepare platform_16s.fasta from data/raw ==="
  & $Rscript (Join-Path $Root "scripts\prep\prepare_platform_fasta.R")
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  $Fasta = $PlatformFasta
  Write-Host "=== real-data test using fixtures\platform_16s.fasta ==="
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
& $Rscript (Join-Path $Root "engine\phylogenetic_tree.R") $Fasta $OutDir
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "OK:"
Write-Host "  $OutDir\tree.nwk"
Write-Host "  $OutDir\tree.png"
Write-Host "  $OutDir\analysis_result.json"
