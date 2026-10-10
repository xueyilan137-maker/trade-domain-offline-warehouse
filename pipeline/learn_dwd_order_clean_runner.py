import argparse
import subprocess
from datetime import datetime
from pathlib import Path


LOG_FILE = None

STEPS = [
    {
        "name": "DWD Order Dirty Capture",
        "template": Path("pipeline/sql/dwd/11_dwd_order_dirty_di.sql.tpl"),
        "output_name": "11_dwd_order_dirty_di.sql",
    },
    {
        "name": "DWD Order Clean",
        "template": Path("pipeline/sql/dwd/10_dwd_order_clean_di.sql.tpl"),
        "output_name": "10_dwd_order_clean_di.sql",
    },
    {
        "name": "DWD Order Cancel Clean",
        "template": Path("pipeline/sql/dwd/12_dwd_order_cancel_clean_di.sql.tpl"),
        "output_name": "12_dwd_order_cancel_clean_di.sql",
    },
    {
        "name": "DWD Order Refund Clean",
        "template": Path("pipeline/sql/dwd/13_dwd_order_refund_clean_di.sql.tpl"),
        "output_name": "13_dwd_order_refund_clean_di.sql",
    },
    {
        "name": "DWD Order Clean Quality",
        "template": Path("pipeline/sql/dwd/20_dwd_order_clean_quality.sql.tpl"),
        "output_name": "20_dwd_order_clean_quality.sql",
    },
    {
        "name": "DWD Order Dirty Quality",
        "template": Path("pipeline/sql/dwd/30_dwd_order_dirty_quality.sql.tpl"),
        "output_name": "30_dwd_order_dirty_quality.sql",
    },
    {
        "name": "DWD Order Cancel Quality",
        "template": Path("pipeline/sql/dwd/40_dwd_order_cancel_quality.sql.tpl"),
        "output_name": "40_dwd_order_cancel_quality.sql",
    },
    {
        "name": "DWD Order Refund Quality",
        "template": Path("pipeline/sql/dwd/50_dwd_order_refund_quality.sql.tpl"),
        "output_name": "50_dwd_order_refund_quality.sql",
    },
]


def parse_args():
    parser = argparse.ArgumentParser(
        description="Learning runner for the real DWD order clean pipeline."
    )
    parser.add_argument(
        "--run-dt",
        required=True,
        help="Business date to process, format: YYYY-MM-DD. Example: 2026-03-05",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Render SQL files and print steps, but do not execute spark-sql.",
    )
    return parser.parse_args()


def validate_run_dt(run_dt):
    try:
        return datetime.strptime(run_dt, "%Y-%m-%d").date()
    except ValueError as exc:
        raise ValueError(
            f"run_dt must use YYYY-MM-DD format, got: {run_dt}"
        ) from exc


def init_log_file(run_dt):
    log_dir = Path("pipeline/logs")
    log_dir.mkdir(parents=True, exist_ok=True)

    log_ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    return log_dir / f"learn_dwd_order_clean_runner_{run_dt}_{log_ts}.log"


def log_info(message):
    log_line = f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] {message}"
    print(log_line)

    if LOG_FILE is not None:
        with LOG_FILE.open("a", encoding="utf-8") as log_file:
            log_file.write(log_line + "\n")


def render_sql_template(template_path, output_path, run_dt):
    template_text = template_path.read_text(encoding="utf-8")
    rendered_sql = template_text.replace("__RUN_DT__", str(run_dt))

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(rendered_sql, encoding="utf-8")

    return output_path


def run_command(command):
    log_info(f"Running command: {' '.join(command)}")

    result = subprocess.run(
        command,
        text=True,
        capture_output=True,
    )

    log_info(f"returncode: {result.returncode}")

    if result.stdout:
        log_info("stdout:")
        for line in result.stdout.strip().splitlines():
            log_info(line)

    if result.stderr:
        log_info("stderr:")
        for line in result.stderr.strip().splitlines():
            log_info(line)

    if result.returncode != 0:
        raise RuntimeError(f"Command failed with returncode={result.returncode}")

    return result


def execute_spark_sql(sql_file):
    local_sql_path = sql_file.resolve()
    container_sql_path = f"/tmp/{sql_file.name}"

    run_command(
        [
            "docker",
            "cp",
            str(local_sql_path),
            f"hadoop-spark:{container_sql_path}",
        ]
    )
    return run_command(
        [
            "docker",
            "exec",
            "hadoop-spark",
            "/spark/bin/spark-sql",
            "--master",
            "local[*]",
            "-f",
            container_sql_path,
        ]
    )


def run_step(step, run_dt, dry_run):
    log_info(f"===== Step started: {step['name']} =====")

    if not step["template"].exists():
        raise FileNotFoundError(f"Template file not found: {step['template']}")

    output_path = (
        Path("pipeline/generated/python_learning/dwd_order_clean")
        / str(run_dt)
        / step["output_name"]
    )
    rendered_sql_path = render_sql_template(
        step["template"],
        output_path,
        run_dt,
    )
    log_info(f"Rendered SQL: {rendered_sql_path}")

    if dry_run:
        log_info(f"Dry run enabled. Skip spark-sql execution for {step['name']}.")
    else:
        execute_spark_sql(rendered_sql_path)

    log_info(f"===== Step finished: {step['name']} =====")


def main():
    global LOG_FILE

    args = parse_args()

    try:
        run_dt = validate_run_dt(args.run_dt)
        LOG_FILE = init_log_file(run_dt)

        log_info(f"Log file: {LOG_FILE}")
        log_info(f"DWD order clean learning runner started. run_dt={run_dt}")
        log_info(f"dry_run={args.dry_run}")

        for step in STEPS:
            run_step(step, run_dt, args.dry_run)
    except Exception as exc:
        log_info(f"DWD order clean learning runner failed: {exc}")
        raise SystemExit(str(exc)) from exc

    log_info("DWD order clean learning runner finished successfully.")


if __name__ == "__main__":
    main()
