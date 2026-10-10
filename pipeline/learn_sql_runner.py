import argparse
import subprocess
from datetime import datetime
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(
        description="Render a SQL template with run_dt and execute it with spark-sql."
    )
    parser.add_argument(
        "--run-dt",
        required=True,
        help="Business date to process, format: YYYY-MM-DD. Example: 2026-03-05",
    )
    parser.add_argument(
        "--template",
        required=True,
        help="Path to the SQL template file.",
    )
    parser.add_argument(
        "--output",
        required=True,
        help="Path to write the rendered SQL file.",
    )
    return parser.parse_args()


def validate_run_dt(run_dt):
    try:
        return datetime.strptime(run_dt, "%Y-%m-%d").date()
    except ValueError as exc:
        raise ValueError(
            f"run_dt must use YYYY-MM-DD format, got: {run_dt}"
        ) from exc


def render_sql_template(template_path, output_path, run_dt):
    template_text = template_path.read_text(encoding="utf-8")
    rendered_sql = template_text.replace("__RUN_DT__", str(run_dt))

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(rendered_sql, encoding="utf-8")

    return output_path


def run_command(command):
    print(f"Running command: {' '.join(command)}")

    result = subprocess.run(
        command,
        text=True,
        capture_output=True,
    )

    print(f"returncode: {result.returncode}")

    if result.stdout:
        print("stdout:")
        print(result.stdout.strip())

    if result.stderr:
        print("stderr:")
        print(result.stderr.strip())

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
    run_command(
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


def main():
    args = parse_args()

    try:
        run_dt = validate_run_dt(args.run_dt)
        template_path = Path(args.template)
        output_path = Path(args.output)

        if not template_path.exists():
            raise FileNotFoundError(f"Template file not found: {template_path}")

        rendered_sql_path = render_sql_template(template_path, output_path, run_dt)
        execute_spark_sql(rendered_sql_path)
    except Exception as exc:
        raise SystemExit(str(exc)) from exc

    print("SQL template rendered and executed successfully.")


if __name__ == "__main__":
    main()
