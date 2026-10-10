param(
  [Parameter(Mandatory = $true)]
  [string]$RunDt,
  [switch]$InitTables,
  [switch]$SeedDemo,
  [switch]$InitOnly
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$sqlDir = Join-Path $projectRoot 'pipeline\sql\payment'
$tempDir = Join-Path $projectRoot 'pipeline\generated\payment'
$logDir = Join-Path $projectRoot 'pipeline\logs'
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$null = [datetime]::ParseExact($RunDt, 'yyyy-MM-dd', $null)

$logTimestamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
$runId = [guid]::NewGuid().ToString('N').Substring(0, 8)
$logFile = Join-Path $logDir ("run_order_payment_reconcile_pipeline_{0}_{1}_{2}_{3}.log" -f $RunDt, $logTimestamp, $PID, $runId)
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
  $qualitySql = New-SqlFromTemplate -TemplatePath (Join-Path $sqlDir '40_order_payment_reconcile_quality.sql.tpl') -OutputName '40_order_payment_reconcile_quality.sql'
  $qualityOutput = Invoke-SparkSqlFile -LocalSqlPath $qualitySql -SqlLabel '40_order_payment_reconcile_quality.sql'

  if ($qualityOutput -match 'check failed') {
    throw "Quality check failed for $RunDt. Check log: $logFile"
  }

  Write-Log "Quality check passed for $RunDt"
}

function Invoke-AdsQualityChecks {
  Write-Log "Starting ADS quality check step for $RunDt"
  $qualitySql = New-SqlFromTemplate -TemplatePath (Join-Path $sqlDir '70_ads_order_payment_reconcile_overview_quality.sql.tpl') -OutputName '70_ads_order_payment_reconcile_overview_quality.sql'
  $qualityOutput = Invoke-SparkSqlFile -LocalSqlPath $qualitySql -SqlLabel '70_ads_order_payment_reconcile_overview_quality.sql'

  if ($qualityOutput -match 'check failed') {
    throw "ADS quality check failed for $RunDt. Check log: $logFile"
  }

  Write-Log "ADS quality check passed for $RunDt"
}

function Invoke-DwdPaymentQualityChecks {
  Write-Log "Starting DWD payment quality check step for $RunDt"
  $qualitySql = New-SqlFromTemplate -TemplatePath (Join-Path $sqlDir '21_dwd_payment_quality.sql.tpl') -OutputName '21_dwd_payment_quality.sql'
  $qualityOutput = Invoke-SparkSqlFile -LocalSqlPath $qualitySql -SqlLabel '21_dwd_payment_quality.sql'

  if ($qualityOutput -match 'check failed') {
    throw "DWD payment quality check failed for $RunDt. Check log: $logFile"
  }

  Write-Log "DWD payment quality check passed for $RunDt"
}

Write-Log "Order payment reconcile pipeline started. RunDt=$RunDt"
Write-Log "Log file: $logFile"

try {
  if ($InitOnly -and -not $InitTables) {
    throw 'InitOnly requires InitTables.'
  }

  if ($InitTables) {
    Write-Log 'Starting init step'
    Invoke-SparkSqlFile -LocalSqlPath (Join-Path $sqlDir '00_init_payment_reconcile_tables.sql') -SqlLabel '00_init_payment_reconcile_tables.sql' | Out-Null
    Write-Log 'Init step finished'
  }

  if ($InitOnly) {
    Write-Log 'Init only mode enabled. Skip payment reconcile steps.'
    exit 0
  }

  if ($SeedDemo) {
    Write-Log 'Starting demo seed step'
    Invoke-SparkSqlFile -LocalSqlPath (Join-Path $sqlDir '01_seed_dwd_payment_p_demo.sql') -SqlLabel '01_seed_dwd_payment_p_demo.sql' | Out-Null
    Write-Log 'Demo seed step finished'
  }

  Invoke-TemplateStep -StepName 'DWD Payment Dirty Capture' -TemplateName '11_dwd_payment_dirty_di.sql.tpl' -OutputName '11_dwd_payment_dirty_di.sql'
  Invoke-TemplateStep -StepName 'DWD Payment Clean' -TemplateName '10_dwd_payment_clean_di.sql.tpl' -OutputName '10_dwd_payment_clean_di.sql'
  Invoke-DwdPaymentQualityChecks
  Invoke-TemplateStep -StepName 'Payment Fact' -TemplateName '20_fct_payment_di.sql.tpl' -OutputName '20_fct_payment_di.sql'
  Invoke-TemplateStep -StepName 'Order Payment Reconcile' -TemplateName '30_dq_order_payment_reconcile_di.sql.tpl' -OutputName '30_dq_order_payment_reconcile_di.sql'
  Invoke-QualityChecks
  Invoke-TemplateStep -StepName 'Order Payment DQ Report' -TemplateName '50_order_payment_dq_report.sql.tpl' -OutputName '50_order_payment_dq_report.sql'
  Invoke-TemplateStep -StepName 'ADS Order Payment Reconcile Overview' -TemplateName '60_ads_order_payment_reconcile_overview.sql.tpl' -OutputName '60_ads_order_payment_reconcile_overview.sql'
  Invoke-AdsQualityChecks

  Write-Log "Order payment reconcile pipeline finished successfully for $RunDt"
  Write-Host 'Validate with:'
  Write-Host "SELECT * FROM hive_demo.dwd_payment_dirty_di WHERE dt = '$RunDt' ORDER BY dirty_reason, payment_id;"
  Write-Host "SELECT * FROM hive_demo.dq_order_payment_reconcile_di WHERE dt = '$RunDt' ORDER BY reconcile_status, order_id;"
  Write-Host "SELECT * FROM hive_demo.ads_order_payment_reconcile_overview WHERE dt = '$RunDt';"
  Write-Host "Log file: $logFile"
}
catch {
  Write-Log $_.Exception.Message 'ERROR'
  Write-Log "Order payment reconcile pipeline failed for $RunDt" 'ERROR'
  Write-Host "Log file: $logFile"
  exit 1
}
