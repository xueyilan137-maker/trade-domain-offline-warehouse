import argparse
import subprocess
from datetime import datetime
from pathlib import Path


LOG_FILE = None

STEPS = [
    {
        "name": "Select run_dt and current database",
        "template": Path("pipeline/sql/learning/select_run_dt.sql.tpl"),
        "output": Path("pipeline/generated/python_learning/multi_step/01_select_run_dt.sql"),
    },
    {
        "name": "Select current database and run_dt",
        "template": Path("pipeline/sql/learning/select_current_database.sql.tpl"),
        "output": Path(
            "pipeline/generated/python_learning/multi_step/02_select_current_database.sql"
        ),
    },
]

FAIL_STEP = {
    "name": "Select not exist table for failure learning",
    "template": Path("pipeline/sql/learning/select_not_exist_table.sql.tpl"),
    "output": Path(
        "pipeline/generated/python_learning/multi_step/99_select_not_exist_table.sql"
    ),
}

DQ_CHECK_STEP = {
    "name": "Check DQ failures",
    "template": Path("pipeline/sql/learning/check_dq_failures.sql.tpl"),
    "output": Path("pipeline/generated/python_learning/multi_step/90_check_dq_failures.sql"),
    "fail_on_stdout": True,
}


def parse_args():
    parser = argparse.ArgumentParser(
        description="Run multiple SQL template steps with a run_dt parameter."
    )
    parser.add_argument(
        "--run-dt",
        required=True,
        help="Business date to process, format: YYYY-MM-DD. Example: 2026-03-05",
    )
    parser.add_argument(
        "--include-fail-step",
        action="store_true",
        help="Include a failing SQL step for learning failure handling.",
    )
    parser.add_argument(
        "--check-dq",
        action="store_true",
        help="Query dq_check_result_di for non-PASS records after successful steps.",
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
    return log_dir / f"learn_multi_step_runner_{run_dt}_{log_ts}.log"


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
    result = run_command(
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
    return result


def run_step(step, run_dt):
    log_info(f"===== Step started: {step['name']} =====")

    if not step["template"].exists():
        raise FileNotFoundError(f"Template file not found: {step['template']}")

    rendered_sql_path = render_sql_template(
        step["template"],
        step["output"],
        run_dt,
    )
    log_info(f"Rendered SQL: {rendered_sql_path}")
    result = execute_spark_sql(rendered_sql_path)

    if step.get("fail_on_stdout") and result.stdout.strip():
        raise RuntimeError(
            f"Step found non-empty query result and is configured to fail: {step['name']}"
        )

    log_info(f"===== Step finished: {step['name']} =====")


def main():
    global LOG_FILE

    args = parse_args()

    try:
        run_dt = validate_run_dt(args.run_dt)
        LOG_FILE = init_log_file(run_dt)
        log_info(f"Log file: {LOG_FILE}")
        log_info(f"Pipeline started. run_dt={run_dt}")

        steps = list(STEPS)
        if args.include_fail_step:
            steps.append(FAIL_STEP)
            log_info("Fail step enabled for learning.")
        if args.check_dq:
            steps.append(DQ_CHECK_STEP)
            log_info("DQ check step enabled.")

        for step in steps:
            run_step(step, run_dt)
    except Exception as exc:
        log_info(f"Pipeline failed: {exc}")
        raise SystemExit(str(exc)) from exc

    log_info("All steps finished successfully.")


if __name__ == "__main__":
    main()
