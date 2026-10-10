import argparse
import subprocess
from datetime import datetime, timedelta
from pathlib import Path


LOG_FILE = None


SUBJECT_ORDER = [
    "dwd_order",
    "fct_order",
    "refund_anomaly",
    "dws_ads",
    "payment",
    "multi_theme",
]


SUBJECTS = {
    "dwd_order": {
        "desc": "Order, cancel, and refund DWD clean/dirty pipeline.",
        "init_sql": [
            Path("pipeline/sql/dwd/00_init_order_clean_tables.sql"),
        ],
        "daily_templates": [
            Path("pipeline/sql/dwd/11_dwd_order_dirty_di.sql.tpl"),
            Path("pipeline/sql/dwd/10_dwd_order_clean_di.sql.tpl"),
            Path("pipeline/sql/dwd/12_dwd_order_cancel_clean_di.sql.tpl"),
            Path("pipeline/sql/dwd/13_dwd_order_refund_clean_di.sql.tpl"),
            Path("pipeline/sql/dwd/20_dwd_order_clean_quality.sql.tpl"),
            Path("pipeline/sql/dwd/30_dwd_order_dirty_quality.sql.tpl"),
            Path("pipeline/sql/dwd/40_dwd_order_cancel_quality.sql.tpl"),
            Path("pipeline/sql/dwd/50_dwd_order_refund_quality.sql.tpl"),
        ],
    },
    "fct_order": {
        "desc": "Order fact, order status fact, and refund status fact pipeline.",
        "init_sql": [
            Path("pipeline/sql/fact/00_init_order_fact_tables.sql"),
        ],
        "daily_templates": [
            Path("pipeline/sql/fact/10_fct_order_di.sql.tpl"),
            Path("pipeline/sql/fact/11_fct_order_status_di.sql.tpl"),
            Path("pipeline/sql/fact/12_fct_order_refund_status_di.sql.tpl"),
            Path("pipeline/sql/fact/20_fct_order_quality.sql.tpl"),
            Path("pipeline/sql/fact/21_fct_order_status_quality.sql.tpl"),
            Path("pipeline/sql/fact/22_fct_order_refund_status_quality.sql.tpl"),
        ],
    },
    "refund_anomaly": {
        "desc": "Refund anomaly detail sink based on fct_order_refund_status_di.",
        "init_sql": [
            Path("pipeline/sql/dq/00_init_dq_check_result_tables.sql"),
        ],
        "daily_templates": [
            Path("pipeline/sql/dq/11_order_refund_anomaly_detail.sql.tpl"),
        ],
    },
    "dws_ads": {
        "desc": "Unified trade DWS/ADS metrics for order, status, and refund views.",
        "init_sql": [
            Path("pipeline/sql/dws/00_init_dws_user_order_day_agg_tables.sql"),
            Path("pipeline/sql/ads/00_init_ads_order_day_overview_tables.sql"),
        ],
        "daily_templates": [
            Path("pipeline/sql/dws/10_dws_user_order_day_agg.sql.tpl"),
            Path("pipeline/sql/dws/11_dws_user_order_refund_day_agg.sql.tpl"),
            Path("pipeline/sql/dws/20_dws_user_order_day_agg_quality.sql.tpl"),
            Path("pipeline/sql/dws/21_dws_user_order_refund_day_agg_quality.sql.tpl"),
            Path("pipeline/sql/ads/10_ads_order_day_overview.sql.tpl"),
            Path("pipeline/sql/ads/11_ads_order_status_day_overview.sql.tpl"),
            Path("pipeline/sql/ads/12_ads_order_refund_day_overview.sql.tpl"),
            Path("pipeline/sql/ads/20_ads_order_day_overview_quality.sql.tpl"),
            Path("pipeline/sql/ads/21_ads_order_status_day_overview_quality.sql.tpl"),
            Path("pipeline/sql/ads/22_ads_order_refund_day_overview_quality.sql.tpl"),
            Path("pipeline/sql/ads/30_ads_order_day_overview_reconcile.sql.tpl"),
            Path("pipeline/sql/ads/31_ads_order_status_day_overview_reconcile.sql.tpl"),
            Path("pipeline/sql/ads/32_ads_order_refund_day_overview_reconcile.sql.tpl"),
        ],
    },
    "payment": {
        "desc": "Payment clean, payment fact, order-payment reconcile, and payment ADS.",
        "init_sql": [
            Path("pipeline/sql/payment/00_init_payment_reconcile_tables.sql"),
        ],
        "daily_templates": [
            Path("pipeline/sql/payment/11_dwd_payment_dirty_di.sql.tpl"),
            Path("pipeline/sql/payment/10_dwd_payment_clean_di.sql.tpl"),
            Path("pipeline/sql/payment/21_dwd_payment_quality.sql.tpl"),
            Path("pipeline/sql/payment/20_fct_payment_di.sql.tpl"),
            Path("pipeline/sql/payment/30_dq_order_payment_reconcile_di.sql.tpl"),
            Path("pipeline/sql/payment/40_order_payment_reconcile_quality.sql.tpl"),
            Path("pipeline/sql/payment/50_order_payment_dq_report.sql.tpl"),
            Path("pipeline/sql/payment/60_ads_order_payment_reconcile_overview.sql.tpl"),
            Path("pipeline/sql/payment/70_ads_order_payment_reconcile_overview_quality.sql.tpl"),
        ],
    },
    "multi_theme": {
        "desc": "User, product, channel, and unified multi-theme ADS pipeline.",
        "init_sql": [
            Path("pipeline/sql/zipper/00_init_user_zipper_tables.sql"),
            Path("pipeline/sql/snapshot/00_init_user_snapshot_tables.sql"),
            Path("pipeline/sql/dws/00_init_dws_user_order_day_agg_tables.sql"),
            Path("pipeline/sql/ads/00_init_ads_order_day_overview_tables.sql"),
            Path("pipeline/sql/product_theme/00_init_product_theme_tables.sql"),
            Path("pipeline/sql/channel_theme/00_init_channel_theme_tables.sql"),
            Path("pipeline/sql/multi_theme/00_init_multi_theme_ads_tables.sql"),
            Path("pipeline/sql/multi_theme/30_init_multi_theme_dq_tables.sql"),
        ],
        "daily_templates": [
            Path("pipeline/sql/zipper/10_dwd_user_info_clean.sql.tpl"),
            Path("pipeline/sql/snapshot/10_dim_user_snapshot_di.sql.tpl"),
            Path("pipeline/sql/dws/12_dws_user_level_trade_day_agg.sql.tpl"),
            Path("pipeline/sql/dws/22_dws_user_level_trade_day_agg_quality.sql.tpl"),
            Path("pipeline/sql/ads/13_ads_user_level_trade_day_overview.sql.tpl"),
            Path("pipeline/sql/ads/23_ads_user_level_trade_day_overview_quality.sql.tpl"),
            Path("pipeline/sql/ads/33_ads_user_level_trade_day_overview_reconcile.sql.tpl"),
            Path("pipeline/sql/product_theme/10_dim_product_snapshot_di.sql.tpl"),
            Path("pipeline/sql/product_theme/11_dwd_order_item_clean_di.sql.tpl"),
            Path("pipeline/sql/product_theme/12_fct_order_item_di.sql.tpl"),
            Path("pipeline/sql/product_theme/20_dws_category_trade_day_agg.sql.tpl"),
            Path("pipeline/sql/product_theme/21_dws_category_trade_day_agg_quality.sql.tpl"),
            Path("pipeline/sql/product_theme/30_ads_category_trade_day_overview.sql.tpl"),
            Path("pipeline/sql/product_theme/31_ads_category_trade_day_overview_quality.sql.tpl"),
            Path("pipeline/sql/product_theme/32_ads_category_trade_day_overview_reconcile.sql.tpl"),
            Path("pipeline/sql/channel_theme/10_dim_channel_snapshot_di.sql.tpl"),
            Path("pipeline/sql/channel_theme/11_dwd_order_channel_clean_di.sql.tpl"),
            Path("pipeline/sql/channel_theme/12_fct_order_channel_di.sql.tpl"),
            Path("pipeline/sql/channel_theme/20_dws_channel_trade_day_agg.sql.tpl"),
            Path("pipeline/sql/channel_theme/21_dws_channel_trade_day_agg_quality.sql.tpl"),
            Path("pipeline/sql/channel_theme/30_ads_channel_trade_day_overview.sql.tpl"),
            Path("pipeline/sql/channel_theme/31_ads_channel_trade_day_overview_quality.sql.tpl"),
            Path("pipeline/sql/channel_theme/32_ads_channel_trade_day_overview_reconcile.sql.tpl"),
            Path("pipeline/sql/multi_theme/10_ads_trade_multi_theme_day_overview.sql.tpl"),
            Path("pipeline/sql/multi_theme/20_ads_trade_multi_theme_day_overview_quality.sql.tpl"),
            Path("pipeline/sql/multi_theme/31_ads_trade_multi_theme_dq_report.sql.tpl"),
        ],
    },
}


def parse_args():
    parser = argparse.ArgumentParser(
        description="Run the realistic trade-domain offline warehouse pipeline by date range and subject."
    )
    parser.add_argument(
        "--start-dt",
        required=True,
        help="Start business date, format: YYYY-MM-DD. Example: 2026-03-01",
    )
    parser.add_argument(
        "--end-dt",
        required=True,
        help="End business date, format: YYYY-MM-DD. Example: 2026-03-07",
    )
    parser.add_argument(
        "--subject",
        choices=["all"] + SUBJECT_ORDER,
        default="all",
        help="Pipeline subject to run. Use all to run subjects in dependency order.",
    )
    parser.add_argument(
        "--init-tables",
        action="store_true",
        help="Run CREATE TABLE init SQL before daily backfill.",
    )
    parser.add_argument(
        "--init-only",
        action="store_true",
        help="Only run init SQL. Requires --init-tables.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Render SQL and print steps without copying to Docker or executing Spark SQL.",
    )
    parser.add_argument(
        "--allow-quality-fail",
        action="store_true",
        help="Continue when quality SQL prints '*check failed'. Useful for expected anomaly observation.",
    )
    parser.add_argument(
        "--skip-process-check",
        action="store_true",
        help="Skip the pre-run spark-sql process check.",
    )
    return parser.parse_args()


def parse_date(date_text, arg_name):
    try:
        return datetime.strptime(date_text, "%Y-%m-%d").date()
    except ValueError as exc:
        raise ValueError(f"{arg_name} must use YYYY-MM-DD format, got: {date_text}") from exc


def date_range(start_dt, end_dt):
    current_dt = start_dt
    while current_dt <= end_dt:
        yield current_dt
        current_dt += timedelta(days=1)


def expand_subjects(subject):
    if subject == "all":
        return list(SUBJECT_ORDER)
    return [subject]


def init_log_file(start_dt, end_dt, subject):
    log_dir = Path("pipeline/logs")
    log_dir.mkdir(parents=True, exist_ok=True)
    log_ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    return log_dir / f"trade_domain_realistic_runner_{subject}_{start_dt}_{end_dt}_{log_ts}.log"


def log_info(message, level="INFO"):
    log_line = f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] [{level}] {message}"
    print(log_line)

    if LOG_FILE is not None:
        with LOG_FILE.open("a", encoding="utf-8") as log_file:
            log_file.write(log_line + "\n")


def validate_paths(paths):
    for path in paths:
        if not path.exists():
            raise FileNotFoundError(f"SQL file not found: {path}")


def render_sql_files(sql_paths, output_path, run_dt=None):
    output_path.parent.mkdir(parents=True, exist_ok=True)

    rendered_parts = ["USE hive_demo;\n"]
    for sql_path in sql_paths:
        text = sql_path.read_text(encoding="utf-8")
        if run_dt is not None:
            text = text.replace("__RUN_DT__", str(run_dt))
        rendered_parts.append(f"\n-- source: {sql_path.as_posix()}\n")
        rendered_parts.append(text.rstrip() + "\n")

    output_path.write_text("\n".join(rendered_parts), encoding="utf-8")
    return output_path


def run_command(command, allow_returncodes=None):
    allowed = {0} if allow_returncodes is None else set(allow_returncodes)
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
            log_info(line, "SPARK")

    if result.stderr:
        log_info("stderr:")
        for line in result.stderr.strip().splitlines():
            level = "WARN" if "WARN" in line else "SPARK"
            log_info(line, level)

    if result.returncode not in allowed:
        raise RuntimeError(f"Command failed with returncode={result.returncode}")

    return result


def check_spark_sql_processes():
    result = run_command(
        [
            "docker",
            "exec",
            "hadoop-spark",
            "bash",
            "-lc",
            "ps -ef | grep -E 'spark-sql|SparkSQLCLIDriver' | grep -v grep",
        ],
        allow_returncodes={0, 1},
    )

    if result.stdout.strip():
        raise RuntimeError(
            "Existing spark-sql process found in hadoop-spark. Wait or stop it before running."
        )

    log_info("No existing spark-sql process found.")


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


def assert_quality_output(result, subject, run_dt, allow_quality_fail):
    output = result.stdout.strip()
    if "check failed" not in output:
        return

    message = f"Quality check output found. subject={subject}, run_dt={run_dt}"
    if allow_quality_fail:
        log_info(message + " Continue because --allow-quality-fail is enabled.", "WARN")
        return

    raise RuntimeError(message + ". Use --allow-quality-fail to continue for expected anomalies.")


def run_init_subject(subject, dry_run):
    subject_cfg = SUBJECTS[subject]
    init_sql = subject_cfg["init_sql"]
    validate_paths(init_sql)

    output_path = Path("pipeline/generated/trade_domain_realistic_runner/init") / f"{subject}_init.sql"
    rendered_sql = render_sql_files(init_sql, output_path)
    log_info(f"Rendered init SQL: {rendered_sql}")

    if dry_run:
        log_info(f"Dry run enabled. Skip init execution for subject={subject}.")
        return

    execute_spark_sql(rendered_sql)


def run_daily_subject(subject, run_dt, dry_run, allow_quality_fail):
    subject_cfg = SUBJECTS[subject]
    templates = subject_cfg["daily_templates"]
    validate_paths(templates)

    output_path = (
        Path("pipeline/generated/trade_domain_realistic_runner")
        / subject
        / str(run_dt)
        / f"{subject}_{run_dt}.sql"
    )
    rendered_sql = render_sql_files(templates, output_path, run_dt)
    log_info(f"Rendered daily SQL: {rendered_sql}")

    if dry_run:
        log_info(f"Dry run enabled. Skip execution for subject={subject}, run_dt={run_dt}.")
        return

    result = execute_spark_sql(rendered_sql)
    assert_quality_output(result, subject, run_dt, allow_quality_fail)


def main():
    global LOG_FILE

    args = parse_args()

    try:
        start_dt = parse_date(args.start_dt, "--start-dt")
        end_dt = parse_date(args.end_dt, "--end-dt")
        if start_dt > end_dt:
            raise ValueError(f"start_dt {start_dt} cannot be later than end_dt {end_dt}")
        if args.init_only and not args.init_tables:
            raise ValueError("--init-only requires --init-tables")

        subjects = expand_subjects(args.subject)
        LOG_FILE = init_log_file(start_dt, end_dt, args.subject)

        log_info(f"Log file: {LOG_FILE}")
        log_info(
            "Runner started. "
            f"start_dt={start_dt}, end_dt={end_dt}, subject={args.subject}, "
            f"subjects={','.join(subjects)}, dry_run={args.dry_run}, "
            f"allow_quality_fail={args.allow_quality_fail}"
        )

        if not args.dry_run and not args.skip_process_check:
            check_spark_sql_processes()

        if args.init_tables:
            for subject in subjects:
                log_info(f"===== Init started: subject={subject} =====")
                run_init_subject(subject, args.dry_run)
                log_info(f"===== Init finished: subject={subject} =====")

        if args.init_only:
            log_info("Init only mode enabled. Skip daily backfill.")
            return

        for run_dt in date_range(start_dt, end_dt):
            log_info(f"---------- Run date started: {run_dt} ----------")
            for subject in subjects:
                log_info(f"===== Subject started: subject={subject}, run_dt={run_dt} =====")
                run_daily_subject(subject, run_dt, args.dry_run, args.allow_quality_fail)
                log_info(f"===== Subject finished: subject={subject}, run_dt={run_dt} =====")
            log_info(f"---------- Run date finished: {run_dt} ----------")

    except Exception as exc:
        log_info(f"Runner failed: {exc}", "ERROR")
        raise SystemExit(str(exc)) from exc

    log_info("Runner finished successfully.")


if __name__ == "__main__":
    main()
