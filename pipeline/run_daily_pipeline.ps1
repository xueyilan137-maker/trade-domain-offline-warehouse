param(
  [Parameter(Mandatory = $true)]
  [string]$RunDt,
  [switch]$InitTables
)

$ErrorActionPreference = 'Stop'

$projectRoot = 'C:\Users\21495\Documents\New project\dw_project'
$sqlDir = Join-Path $projectRoot 'pipeline\sql'
$tempDir = Join-Path $projectRoot 'pipeline\generated'
$logDir = Join-Path $projectRoot 'pipeline\logs'
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$logTimestamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
$runId = [guid]::NewGuid().ToString('N').Substring(0, 8)
$logFile = Join-Path $logDir ("run_daily_pipeline_{0}_{1}_{2}_{3}.log" -f $RunDt, $logTimestamp, $PID, $runId)
[System.IO.File]::WriteAllText($logFile, '', (New-Object System.Text.UTF8Encoding($false)))

function Write-Log {
  param(
    [string]$Message,
    [string]$Level = 'INFO'
  )

  $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  $line = "[{0}] [{1}] {2}" -f $ts, $Level, $Message
  Write-Host $line

  $lineWithNewline = $line + [Environment]::NewLine
  for ($i = 0; $i -lt 5; $i++) {
    try {
      [System.IO.File]::AppendAllText($script:logFile, $lineWithNewline, (New-Object System.Text.UTF8Encoding($false)))
      break
    }
    catch {
      if ($i -eq 4) {
        throw
      }
      Start-Sleep -Milliseconds 200
    }
  }
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
  $qualitySql = New-SqlFromTemplate -TemplatePath (Join-Path $sqlDir '40_quality_checks.sql.tpl') -OutputName '40_quality_checks.sql'
  $qualityOutput = Invoke-SparkSqlFile -LocalSqlPath $qualitySql -SqlLabel '40_quality_checks.sql'

  if ($qualityOutput -match 'check failed') {
    throw "Quality check failed for $RunDt. Check log: $logFile"
  }

  Write-Log "Quality check passed for $RunDt"
}

Write-Log "Pipeline started. RunDt=$RunDt"
Write-Log "Log file: $logFile"

try {
  if ($InitTables) {
    Write-Log "Starting init step"
    Invoke-SparkSqlFile -LocalSqlPath (Join-Path $sqlDir '00_init_partition_tables.sql') -SqlLabel '00_init_partition_tables.sql' | Out-Null
    Write-Log 'Init step finished'
  }

  Invoke-TemplateStep -StepName 'DWD' -TemplateName '10_dwd_daily.sql.tpl' -OutputName '10_dwd_daily.sql'
  Invoke-TemplateStep -StepName 'DWS' -TemplateName '20_dws_daily.sql.tpl' -OutputName '20_dws_daily.sql'
  Invoke-TemplateStep -StepName 'ADS' -TemplateName '30_ads_daily.sql.tpl' -OutputName '30_ads_daily.sql'
  Invoke-QualityChecks

  Write-Log "Pipeline finished successfully for $RunDt"
  Write-Host "Validate with:"
  Write-Host "SELECT * FROM hive_demo.ads_daily_overview_dp WHERE dt = '$RunDt';"
  Write-Host "Log file: $logFile"
}
catch {
  Write-Log $_.Exception.Message 'ERROR'
  Write-Log "Pipeline failed for $RunDt" 'ERROR'
  Write-Host "Log file: $logFile"
  exit 1
}
