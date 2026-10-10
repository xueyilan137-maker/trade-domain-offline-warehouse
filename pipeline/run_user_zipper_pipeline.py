import argparse
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from uuid import uuid4


PROJECT_ROOT = Path(__file__).resolve().parent.parent
SQL_DIR = PROJECT_ROOT / "pipeline" / "sql" / "zipper"
GENERATED_DIR = PROJECT_ROOT / "pipeline" / "generated" / "zipper"
LOG_DIR = PROJECT_ROOT / "pipeline" / "logs"


class ZipperLogger:
    def __init__(self, run_dt: str) -> None:
        GENERATED_DIR.mkdir(parents=True, exist_ok=True)
        LOG_DIR.mkdir(parents=True, exist_ok=True)
        ts = datetime.now().strftime("%Y%m%d_%H%M%S_%f")[:-3]
        run_id = uuid4().hex[:8]
        self.log_file = LOG_DIR / f"run_user_zipper_pipeline_{run_dt}_{ts}_{run_id}.log"
        self.log_file.write_text("", encoding="utf-8")

    def write(self, message: str, level: str = "INFO") -> None:
        ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        line = f"[{ts}] [{level}] {message}"
        print(line)
        with self.log_file.open("a", encoding="utf-8") as f:
            f.write(line + "\n")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run the Spark-based user zipper pipeline.")
    parser.add_argument("--run-dt", required=True, help="Pipeline date in YYYY-MM-DD format.")
    parser.add_argument("--init-tables", action="store_true", help="Create required ODS/DWD/DIM tables before running.")
    parser.add_argument("--init-only", action="store_true", help="Run table initialization only and skip DWD/zipper steps.")
    return parser.parse_args()


def validate_run_dt(run_dt: str) -> None:
    datetime.strptime(run_dt, "%Y-%m-%d")


def new_sql_from_template(template_name: str, output_name: str, run_dt: str) -> Path:
    content = (SQL_DIR / template_name).read_text(encoding="utf-8")
    content = content.replace("__RUN_DT__", run_dt)
    out_path = GENERATED_DIR / output_name
    out_path.write_text(content, encoding="utf-8")
    return out_path


def invoke_spark_sql_file(local_sql_path: Path, sql_label: str, logger: ZipperLogger) -> str:
    container_sql = f"/tmp/{local_sql_path.name}"
    logger.write(f"Executing SQL file: {sql_label}")

    copy_result = subprocess.run(
        ["docker", "cp", str(local_sql_path), f"hadoop-spark:{container_sql}"],
        text=True,
        capture_output=True,
        encoding="utf-8",
    )
    if copy_result.returncode != 0:
        raise RuntimeError(copy_result.stderr.strip() or copy_result.stdout.strip() or f"Failed to copy SQL file: {sql_label}")

    result = subprocess.run(
        ["docker", "exec", "hadoop-spark", "bash", "-lc", f"/spark/bin/spark-sql --master local[*] -f {container_sql}"],
        text=True,
        capture_output=True,
        encoding="utf-8",
    )

    output = (result.stdout or "") + (result.stderr or "")
    if output.strip():
        for line in output.strip().splitlines():
            level = "WARN" if "WARN" in line else "SPARK"
            logger.write(line, level)

    if result.returncode != 0:
        raise RuntimeError(f"SQL execution failed: {sql_label}")

    return output


def invoke_template_step(step_name: str, template_name: str, output_name: str, run_dt: str, logger: ZipperLogger) -> None:
    logger.write(f"Starting {step_name} step for {run_dt}")
    sql_path = new_sql_from_template(template_name, output_name, run_dt)
    invoke_spark_sql_file(sql_path, output_name, logger)
    logger.write(f"{step_name} step finished for {run_dt}")


def invoke_quality_checks(run_dt: str, logger: ZipperLogger) -> None:
    logger.write(f"Starting quality check step for {run_dt}")
    quality_sql = new_sql_from_template("30_dim_user_zipper_quality.sql.tpl", "30_dim_user_zipper_quality.sql", run_dt)
    quality_output = invoke_spark_sql_file(quality_sql, "30_dim_user_zipper_quality.sql", logger)
    if "check failed" in quality_output:
        raise RuntimeError(f"Quality check failed for {run_dt}. Check log: {logger.log_file}")
    logger.write(f"Quality check passed for {run_dt}")


def main() -> int:
    args = parse_args()
    validate_run_dt(args.run_dt)
    logger = ZipperLogger(args.run_dt)

    logger.write(f"User zipper pipeline started. RunDt={args.run_dt}")
    logger.write(f"Log file: {logger.log_file}")

    init_sql_path = SQL_DIR / "00_init_user_zipper_tables.sql"

    if args.init_tables:
        logger.write("Starting init step")
        invoke_spark_sql_file(init_sql_path, "00_init_user_zipper_tables.sql", logger)
        logger.write("Init step finished")

    if args.init_only:
        logger.write("Init only mode enabled. Skip DWD/zipper steps.")
        return 0

    invoke_template_step("DWD Clean", "10_dwd_user_info_clean.sql.tpl", "10_dwd_user_info_clean.sql", args.run_dt, logger)
    invoke_template_step("Zipper Merge", "20_dim_user_zipper_merge.sql.tpl", "20_dim_user_zipper_merge.sql", args.run_dt, logger)
    invoke_quality_checks(args.run_dt, logger)

    logger.write(f"User zipper pipeline finished successfully for {args.run_dt}")
    print("Validate with:")
    print("SELECT * FROM hive_demo.dim_user_zipper ORDER BY user_id, start_date;")
    print(f"SELECT * FROM hive_demo.dwd_user_info_clean_di WHERE dt = '{args.run_dt}';")
    print(f"Log file: {logger.log_file}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:  # pragma: no cover
        fallback_run_dt = "unknown"
        if "--run-dt" in sys.argv:
          idx = sys.argv.index("--run-dt")
          if idx + 1 < len(sys.argv):
              fallback_run_dt = sys.argv[idx + 1]
        logger = ZipperLogger(fallback_run_dt)
        logger.write(str(exc), "ERROR")
        sys.exit(1)
