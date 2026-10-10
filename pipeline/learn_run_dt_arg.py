import argparse
from datetime import datetime


def parse_args():
    parser = argparse.ArgumentParser(
        description="Learn how to parse a data warehouse run_dt parameter."
    )
    parser.add_argument(
        "--run-dt",
        required=True,
        help="Business date to process, format: YYYY-MM-DD. Example: 2026-03-05",
    )
    return parser.parse_args()


def validate_run_dt(run_dt):
    try:
        return datetime.strptime(run_dt, "%Y-%m-%d").date()
    except ValueError as exc:
        raise ValueError(
            f"run_dt must use YYYY-MM-DD format, got: {run_dt}"
        ) from exc


def main():
    args = parse_args()
    try:
        run_dt = validate_run_dt(args.run_dt)
    except ValueError as exc:
        raise SystemExit(str(exc)) from exc

    print(f"本次离线跑批业务日期 run_dt = {run_dt}")


if __name__ == "__main__":
    main()
