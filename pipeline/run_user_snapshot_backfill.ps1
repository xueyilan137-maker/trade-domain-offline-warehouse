param(
  [Parameter(Mandatory = $true)]
  [string]$StartDt,

  [Parameter(Mandatory = $true)]
  [string]$EndDt,

  [switch]$InitTables
)

$ErrorActionPreference = 'Stop'

$pipelineScript = Join-Path $PSScriptRoot 'run_user_snapshot_pipeline.ps1'

$startDate = [datetime]::ParseExact($StartDt, 'yyyy-MM-dd', $null)
$endDate = [datetime]::ParseExact($EndDt, 'yyyy-MM-dd', $null)

if ($startDate -gt $endDate) {
  throw "StartDt cannot be later than EndDt. StartDt=$StartDt EndDt=$EndDt"
}

$currentDt = $startDate
$isFirstRun = $true

while ($currentDt -le $endDate) {
  $runDt = $currentDt.ToString('yyyy-MM-dd')

  Write-Host '=================================================='
  Write-Host "Starting snapshot backfill for $runDt"
  Write-Host '=================================================='

  $args = @(
    '-ExecutionPolicy', 'Bypass',
    '-File', $pipelineScript,
    '-RunDt', $runDt
  )

  if ($InitTables -and $isFirstRun) {
    $args += '-InitTables'
  }

  & powershell @args

  if ($LASTEXITCODE -ne 0) {
    Write-Host "Snapshot backfill failed for $runDt" -ForegroundColor Red
    exit 1
  }

  Write-Host "Snapshot backfill finished successfully for $runDt" -ForegroundColor Green
  $currentDt = $currentDt.AddDays(1)
  $isFirstRun = $false
}

Write-Host '=================================================='
Write-Host 'Snapshot backfill finished successfully for all dates' -ForegroundColor Green
Write-Host '=================================================='
