param(
  [Parameter(Mandatory = $true)]
  [string]$RunDt,
  [switch]$InitTables,
  [switch]$InitOnly
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$sqlDir = Join-Path $projectRoot 'pipeline\sql\dwd'
$tempDir = Join-Path $projectRoot 'pipeline\generated\dwd'
$logDir = Join-Path $projectRoot 'pipeline\logs'
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$null = [datetime]::ParseExact($RunDt, 'yyyy-MM-dd', $null)

$logTimestamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
$runId = [guid]::NewGuid().ToString('N').Substring(0, 8)
$logFile = Join-Path $logDir ("run_dwd_order_clean_pipeline_{0}_{1}_{2}_{3}.log" -f $RunDt, $logTimestamp, $PID, $runId)
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

function New-SqlFromTemplate {
  param(
    [string]$TemplatePath,
    [string]$OutputName
  )

  $content = Get-Content -Raw -Path $TemplatePath
  $content = $content.Replace('__RUN_DT__', $RunDt)
  $outPath = Join-Path $tempDir $OutputName
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

function Invoke-TemplateStep {
  param(
    [string]$StepName,
    [string]$TemplateName,
    [string]$OutputName
  )

  Write-Log "Starting $StepName step for $RunDt"
  $sqlPath = New-SqlFromTemplate -TemplatePath (Join-Path $sqlDir $TemplateName) -OutputName $OutputName
  Invoke-SparkSqlFile -LocalSqlPath $sqlPath -SqlLabel $OutputName | Out-Null
  Write-Log "$StepName step finished for $RunDt"
}

function Invoke-QualityChecks {
  Write-Log "Starting quality check step for $RunDt"
  $qualitySql = New-SqlFromTemplate -TemplatePath (Join-Path $sqlDir '20_dwd_order_clean_quality.sql.tpl') -OutputName '20_dwd_order_clean_quality.sql'
  $qualityOutput = Invoke-SparkSqlFile -LocalSqlPath $qualitySql -SqlLabel '20_dwd_order_clean_quality.sql'

  if ($qualityOutput -match 'check failed') {
    throw "Quality check failed for $RunDt. Check log: $logFile"
  }

  Write-Log "Quality check passed for $RunDt"
}

function Invoke-DirtyQualityChecks {
  Write-Log "Starting dirty quality check step for $RunDt"
  $qualitySql = New-SqlFromTemplate -TemplatePath (Join-Path $sqlDir '30_dwd_order_dirty_quality.sql.tpl') -OutputName '30_dwd_order_dirty_quality.sql'
  $qualityOutput = Invoke-SparkSqlFile -LocalSqlPath $qualitySql -SqlLabel '30_dwd_order_dirty_quality.sql'

  if ($qualityOutput -match 'check failed') {
    throw "Dirty quality check failed for $RunDt. Check log: $logFile"
  }

  Write-Log "Dirty quality check passed for $RunDt"
}

function Invoke-CancelQualityChecks {
  Write-Log "Starting cancel quality check step for $RunDt"
  $qualitySql = New-SqlFromTemplate -TemplatePath (Join-Path $sqlDir '40_dwd_order_cancel_quality.sql.tpl') -OutputName '40_dwd_order_cancel_quality.sql'
  $qualityOutput = Invoke-SparkSqlFile -LocalSqlPath $qualitySql -SqlLabel '40_dwd_order_cancel_quality.sql'

  if ($qualityOutput -match 'check failed') {
    throw "Cancel quality check failed for $RunDt. Check log: $logFile"
  }

  Write-Log "Cancel quality check passed for $RunDt"
}

function Invoke-RefundQualityChecks {
  Write-Log "Starting refund quality check step for $RunDt"
  $qualitySql = New-SqlFromTemplate -TemplatePath (Join-Path $sqlDir '50_dwd_order_refund_quality.sql.tpl') -OutputName '50_dwd_order_refund_quality.sql'
  $qualityOutput = Invoke-SparkSqlFile -LocalSqlPath $qualitySql -SqlLabel '50_dwd_order_refund_quality.sql'

  if ($qualityOutput -match 'check failed') {
    throw "Refund quality check failed for $RunDt. Check log: $logFile"
  }

  Write-Log "Refund quality check passed for $RunDt"
}

Write-Log "DWD order clean pipeline started. RunDt=$RunDt"
Write-Log "Log file: $logFile"

try {
  if ($InitTables) {
    Write-Log 'Starting init step'
    Invoke-SparkSqlFile -LocalSqlPath (Join-Path $sqlDir '00_init_order_clean_tables.sql') -SqlLabel '00_init_order_clean_tables.sql' | Out-Null
    Write-Log 'Init step finished'
  }

  if ($InitOnly) {
    Write-Log 'Init only mode enabled. Skip DWD clean step.'
    exit 0
  }

  Invoke-TemplateStep -StepName 'DWD Order Dirty Capture' -TemplateName '11_dwd_order_dirty_di.sql.tpl' -OutputName '11_dwd_order_dirty_di.sql'
  Invoke-TemplateStep -StepName 'DWD Order Clean' -TemplateName '10_dwd_order_clean_di.sql.tpl' -OutputName '10_dwd_order_clean_di.sql'
  Invoke-TemplateStep -StepName 'DWD Order Cancel Clean' -TemplateName '12_dwd_order_cancel_clean_di.sql.tpl' -OutputName '12_dwd_order_cancel_clean_di.sql'
  Invoke-TemplateStep -StepName 'DWD Order Refund Clean' -TemplateName '13_dwd_order_refund_clean_di.sql.tpl' -OutputName '13_dwd_order_refund_clean_di.sql'
  Invoke-QualityChecks
  Invoke-DirtyQualityChecks
  Invoke-CancelQualityChecks
  Invoke-RefundQualityChecks

  Write-Log "DWD order clean pipeline finished successfully for $RunDt"
  Write-Host 'Validate with:'
  Write-Host "SELECT * FROM hive_demo.dwd_order_clean_di WHERE dt = '$RunDt' ORDER BY order_id;"
  Write-Host "SELECT * FROM hive_demo.dwd_order_dirty_di WHERE dt = '$RunDt' ORDER BY dirty_reason, order_id;"
  Write-Host "SELECT * FROM hive_demo.dwd_order_cancel_clean_di WHERE dt = '$RunDt' ORDER BY order_id;"
  Write-Host "SELECT * FROM hive_demo.dwd_order_refund_clean_di WHERE dt = '$RunDt' ORDER BY order_id;"
  Write-Host "Log file: $logFile"
}
catch {
  Write-Log $_.Exception.Message 'ERROR'
  Write-Log "DWD order clean pipeline failed for $RunDt" 'ERROR'
  Write-Host "Log file: $logFile"
  exit 1
}
