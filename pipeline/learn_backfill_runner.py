import argparse
import subprocess
from datetime import datetime, timedelta
from pathlib import Path


LOG_FILE = None

STEPS = [
    {
        "name": "Select run_dt and current database",
        "template": Path("pipeline/sql/learning/select_run_dt.sql.tpl"),
        "output_template": "pipeline/generated/python_learning/backfill/{run_dt}/01_select_run_dt.sql",
    },
    {
        "name": "Select current database and run_dt",
        "template": Path("pipeline/sql/learning/select_current_database.sql.tpl"),
        "output_template": "pipeline/generated/python_learning/backfill/{run_dt}/02_select_current_database.sql",
    },
]


def parse_args():
    parser = argparse.ArgumentParser(
        description="Run multiple SQL template steps for a date range."
    )
    parser.add_argument(
        "--start-dt",
        required=True,
        help="Start business date, format: YYYY-MM-DD. Example: 2026-03-01",
    )
    parser.add_argument(
        "--end-dt",
        required=True,
        help="End business date, format: YYYY-MM-DD. Example: 2026-03-05",
    )
    return parser.parse_args()


def parse_date(date_text, arg_name):
    try:
        return datetime.strptime(date_text, "%Y-%m-%d").date()
    except ValueError as exc:
        raise ValueError(
            f"{arg_name} must use YYYY-MM-DD format, got: {date_text}"
        ) from exc


def date_range(start_dt, end_dt):
    current_dt = start_dt
    while current_dt <= end_dt:
        yield current_dt
        current_dt += timedelta(days=1)


def init_log_file(start_dt, end_dt):
    log_dir = Path("pipeline/logs")
    log_dir.mkdir(parents=True, exist_ok=True)

    log_ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    return log_dir / f"learn_backfill_runner_{start_dt}_{end_dt}_{log_ts}.log"


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


def run_step(step, run_dt):
    log_info(f"===== Step started: {step['name']} run_dt={run_dt} =====")

    if not step["template"].exists():
        raise FileNotFoundError(f"Template file not found: {step['template']}")

    output_path = Path(step["output_template"].format(run_dt=run_dt))
    rendered_sql_path = render_sql_template(
        step["template"],
        output_path,
        run_dt,
    )
    log_info(f"Rendered SQL: {rendered_sql_path}")
    execute_spark_sql(rendered_sql_path)

    log_info(f"===== Step finished: {step['name']} run_dt={run_dt} =====")


def run_one_day(run_dt):
    log_info(f"---------- Run date started: {run_dt} ----------")
    for step in STEPS:
        run_step(step, run_dt)
    log_info(f"---------- Run date finished: {run_dt} ----------")


def main():
    global LOG_FILE

    args = parse_args()

    try:
        start_dt = parse_date(args.start_dt, "--start-dt")
        end_dt = parse_date(args.end_dt, "--end-dt")

        if start_dt > end_dt:
            raise ValueError(f"start_dt {start_dt} cannot be later than end_dt {end_dt}")

        LOG_FILE = init_log_file(start_dt, end_dt)
        log_info(f"Log file: {LOG_FILE}")
        log_info(f"Backfill started. start_dt={start_dt}, end_dt={end_dt}")

        for run_dt in date_range(start_dt, end_dt):
            run_one_day(run_dt)
    except Exception as exc:
        log_info(f"Backfill failed: {exc}")
        raise SystemExit(str(exc)) from exc

    log_info("Backfill finished successfully.")


if __name__ == "__main__":
    main()
