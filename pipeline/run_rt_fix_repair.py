import argparse
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from uuid import uuid4


PROJECT_ROOT = Path(r"C:\Users\21495\Documents\New project\dw_project")
LOG_DIR = PROJECT_ROOT / "pipeline" / "logs"
MAIN_TABLE = "rt_dw2.ads_visit_main"
FIX_TABLE = "rt_dw2.ads_visit_fix"
BACKUP_TABLE = "rt_dw2.ads_visit_main_bak"
REPAIR_LOG_TABLE = "rt_dw2.ads_visit_fix_repair_log"


class RepairLogger:
    def __init__(self) -> None:
        LOG_DIR.mkdir(parents=True, exist_ok=True)
        ts = datetime.now().strftime("%Y%m%d_%H%M%S_%f")[:-3]
        self.log_file = LOG_DIR / f"run_rt_fix_repair_py_{ts}_{Path.cwd().name}.log"
        self.log_file.write_text("", encoding="utf-8")

    def write(self, message: str, level: str = "INFO") -> None:
        ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        line = f"[{ts}] [{level}] {message}"
        print(line)
        with self.log_file.open("a", encoding="utf-8") as f:
            f.write(line + "\n")


logger = RepairLogger()


def run_mysql(sql: str) -> str:
    cmd = [
        "docker",
        "exec",
        "-i",
        "rt-doris-fe",
        "bash",
        "-lc",
        "mysql -h127.0.0.1 -P9030 -uroot -N -B",
    ]
    result = subprocess.run(
        cmd,
        input=sql,
        text=True,
        capture_output=True,
        encoding="utf-8",
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or "Unknown mysql error")
    return result.stdout.strip()


def build_where_clause(start_window: str | None, end_window: str | None) -> str:
    clauses: list[str] = []
    if start_window:
        clauses.append(f"window_start >= '{start_window}'")
    if end_window:
        clauses.append(f"window_start < '{end_window}'")
    return " AND ".join(clauses) if clauses else "1 = 1"


def sql_prepare_backup_table() -> str:
    return f"""
CREATE TABLE IF NOT EXISTS {BACKUP_TABLE} (
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
""".strip()


def sql_prepare_repair_log_table() -> str:
    return f"""
CREATE TABLE IF NOT EXISTS {REPAIR_LOG_TABLE} (
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
""".strip()


def sql_find_affected_windows(where_clause: str) -> str:
    return f"""
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
    FROM {FIX_TABLE}
    WHERE {where_clause}
    GROUP BY
        window_start,
        window_end
) f
LEFT JOIN {REPAIR_LOG_TABLE} l
    ON f.window_start = l.window_start
   AND f.window_end = l.window_end
WHERE f.fix_rows > COALESCE(l.repaired_fix_rows, 0)
   OR f.fix_pv > COALESCE(l.repaired_fix_pv, 0)
ORDER BY
    f.window_start;
""".strip()


def sql_preview_repair(where_clause: str) -> str:
    return f"""
USE rt_dw2;
SELECT
    m.window_start,
    m.window_end,
    m.pv AS main_pv,
    d.current_fix_pv,
    d.repaired_fix_pv,
    d.delta_fix_pv,
    m.pv + d.delta_fix_pv AS final_pv
FROM {MAIN_TABLE} m
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
        FROM {FIX_TABLE}
        WHERE {where_clause}
        GROUP BY
            window_start,
            window_end
    ) f
    LEFT JOIN {REPAIR_LOG_TABLE} l
        ON f.window_start = l.window_start
       AND f.window_end = l.window_end
    WHERE f.fix_rows > COALESCE(l.repaired_fix_rows, 0)
       OR f.fix_pv > COALESCE(l.repaired_fix_pv, 0)
) d
    ON m.window_start = d.window_start
   AND m.window_end = d.window_end
ORDER BY
    m.window_start;
""".strip()


def sql_refresh_backup(where_clause: str) -> str:
    return f"""
USE rt_dw2;
TRUNCATE TABLE {BACKUP_TABLE};
INSERT INTO {BACKUP_TABLE}
SELECT
    m.window_start,
    m.window_end,
    m.pv
FROM {MAIN_TABLE} m
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
        FROM {FIX_TABLE}
        WHERE {where_clause}
        GROUP BY
            window_start,
            window_end
    ) f
    LEFT JOIN {REPAIR_LOG_TABLE} l
        ON f.window_start = l.window_start
       AND f.window_end = l.window_end
    WHERE f.fix_rows > COALESCE(l.repaired_fix_rows, 0)
       OR f.fix_pv > COALESCE(l.repaired_fix_pv, 0)
) x
    ON m.window_start = x.window_start
   AND m.window_end = x.window_end;
""".strip()


def sql_apply_repair(where_clause: str) -> str:
    return f"""
USE rt_dw2;
INSERT INTO {MAIN_TABLE}
SELECT
    b.window_start,
    b.window_end,
    b.pv + d.delta_fix_pv AS pv
FROM {BACKUP_TABLE} b
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
        FROM {FIX_TABLE}
        WHERE {where_clause}
        GROUP BY
            window_start,
            window_end
    ) f
    LEFT JOIN {REPAIR_LOG_TABLE} l
        ON f.window_start = l.window_start
       AND f.window_end = l.window_end
    WHERE f.fix_rows > COALESCE(l.repaired_fix_rows, 0)
       OR f.fix_pv > COALESCE(l.repaired_fix_pv, 0)
) d
    ON b.window_start = d.window_start
   AND b.window_end = d.window_end;
""".strip()


def sql_update_repair_log(where_clause: str, batch_id: str) -> str:
    return f"""
USE rt_dw2;
INSERT INTO {REPAIR_LOG_TABLE}
SELECT
    f.window_start,
    f.window_end,
    f.fix_rows AS repaired_fix_rows,
    f.fix_pv AS repaired_fix_pv,
    '{batch_id}' AS repair_batch_id,
    NOW(3) AS repair_time
FROM (
    SELECT
        window_start,
        window_end,
        COUNT(*) AS fix_rows,
        SUM(pv) AS fix_pv
    FROM {FIX_TABLE}
    WHERE {where_clause}
    GROUP BY
        window_start,
        window_end
) f
LEFT JOIN {REPAIR_LOG_TABLE} l
    ON f.window_start = l.window_start
   AND f.window_end = l.window_end
WHERE f.fix_rows > COALESCE(l.repaired_fix_rows, 0)
   OR f.fix_pv > COALESCE(l.repaired_fix_pv, 0);
""".strip()


def sql_validate_repair(where_clause: str) -> str:
    return f"""
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
FROM {BACKUP_TABLE} b
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
        FROM {FIX_TABLE}
        WHERE {where_clause}
        GROUP BY
            window_start,
            window_end
    ) f
    LEFT JOIN {REPAIR_LOG_TABLE} l
        ON f.window_start = l.window_start
       AND f.window_end = l.window_end
    WHERE f.fix_rows > COALESCE(l.repaired_fix_rows, 0)
       OR f.fix_pv > COALESCE(l.repaired_fix_pv, 0)
) d
    ON b.window_start = d.window_start
   AND b.window_end = d.window_end
LEFT JOIN {MAIN_TABLE} a
    ON b.window_start = a.window_start
   AND b.window_end = a.window_end
LEFT JOIN {REPAIR_LOG_TABLE} l
    ON b.window_start = l.window_start
   AND b.window_end = l.window_end
ORDER BY
    b.window_start;
""".strip()


def sql_repair_log_by_batch(batch_id: str) -> str:
    return f"""
USE rt_dw2;
SELECT
    window_start,
    window_end,
    repaired_fix_rows,
    repaired_fix_pv,
    repair_batch_id,
    repair_time
FROM {REPAIR_LOG_TABLE}
WHERE repair_batch_id = '{batch_id}'
ORDER BY window_start;
""".strip()


def sql_bootstrap_repair_log(where_clause: str, batch_id: str) -> str:
    return f"""
USE rt_dw2;
INSERT INTO {REPAIR_LOG_TABLE}
SELECT
    f.window_start,
    f.window_end,
    f.fix_rows AS repaired_fix_rows,
    f.fix_pv AS repaired_fix_pv,
    '{batch_id}' AS repair_batch_id,
    NOW(3) AS repair_time
FROM (
    SELECT
        window_start,
        window_end,
        COUNT(*) AS fix_rows,
        SUM(pv) AS fix_pv
    FROM {FIX_TABLE}
    WHERE {where_clause}
    GROUP BY
        window_start,
        window_end
) f;
""".strip()


def main() -> int:
    parser = argparse.ArgumentParser(description="Idempotent realtime repair from fix table into main table.")
    parser.add_argument("--start-window", help="Inclusive lower bound, e.g. 2026-04-21 00:00:00")
    parser.add_argument("--end-window", help="Exclusive upper bound, e.g. 2026-04-22 00:00:00")
    parser.add_argument("--apply", action="store_true", help="Apply repaired values to ads_visit_main.")
    parser.add_argument(
        "--bootstrap-current-state",
        action="store_true",
        help="Initialize repair-log table from current fix-table totals.",
    )
    args = parser.parse_args()

    where_clause = build_where_clause(args.start_window, args.end_window)
    batch_id = uuid4().hex[:12]

    logger.write(
        f"Repair started. apply={args.apply}, bootstrap_current_state={args.bootstrap_current_state}, where={where_clause}"
    )
    logger.write(f"Repair batch id: {batch_id}")
    logger.write(f"Log file: {logger.log_file}")

    run_mysql(sql_prepare_repair_log_table())

    if args.bootstrap_current_state:
        logger.write("Bootstrapping repair log from current fix-table state.")
        run_mysql(sql_bootstrap_repair_log(where_clause, batch_id))
        repair_log = run_mysql(sql_repair_log_by_batch(batch_id))
        logger.write("Bootstrap log rows:")
        print(repair_log or "(empty)")
        logger.write("Bootstrap finished successfully.")
        return 0

    affected = run_mysql(sql_find_affected_windows(where_clause))
    if not affected:
        logger.write("No unrepaired windows found. Skip repair.")
        return 0

    logger.write("Affected windows:")
    print(affected)

    preview = run_mysql(sql_preview_repair(where_clause))
    logger.write("Repair preview:")
    print(preview or "(empty)")

    if not args.apply:
        logger.write("Preview mode only. Add --apply to write repaired values back to ads_visit_main.")
        return 0

    logger.write("Preparing backup table.")
    run_mysql(sql_prepare_backup_table())

    logger.write("Refreshing backup data for affected windows.")
    run_mysql(sql_refresh_backup(where_clause))

    logger.write("Applying repaired values to ads_visit_main.")
    run_mysql(sql_apply_repair(where_clause))

    validation = run_mysql(sql_validate_repair(where_clause))
    logger.write("Repair validation:")
    print(validation or "(empty)")

    logger.write("Updating repair log table.")
    run_mysql(sql_update_repair_log(where_clause, batch_id))

    repair_log = run_mysql(sql_repair_log_by_batch(batch_id))
    logger.write("Repair log rows for this batch:")
    print(repair_log or "(empty)")

    logger.write("Repair finished successfully.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:  # pragma: no cover
        logger.write(str(exc), "ERROR")
        sys.exit(1)
