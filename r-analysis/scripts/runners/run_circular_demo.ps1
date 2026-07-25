# 环形树演示：生成 24-tip 数据并出图（旧 plot_circular_tree 路径）
$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $Root

$Rscript = "Rscript"
if (Test-Path "D:\R-4.4.2\bin\Rscript.exe") {
  $Rscript = "D:\R-4.4.2\bin\Rscript.exe"
}

Write-Host "=== prepare circular demo data ==="
& $Rscript (Join-Path $Root "scripts\demo\prepare_circular_demo.R")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$OutDir = Join-Path $Root "output\demos\circular"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

Write-Host "=== plot circular tree ==="
& $Rscript (Join-Path $Root "scripts\demo\plot_circular_tree.R") `
  (Join-Path $Root "data\demo\circular\tree.nwk") `
  (Join-Path $Root "data\demo\circular\metadata.csv") `
  (Join-Path $OutDir "circular_tree.png")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "OK: $OutDir\circular_tree.png"
