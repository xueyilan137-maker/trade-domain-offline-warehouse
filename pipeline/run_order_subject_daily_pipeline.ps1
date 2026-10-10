param(
  [Parameter(Mandatory = $true)]
  [string]$RunDt,
  [switch]$InitTables,
  [switch]$InitOnly
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$dqSqlDir = Join-Path $projectRoot 'pipeline\sql\dq'
$dqTempDir = Join-Path $projectRoot 'pipeline\generated\dq'
$logDir = Join-Path $projectRoot 'pipeline\logs'
New-Item -ItemType Directory -Force -Path $dqTempDir | Out-Null
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$null = [datetime]::ParseExact($RunDt, 'yyyy-MM-dd', $null)

$logTimestamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
$runId = [guid]::NewGuid().ToString('N').Substring(0, 8)
$logFile = Join-Path $logDir ("run_order_subject_daily_pipeline_{0}_{1}_{2}_{3}.log" -f $RunDt, $logTimestamp, $PID, $runId)
[System.IO.File]::WriteAllText($logFile, '', (New-Object System.Text.UTF8Encoding($false)))

function Write-Log {
  param(
    [string]$Message,
    [string]$Level = 'INFO'
  )

  $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  $line = "[{0}] [{1}] {2}" -f $ts, $Level, $Message
  Write-Host $line
  [System.IO.File]::AppendAllText($script:logFile, $line + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
}

function Invoke-PipelineScript {
  param(
    [string]$StepName,
    [string]$ScriptName,
    [switch]$PassInitTables,
    [switch]$PassInitOnly
  )

  $scriptPath = Join-Path $PSScriptRoot $ScriptName
  $args = @(
    '-ExecutionPolicy', 'Bypass',
    '-File', $scriptPath,
    '-RunDt', $RunDt
  )

  if ($PassInitTables) {
    $args += '-InitTables'
  }

  if ($PassInitOnly) {
    $args += '-InitOnly'
  }

  Write-Log "Starting $StepName step"
  & powershell @args

  if ($LASTEXITCODE -ne 0) {
    throw "$StepName step failed. Script=$ScriptName"
  }

  Write-Log "$StepName step finished"
}

function New-DqSqlFromTemplate {
  param(
    [string]$TemplatePath,
    [string]$OutputName
  )

  $content = Get-Content -Raw -Path $TemplatePath
  $content = $content.Replace('__RUN_DT__', $RunDt)
  $outPath = Join-Path $dqTempDir $OutputName
  [System.IO.File]::WriteAllText($outPath, $content, (New-Object System.Text.UTF8Encoding($false)))
  return $outPath
}

function Invoke-SparkSqlFile {
  param(
    [string]$LocalSqlPath,
    [string]$SqlLabel
  )

  $containerSql = "/tmp/" + [System.IO.Path]::GetFileName($LocalSqlPath)
  Write-Log "Executing SQL file: $SqlLabel"

  & docker cp $LocalSqlPath "hadoop-spark:$containerSql" | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to copy SQL file to container: $SqlLabel"
  }

  $oldEap = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $output = (& docker exec hadoop-spark bash -lc "/spark/bin/spark-sql --master local[*] -f $containerSql" 2>&1 | Out-String)
  $exitCode = $LASTEXITCODE
  $ErrorActionPreference = $oldEap

  if (-not [string]::IsNullOrWhiteSpace($output)) {
    $output.TrimEnd() -split "`r?`n" | ForEach-Object {
      $level = if ($_ -match '\bWARN\b') { 'WARN' } else { 'SPARK' }
      Write-Log $_ $level
    }
  }

  if ($exitCode -ne 0) {
    throw "SQL execution failed: $SqlLabel"
  }

  return $output
}

function Invoke-DqReport {
  Write-Log "Starting DQ report step for $RunDt"
  $dqSql = New-DqSqlFromTemplate -TemplatePath (Join-Path $dqSqlDir '10_order_subject_dq_report.sql.tpl') -OutputName '10_order_subject_dq_report.sql'
  Invoke-SparkSqlFile -LocalSqlPath $dqSql -SqlLabel '10_order_subject_dq_report.sql' | Out-Null
  Write-Log "DQ report step finished for $RunDt"
}

Write-Log "Order subject daily pipeline started. RunDt=$RunDt"
Write-Log "Log file: $logFile"

try {
  if ($InitOnly -and -not $InitTables) {
    throw 'InitOnly requires InitTables.'
  }

  if ($InitTables) {
    Invoke-PipelineScript -StepName 'Init DWD order clean table' -ScriptName 'run_dwd_order_clean_pipeline.ps1' -PassInitTables -PassInitOnly
    Invoke-PipelineScript -StepName 'Init order fact table' -ScriptName 'run_order_fact_pipeline.ps1' -PassInitTables -PassInitOnly
    Invoke-PipelineScript -StepName 'Init DWS user order day aggregate table' -ScriptName 'run_dws_user_order_day_agg_pipeline.ps1' -PassInitTables -PassInitOnly
    Invoke-PipelineScript -StepName 'Init ADS order day overview table' -ScriptName 'run_ads_order_day_overview_pipeline.ps1' -PassInitTables -PassInitOnly
    Invoke-SparkSqlFile -LocalSqlPath (Join-Path $dqSqlDir '00_init_dq_check_result_tables.sql') -SqlLabel '00_init_dq_check_result_tables.sql' | Out-Null
  }

  if ($InitOnly) {
    Write-Log 'Init only mode enabled. Skip order subject daily run.'
    exit 0
  }

  Invoke-PipelineScript -StepName 'DWD order clean' -ScriptName 'run_dwd_order_clean_pipeline.ps1'
  Invoke-PipelineScript -StepName 'FCT order detail' -ScriptName 'run_order_fact_pipeline.ps1'
  Invoke-PipelineScript -StepName 'DWS user order day aggregate' -ScriptName 'run_dws_user_order_day_agg_pipeline.ps1'
  Invoke-PipelineScript -StepName 'ADS order day overview' -ScriptName 'run_ads_order_day_overview_pipeline.ps1'
  Invoke-DqReport

  Write-Log "Order subject daily pipeline finished successfully for $RunDt"
  Write-Host 'Validate with:'
  Write-Host "SELECT * FROM hive_demo.ads_order_day_overview WHERE dt = '$RunDt';"
  Write-Host "Log file: $logFile"
}
catch {
  Write-Log $_.Exception.Message 'ERROR'
  Write-Log "Order subject daily pipeline failed for $RunDt" 'ERROR'
  Write-Host "Log file: $logFile"
  exit 1
}
