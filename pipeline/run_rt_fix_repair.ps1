param(
  [string]$StartWindow,
  [string]$EndWindow,
  [switch]$Apply,
  [switch]$BootstrapCurrentState
)

$ErrorActionPreference = 'Stop'

$projectRoot = 'C:\Users\21495\Documents\New project\dw_project'
$logDir = Join-Path $projectRoot 'pipeline\logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$logTimestamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
$logFile = Join-Path $logDir ("run_rt_fix_repair_{0}_{1}.log" -f $logTimestamp, $PID)
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

function Get-WhereClause {
  $clauses = @()
  if (-not [string]::IsNullOrWhiteSpace($StartWindow)) {
    $clauses += "window_start >= '$StartWindow'"
  }
  if (-not [string]::IsNullOrWhiteSpace($EndWindow)) {
    $clauses += "window_start < '$EndWindow'"
  }

  if ($clauses.Count -eq 0) {
    return '1 = 1'
  }

  return ($clauses -join ' AND ')
}

function Invoke-DorisSql {
  param(
    [string]$Sql
  )

  $bytes = [System.Text.Encoding]::UTF8.GetBytes($Sql)
  $tempFile = [System.IO.Path]::GetTempFileName()
  [System.IO.File]::WriteAllBytes($tempFile, $bytes)

  try {
    $oldEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $output = Get-Content -Raw -Path $tempFile | docker exec -i rt-doris-fe bash -lc "mysql -h127.0.0.1 -P9030 -uroot -N -B" 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $oldEap

    if ($exitCode -ne 0) {
      throw ($output.Trim())
    }

    return $output.Trim()
  }
  finally {
    Remove-Item -Force $tempFile -ErrorAction SilentlyContinue
  }
}

function Get-AffectedWindowsSql {
  param([string]$WhereClause)
@"
USE rt_dw2;
SELECT
    f.window_start,
    f.window_end,
    f.fix_rows,
    f.fix_pv,
    COALESCE(l.repaired_fix_rows, 0) AS repaired_fix_rows,
    COALESCE(l.repaired_fix_pv, 0) AS repaired_fix_pv,
    f.fix_rows - COALESCE(l.repaired_fix_rows, 0) AS delta_fix_rows,
    f.fix_pv - COALESCE(l.repaired_fix_pv, 0) AS delta_fix_pv
FROM (
    SELECT
        window_start,
        window_end,
        COUNT(*) AS fix_rows,
        SUM(pv) AS fix_pv
    FROM rt_dw2.ads_visit_fix
    WHERE $WhereClause
    GROUP BY
        window_start,
        window_end
) f
LEFT JOIN rt_dw2.ads_visit_fix_repair_log l
    ON f.window_start = l.window_start
   AND f.window_end = l.window_end
WHERE f.fix_rows > COALESCE(l.repaired_fix_rows, 0)
   OR f.fix_pv > COALESCE(l.repaired_fix_pv, 0)
ORDER BY
    f.window_start;
"@
}

function Get-PreviewSql {
  param([string]$WhereClause)

@"
USE rt_dw2;
SELECT
    m.window_start,
    m.window_end,
    m.pv AS main_pv,
    d.current_fix_pv,
    d.repaired_fix_pv,
    d.delta_fix_pv,
    m.pv + d.delta_fix_pv AS final_pv
FROM rt_dw2.ads_visit_main m
JOIN (
    SELECT
        f.window_start,
        f.window_end,
        f.fix_pv AS current_fix_pv,
        COALESCE(l.repaired_fix_pv, 0) AS repaired_fix_pv,
        f.fix_pv - COALESCE(l.repaired_fix_pv, 0) AS delta_fix_pv
    FROM (
        SELECT
            window_start,
            window_end,
            COUNT(*) AS fix_rows,
            SUM(pv) AS fix_pv
        FROM rt_dw2.ads_visit_fix
        WHERE $WhereClause
        GROUP BY
            window_start,
            window_end
    ) f
    LEFT JOIN rt_dw2.ads_visit_fix_repair_log l
        ON f.window_start = l.window_start
       AND f.window_end = l.window_end
    WHERE f.fix_rows > COALESCE(l.repaired_fix_rows, 0)
       OR f.fix_pv > COALESCE(l.repaired_fix_pv, 0)
) d
    ON m.window_start = d.window_start
   AND m.window_end = d.window_end
ORDER BY
    m.window_start;
"@
}

function Get-PrepareBackupTableSql {
@"
CREATE TABLE IF NOT EXISTS rt_dw2.ads_visit_main_bak (
    window_start DATETIME(3) NOT NULL,
    window_end DATETIME(3) NOT NULL,
    pv BIGINT NOT NULL
)
UNIQUE KEY(window_start, window_end)
DISTRIBUTED BY HASH(window_start) BUCKETS 1
PROPERTIES (
    "replication_num" = "1",
    "enable_unique_key_merge_on_write" = "true"
);
"@
}

function Get-PrepareRepairLogTableSql {
@"
CREATE TABLE IF NOT EXISTS rt_dw2.ads_visit_fix_repair_log (
    window_start DATETIME(3) NOT NULL,
    window_end DATETIME(3) NOT NULL,
    repaired_fix_rows BIGINT NOT NULL,
    repaired_fix_pv BIGINT NOT NULL,
    repair_batch_id VARCHAR(64) NOT NULL,
    repair_time DATETIME(3) NOT NULL
)
UNIQUE KEY(window_start, window_end)
DISTRIBUTED BY HASH(window_start) BUCKETS 1
PROPERTIES (
    "replication_num" = "1",
    "enable_unique_key_merge_on_write" = "true"
);
"@
}

function Get-RefreshBackupSql {
  param([string]$WhereClause)
@"
USE rt_dw2;
TRUNCATE TABLE rt_dw2.ads_visit_main_bak;
INSERT INTO rt_dw2.ads_visit_main_bak
SELECT
    m.window_start,
    m.window_end,
    m.pv
FROM rt_dw2.ads_visit_main m
JOIN (
    SELECT
        f.window_start,
        f.window_end
    FROM (
        SELECT
            window_start,
            window_end,
            COUNT(*) AS fix_rows,
            SUM(pv) AS fix_pv
        FROM rt_dw2.ads_visit_fix
        WHERE $WhereClause
        GROUP BY
            window_start,
            window_end
    ) f
    LEFT JOIN rt_dw2.ads_visit_fix_repair_log l
        ON f.window_start = l.window_start
       AND f.window_end = l.window_end
    WHERE f.fix_rows > COALESCE(l.repaired_fix_rows, 0)
       OR f.fix_pv > COALESCE(l.repaired_fix_pv, 0)
) x
    ON m.window_start = x.window_start
   AND m.window_end = x.window_end;
"@
}

function Get-ApplyRepairSql {
  param([string]$WhereClause)
@"
USE rt_dw2;
INSERT INTO rt_dw2.ads_visit_main
SELECT
    b.window_start,
    b.window_end,
    b.pv + d.delta_fix_pv AS pv
FROM rt_dw2.ads_visit_main_bak b
JOIN (
    SELECT
        f.window_start,
        f.window_end,
        f.fix_pv - COALESCE(l.repaired_fix_pv, 0) AS delta_fix_pv
    FROM (
        SELECT
            window_start,
            window_end,
            COUNT(*) AS fix_rows,
            SUM(pv) AS fix_pv
        FROM rt_dw2.ads_visit_fix
        WHERE $WhereClause
        GROUP BY
            window_start,
            window_end
    ) f
    LEFT JOIN rt_dw2.ads_visit_fix_repair_log l
        ON f.window_start = l.window_start
       AND f.window_end = l.window_end
    WHERE f.fix_rows > COALESCE(l.repaired_fix_rows, 0)
       OR f.fix_pv > COALESCE(l.repaired_fix_pv, 0)
) d
    ON b.window_start = d.window_start
   AND b.window_end = d.window_end;
"@
}

function Get-UpdateRepairLogSql {
  param(
    [string]$WhereClause,
    [string]$BatchId
  )

@"
USE rt_dw2;
INSERT INTO rt_dw2.ads_visit_fix_repair_log
SELECT
    f.window_start,
    f.window_end,
    f.fix_rows AS repaired_fix_rows,
    f.fix_pv AS repaired_fix_pv,
    '$BatchId' AS repair_batch_id,
    NOW(3) AS repair_time
FROM (
    SELECT
        window_start,
        window_end,
        COUNT(*) AS fix_rows,
        SUM(pv) AS fix_pv
    FROM rt_dw2.ads_visit_fix
    WHERE $WhereClause
    GROUP BY
        window_start,
        window_end
) f
LEFT JOIN rt_dw2.ads_visit_fix_repair_log l
    ON f.window_start = l.window_start
   AND f.window_end = l.window_end
WHERE f.fix_rows > COALESCE(l.repaired_fix_rows, 0)
   OR f.fix_pv > COALESCE(l.repaired_fix_pv, 0);
"@
}

function Get-ValidateSql {
  param([string]$WhereClause)
@"
USE rt_dw2;
SELECT
    b.window_start,
    b.window_end,
    b.pv AS before_pv,
    d.current_fix_pv,
    d.repaired_fix_pv,
    d.delta_fix_pv,
    b.pv + d.delta_fix_pv AS expected_pv,
    a.pv AS actual_pv,
    l.repair_batch_id,
    l.repair_time
FROM rt_dw2.ads_visit_main_bak b
JOIN (
    SELECT
        f.window_start,
        f.window_end,
        f.fix_pv AS current_fix_pv,
        COALESCE(l.repaired_fix_pv, 0) AS repaired_fix_pv,
        f.fix_pv - COALESCE(l.repaired_fix_pv, 0) AS delta_fix_pv
    FROM (
        SELECT
            window_start,
            window_end,
            COUNT(*) AS fix_rows,
            SUM(pv) AS fix_pv
        FROM rt_dw2.ads_visit_fix
        WHERE $WhereClause
        GROUP BY
            window_start,
            window_end
    ) f
    LEFT JOIN rt_dw2.ads_visit_fix_repair_log l
        ON f.window_start = l.window_start
       AND f.window_end = l.window_end
    WHERE f.fix_rows > COALESCE(l.repaired_fix_rows, 0)
       OR f.fix_pv > COALESCE(l.repaired_fix_pv, 0)
) d
    ON b.window_start = d.window_start
   AND b.window_end = d.window_end
LEFT JOIN rt_dw2.ads_visit_main a
    ON b.window_start = a.window_start
   AND b.window_end = a.window_end
LEFT JOIN rt_dw2.ads_visit_fix_repair_log l
    ON b.window_start = l.window_start
   AND b.window_end = l.window_end
ORDER BY
    b.window_start;
"@
}

function Get-RepairLogByBatchSql {
  param([string]$BatchId)
@"
USE rt_dw2;
SELECT
    window_start,
    window_end,
    repaired_fix_rows,
    repaired_fix_pv,
    repair_batch_id,
    repair_time
FROM rt_dw2.ads_visit_fix_repair_log
WHERE repair_batch_id = '$BatchId'
ORDER BY window_start;
"@
}

function Get-BootstrapRepairLogSql {
  param(
    [string]$WhereClause,
    [string]$BatchId
  )
@"
USE rt_dw2;
INSERT INTO rt_dw2.ads_visit_fix_repair_log
SELECT
    f.window_start,
    f.window_end,
    f.fix_rows AS repaired_fix_rows,
    f.fix_pv AS repaired_fix_pv,
    '$BatchId' AS repair_batch_id,
    NOW(3) AS repair_time
FROM (
    SELECT
        window_start,
        window_end,
        COUNT(*) AS fix_rows,
        SUM(pv) AS fix_pv
    FROM rt_dw2.ads_visit_fix
    WHERE $WhereClause
    GROUP BY
        window_start,
        window_end
) f;
"@
}

$whereClause = Get-WhereClause
$repairBatchId = [guid]::NewGuid().ToString('N').Substring(0, 12)
Write-Log "Repair started. Apply=$Apply, BootstrapCurrentState=$BootstrapCurrentState, Where=$whereClause"
Write-Log "Repair batch id: $repairBatchId"
Write-Log "Log file: $logFile"

try {
  Write-Log 'Preparing repair log table.'
  Invoke-DorisSql -Sql (Get-PrepareRepairLogTableSql) | Out-Null

  if ($BootstrapCurrentState) {
    Write-Log 'Bootstrapping repair log from current fix table state.'
    Invoke-DorisSql -Sql (Get-BootstrapRepairLogSql -WhereClause $whereClause -BatchId $repairBatchId) | Out-Null
    $repairLog = Invoke-DorisSql -Sql (Get-RepairLogByBatchSql -BatchId $repairBatchId)
    Write-Log 'Bootstrap log rows:'
    Write-Host $repairLog
    Write-Log 'Bootstrap finished successfully.'
    exit 0
  }

  $affectedWindows = Invoke-DorisSql -Sql (Get-AffectedWindowsSql -WhereClause $whereClause)

  if ([string]::IsNullOrWhiteSpace($affectedWindows)) {
    Write-Log 'No unrepaired windows found. Skip repair.'
    exit 0
  }

  Write-Log 'Affected windows:'
  Write-Host $affectedWindows

  $preview = Invoke-DorisSql -Sql (Get-PreviewSql -WhereClause $whereClause)
  Write-Log 'Repair preview:'
  Write-Host $preview

  if (-not $Apply) {
    Write-Log 'Preview mode only. Add -Apply to write repaired values back to ads_visit_main.'
    exit 0
  }

  Write-Log 'Preparing backup table.'
  Invoke-DorisSql -Sql (Get-PrepareBackupTableSql) | Out-Null

  Write-Log 'Refreshing backup data for affected windows.'
  Invoke-DorisSql -Sql (Get-RefreshBackupSql -WhereClause $whereClause) | Out-Null

  Write-Log 'Applying repaired values to ads_visit_main.'
  Invoke-DorisSql -Sql (Get-ApplyRepairSql -WhereClause $whereClause) | Out-Null

  $validation = Invoke-DorisSql -Sql (Get-ValidateSql -WhereClause $whereClause)
  Write-Log 'Repair validation:'
  Write-Host $validation

  Write-Log 'Updating repair log table.'
  Invoke-DorisSql -Sql (Get-UpdateRepairLogSql -WhereClause $whereClause -BatchId $repairBatchId) | Out-Null

  $repairLog = Invoke-DorisSql -Sql (Get-RepairLogByBatchSql -BatchId $repairBatchId)
  Write-Log 'Repair log rows for this batch:'
  Write-Host $repairLog

  Write-Log 'Repair finished successfully.'
}
catch {
  Write-Log $_.Exception.Message 'ERROR'
  Write-Host "Log file: $logFile"
  exit 1
}
