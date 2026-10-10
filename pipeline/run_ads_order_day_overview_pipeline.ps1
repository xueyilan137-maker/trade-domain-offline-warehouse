param(
  [Parameter(Mandatory = $true)]
  [string]$RunDt,
  [switch]$InitTables,
  [switch]$InitOnly
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$sqlDir = Join-Path $projectRoot 'pipeline\sql\ads'
$tempDir = Join-Path $projectRoot 'pipeline\generated\ads'
$logDir = Join-Path $projectRoot 'pipeline\logs'
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$null = [datetime]::ParseExact($RunDt, 'yyyy-MM-dd', $null)

$logTimestamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
$runId = [guid]::NewGuid().ToString('N').Substring(0, 8)
$logFile = Join-Path $logDir ("run_ads_order_day_overview_pipeline_{0}_{1}_{2}_{3}.log" -f $RunDt, $logTimestamp, $PID, $runId)
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
  $qualitySql = New-SqlFromTemplate -TemplatePath (Join-Path $sqlDir '20_ads_order_day_overview_quality.sql.tpl') -OutputName '20_ads_order_day_overview_quality.sql'
  $qualityOutput = Invoke-SparkSqlFile -LocalSqlPath $qualitySql -SqlLabel '20_ads_order_day_overview_quality.sql'

  if ($qualityOutput -match 'check failed') {
    throw "Quality check failed for $RunDt. Check log: $logFile"
  }

  Write-Log "Quality check passed for $RunDt"
}

function Invoke-ReconcileChecks {
  Write-Log "Starting reconcile check step for $RunDt"
  $reconcileSql = New-SqlFromTemplate -TemplatePath (Join-Path $sqlDir '30_ads_order_day_overview_reconcile.sql.tpl') -OutputName '30_ads_order_day_overview_reconcile.sql'
  $reconcileOutput = Invoke-SparkSqlFile -LocalSqlPath $reconcileSql -SqlLabel '30_ads_order_day_overview_reconcile.sql'

  if ($reconcileOutput -match 'check failed') {
    throw "Reconcile check failed for $RunDt. Check log: $logFile"
  }

  Write-Log "Reconcile check passed for $RunDt"
}

function Invoke-StatusQualityChecks {
  Write-Log "Starting order status ADS quality check step for $RunDt"
  $qualitySql = New-SqlFromTemplate -TemplatePath (Join-Path $sqlDir '21_ads_order_status_day_overview_quality.sql.tpl') -OutputName '21_ads_order_status_day_overview_quality.sql'
  $qualityOutput = Invoke-SparkSqlFile -LocalSqlPath $qualitySql -SqlLabel '21_ads_order_status_day_overview_quality.sql'

  if ($qualityOutput -match 'check failed') {
    throw "Order status ADS quality check failed for $RunDt. Check log: $logFile"
  }

  Write-Log "Order status ADS quality check passed for $RunDt"
}

function Invoke-StatusReconcileChecks {
  Write-Log "Starting order status ADS reconcile check step for $RunDt"
  $reconcileSql = New-SqlFromTemplate -TemplatePath (Join-Path $sqlDir '31_ads_order_status_day_overview_reconcile.sql.tpl') -OutputName '31_ads_order_status_day_overview_reconcile.sql'
  $reconcileOutput = Invoke-SparkSqlFile -LocalSqlPath $reconcileSql -SqlLabel '31_ads_order_status_day_overview_reconcile.sql'

  if ($reconcileOutput -match 'check failed') {
    throw "Order status ADS reconcile check failed for $RunDt. Check log: $logFile"
  }

  Write-Log "Order status ADS reconcile check passed for $RunDt"
}

function Invoke-RefundQualityChecks {
  Write-Log "Starting order refund ADS quality check step for $RunDt"
  $qualitySql = New-SqlFromTemplate -TemplatePath (Join-Path $sqlDir '22_ads_order_refund_day_overview_quality.sql.tpl') -OutputName '22_ads_order_refund_day_overview_quality.sql'
  $qualityOutput = Invoke-SparkSqlFile -LocalSqlPath $qualitySql -SqlLabel '22_ads_order_refund_day_overview_quality.sql'

  if ($qualityOutput -match 'check failed') {
    throw "Order refund ADS quality check failed for $RunDt. Check log: $logFile"
  }

  Write-Log "Order refund ADS quality check passed for $RunDt"
}

function Invoke-RefundReconcileChecks {
  Write-Log "Starting order refund ADS reconcile check step for $RunDt"
  $reconcileSql = New-SqlFromTemplate -TemplatePath (Join-Path $sqlDir '32_ads_order_refund_day_overview_reconcile.sql.tpl') -OutputName '32_ads_order_refund_day_overview_reconcile.sql'
  $reconcileOutput = Invoke-SparkSqlFile -LocalSqlPath $reconcileSql -SqlLabel '32_ads_order_refund_day_overview_reconcile.sql'

  if ($reconcileOutput -match 'check failed') {
    throw "Order refund ADS reconcile check failed for $RunDt. Check log: $logFile"
  }

  Write-Log "Order refund ADS reconcile check passed for $RunDt"
}

Write-Log "ADS order day overview pipeline started. RunDt=$RunDt"
Write-Log "Log file: $logFile"

try {
  if ($InitTables) {
    Write-Log 'Starting init step'
    Invoke-SparkSqlFile -LocalSqlPath (Join-Path $sqlDir '00_init_ads_order_day_overview_tables.sql') -SqlLabel '00_init_ads_order_day_overview_tables.sql' | Out-Null
    Write-Log 'Init step finished'
  }

  if ($InitOnly) {
    Write-Log 'Init only mode enabled. Skip ADS overview step.'
    exit 0
  }

  Invoke-TemplateStep -StepName 'ADS Order Day Overview' -TemplateName '10_ads_order_day_overview.sql.tpl' -OutputName '10_ads_order_day_overview.sql'
  Invoke-TemplateStep -StepName 'ADS Order Status Day Overview' -TemplateName '11_ads_order_status_day_overview.sql.tpl' -OutputName '11_ads_order_status_day_overview.sql'
  Invoke-TemplateStep -StepName 'ADS Order Refund Day Overview' -TemplateName '12_ads_order_refund_day_overview.sql.tpl' -OutputName '12_ads_order_refund_day_overview.sql'
  Invoke-QualityChecks
  Invoke-StatusQualityChecks
  Invoke-RefundQualityChecks
  Invoke-ReconcileChecks
  Invoke-StatusReconcileChecks
  Invoke-RefundReconcileChecks

  Write-Log "ADS order day overview pipeline finished successfully for $RunDt"
  Write-Host 'Validate with:'
  Write-Host "SELECT * FROM hive_demo.ads_order_day_overview WHERE dt = '$RunDt';"
  Write-Host "SELECT * FROM hive_demo.ads_order_status_day_overview WHERE dt = '$RunDt';"
  Write-Host "SELECT * FROM hive_demo.ads_order_refund_day_overview WHERE dt = '$RunDt';"
  Write-Host "Log file: $logFile"
}
catch {
  Write-Log $_.Exception.Message 'ERROR'
  Write-Log "ADS order day overview pipeline failed for $RunDt" 'ERROR'
  Write-Host "Log file: $logFile"
  exit 1
}
