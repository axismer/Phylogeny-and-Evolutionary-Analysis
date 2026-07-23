# 玩具数据冒烟测试（保留 example.fasta → output/）
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

$Rscript = "Rscript"
if (Test-Path "D:\R-4.4.2\bin\Rscript.exe") {
  $Rscript = "D:\R-4.4.2\bin\Rscript.exe"
}

Write-Host "=== example.fasta smoke test ==="
& $Rscript phylogenetic_tree.R ..\data\example.fasta ..\output
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "OK: ..\output\tree.nwk / tree.png / analysis_result.json"
