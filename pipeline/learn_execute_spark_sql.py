import argparse
import subprocess
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(
        description="Copy a local SQL file into hadoop-spark and execute it with spark-sql."
    )
    parser.add_argument(
        "--sql-file",
        required=True,
        help="Local SQL file to execute.",
    )
    return parser.parse_args()


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
    sql_file = Path(args.sql_file)

    try:
        if not sql_file.exists():
            raise FileNotFoundError(f"SQL file not found: {sql_file}")

        execute_spark_sql(sql_file)
    except Exception as exc:
        raise SystemExit(str(exc)) from exc

    print("Spark SQL executed successfully.")


if __name__ == "__main__":
    main()
