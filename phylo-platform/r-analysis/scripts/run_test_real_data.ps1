# 真实数据测试：合并平台 data/raw → test-data/platform_16s.fasta → test-data/output
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

$Rscript = "Rscript"
if (Test-Path "D:\R-4.4.2\bin\Rscript.exe") {
  $Rscript = "D:\R-4.4.2\bin\Rscript.exe"
}

$InputFasta = Join-Path $ScriptDir "..\test-data\input.fasta"
$PlatformFasta = Join-Path $ScriptDir "..\test-data\platform_16s.fasta"
$OutDir = Join-Path $ScriptDir "..\test-data\output"

# 优先使用用户放置的 input.fasta；否则从平台 raw 合并
if (Test-Path $InputFasta) {
  $Fasta = $InputFasta
  Write-Host "=== real-data test using test-data\input.fasta ==="
} else {
  Write-Host "=== prepare platform_16s.fasta from data/raw ==="
  & $Rscript prepare_platform_fasta.R
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  $Fasta = $PlatformFasta
  Write-Host "=== real-data test using platform_16s.fasta ==="
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
& $Rscript phylogenetic_tree.R $Fasta $OutDir
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "OK:"
Write-Host "  $OutDir\tree.nwk"
Write-Host "  $OutDir\tree.png"
Write-Host "  $OutDir\analysis_result.json"
