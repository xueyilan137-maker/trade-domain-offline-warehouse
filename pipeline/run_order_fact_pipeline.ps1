param(
  [Parameter(Mandatory = $true)]
  [string]$RunDt,
  [switch]$InitTables,
  [switch]$InitOnly
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$sqlDir = Join-Path $projectRoot 'pipeline\sql\fact'
$tempDir = Join-Path $projectRoot 'pipeline\generated\fact'
$logDir = Join-Path $projectRoot 'pipeline\logs'
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$null = [datetime]::ParseExact($RunDt, 'yyyy-MM-dd', $null)

$logTimestamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
$runId = [guid]::NewGuid().ToString('N').Substring(0, 8)
$logFile = Join-Path $logDir ("run_order_fact_pipeline_{0}_{1}_{2}_{3}.log" -f $RunDt, $logTimestamp, $PID, $runId)
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
  $qualitySql = New-SqlFromTemplate -TemplatePath (Join-Path $sqlDir '20_fct_order_quality.sql.tpl') -OutputName '20_fct_order_quality.sql'
  $qualityOutput = Invoke-SparkSqlFile -LocalSqlPath $qualitySql -SqlLabel '20_fct_order_quality.sql'

  if ($qualityOutput -match 'check failed') {
    throw "Quality check failed for $RunDt. Check log: $logFile"
  }

  Write-Log "Quality check passed for $RunDt"
}

function Invoke-StatusQualityChecks {
  Write-Log "Starting order status quality check step for $RunDt"
  $qualitySql = New-SqlFromTemplate -TemplatePath (Join-Path $sqlDir '21_fct_order_status_quality.sql.tpl') -OutputName '21_fct_order_status_quality.sql'
  $qualityOutput = Invoke-SparkSqlFile -LocalSqlPath $qualitySql -SqlLabel '21_fct_order_status_quality.sql'

  if ($qualityOutput -match 'check failed') {
    throw "Order status quality check failed for $RunDt. Check log: $logFile"
  }

  Write-Log "Order status quality check passed for $RunDt"
}

function Invoke-RefundStatusQualityChecks {
  Write-Log "Starting order refund status quality check step for $RunDt"
  $qualitySql = New-SqlFromTemplate -TemplatePath (Join-Path $sqlDir '22_fct_order_refund_status_quality.sql.tpl') -OutputName '22_fct_order_refund_status_quality.sql'
  $qualityOutput = Invoke-SparkSqlFile -LocalSqlPath $qualitySql -SqlLabel '22_fct_order_refund_status_quality.sql'

  if ($qualityOutput -match 'check failed') {
    throw "Order refund status quality check failed for $RunDt. Check log: $logFile"
  }

  Write-Log "Order refund status quality check passed for $RunDt"
}

Write-Log "Order fact pipeline started. RunDt=$RunDt"
Write-Log "Log file: $logFile"

try {
  if ($InitTables) {
    Write-Log 'Starting init step'
    Invoke-SparkSqlFile -LocalSqlPath (Join-Path $sqlDir '00_init_order_fact_tables.sql') -SqlLabel '00_init_order_fact_tables.sql' | Out-Null
    Write-Log 'Init step finished'
  }

  if ($InitOnly) {
    Write-Log 'Init only mode enabled. Skip fact step.'
    exit 0
  }

  Invoke-TemplateStep -StepName 'Order Fact' -TemplateName '10_fct_order_di.sql.tpl' -OutputName '10_fct_order_di.sql'
  Invoke-TemplateStep -StepName 'Order Status Fact' -TemplateName '11_fct_order_status_di.sql.tpl' -OutputName '11_fct_order_status_di.sql'
  Invoke-TemplateStep -StepName 'Order Refund Status Fact' -TemplateName '12_fct_order_refund_status_di.sql.tpl' -OutputName '12_fct_order_refund_status_di.sql'
  Invoke-QualityChecks
  Invoke-StatusQualityChecks
  Invoke-RefundStatusQualityChecks

  Write-Log "Order fact pipeline finished successfully for $RunDt"
  Write-Host 'Validate with:'
  Write-Host "SELECT * FROM hive_demo.fct_order_di WHERE dt = '$RunDt' ORDER BY order_id;"
  Write-Host "SELECT * FROM hive_demo.fct_order_status_di WHERE dt = '$RunDt' ORDER BY order_id;"
  Write-Host "SELECT * FROM hive_demo.fct_order_refund_status_di WHERE dt = '$RunDt' ORDER BY order_id;"
  Write-Host "Log file: $logFile"
}
catch {
  Write-Log $_.Exception.Message 'ERROR'
  Write-Log "Order fact pipeline failed for $RunDt" 'ERROR'
  Write-Host "Log file: $logFile"
  exit 1
}
