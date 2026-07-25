# 基准/任务结果环形图：默认对 output/benchmarks/h3n2_ha 出 circular_tree_final
$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $Root

$Rscript = "Rscript"
if (Test-Path "D:\R-4.4.2\bin\Rscript.exe") {
  $Rscript = "D:\R-4.4.2\bin\Rscript.exe"
}

$OutDir = Join-Path $Root "output\benchmarks\h3n2_ha"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

Write-Host "=== ggtree on benchmark output ==="
& $Rscript (Join-Path $Root "engine\ggtree_visualization.R") `
  (Join-Path $OutDir "tree.nwk") `
  (Join-Path $OutDir "metadata.csv") `
  $OutDir
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "OK: $OutDir\circular_tree_final.png"
Write-Host "OK: $OutDir\circular_tree_final.pdf"
Write-Host "OK: $OutDir\visualization_report.json"
