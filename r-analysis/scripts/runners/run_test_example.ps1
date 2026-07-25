# 玩具数据冒烟测试（data/smoke/example.fasta → output/tasks/example/）
$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $Root

$Rscript = "Rscript"
if (Test-Path "D:\R-4.4.2\bin\Rscript.exe") {
  $Rscript = "D:\R-4.4.2\bin\Rscript.exe"
}

$OutDir = Join-Path $Root "output\tasks\example"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

Write-Host "=== example.fasta smoke test ==="
& $Rscript (Join-Path $Root "engine\phylogenetic_tree.R") `
  (Join-Path $Root "data\smoke\example.fasta") `
  $OutDir
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "OK: $OutDir\tree.nwk / tree.png / analysis_result.json"
