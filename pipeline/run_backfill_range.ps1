param(
  [Parameter(Mandatory = $true)]
  [string]$StartDt,

  [Parameter(Mandatory = $true)]
  [string]$EndDt
)

$ErrorActionPreference = 'Stop'

$pipelineScript = 'C:\Users\21495\Documents\New project\dw_project\pipeline\run_daily_pipeline.ps1'

$startDate = [datetime]::ParseExact($StartDt, 'yyyy-MM-dd', $null)
$endDate = [datetime]::ParseExact($EndDt, 'yyyy-MM-dd', $null)

if ($startDate -gt $endDate) {
  throw "StartDt cannot be later than EndDt. StartDt=$StartDt EndDt=$EndDt"
}

$currentDt = $startDate

while ($currentDt -le $endDate) {
  $runDt = $currentDt.ToString('yyyy-MM-dd')

  Write-Host '=================================================='
  Write-Host "Starting backfill for $runDt"
  Write-Host '=================================================='

  & powershell -ExecutionPolicy Bypass -File $pipelineScript -RunDt $runDt

  if ($LASTEXITCODE -ne 0) {
    Write-Host "Backfill failed for $runDt" -ForegroundColor Red
    exit 1
  }

  Write-Host "Backfill finished successfully for $runDt" -ForegroundColor Green
  $currentDt = $currentDt.AddDays(1)
}

Write-Host '=================================================='
Write-Host 'Backfill finished successfully for all dates' -ForegroundColor Green
Write-Host '=================================================='
