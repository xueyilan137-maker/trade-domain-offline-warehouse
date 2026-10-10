# Order Subject Airflow Multi-Task DAG

This practice upgrades the order subject pipeline from one local main script into an Airflow DAG with visible layer tasks plus the payment reconcile extension:

```text
validate_run_dt
  -> run_dwd_order_clean
  -> run_fct_order
  -> run_dws_user_order_day_agg
  -> run_ads_order_day_overview
  -> run_order_subject_dq_report
  -> run_order_payment_reconcile
```

## Why This DAG Exists

The local main script is still useful for manual execution:

```text
run_order_subject_daily_pipeline.ps1
```

Airflow multi-task orchestration is useful when you want the scheduler UI to show each layer separately:

```text
FCT success/failure
DWS success/failure
ADS success/failure
DQ report refresh
payment reconcile success/failure
```

This makes failure location, rerun, and operation visibility closer to real offline data warehouse work.

## Files

```text
airflow/dags/order_subject_daily_multi_task_dag.py
pipeline/run_order_fact_pipeline.sh
pipeline/run_dws_user_order_day_agg_pipeline.sh
pipeline/run_ads_order_day_overview_pipeline.sh
pipeline/run_order_subject_dq_report_pipeline.sh
pipeline/run_order_payment_reconcile_pipeline.sh
pipeline/lib/spark_sql_runner.sh
```

The `.ps1` scripts are still the Windows learning entrypoints. The `.sh` scripts are the Airflow/Linux entrypoints.

## Trigger Example

Use Airflow UI and pass:

```json
{
  "run_dt": "2026-03-05"
}
```

The DAG will run:

```text
DWD: clean order detail and capture dirty order rows
FCT: build fct_order_di
DWS: build dws_user_order_day_agg
ADS: build ads_order_day_overview and run reconcile checks
DQ: write order subject checks into dq_check_result_di
Payment: build payment clean/dirty, fct_payment_di, order-payment reconcile detail, payment reconcile ADS, and payment DQ checks
```

## Why Payment Runs After Order DQ

`10_order_subject_dq_report.sql.tpl` overwrites `dq_check_result_di` for the current `dt`.
`50_order_payment_dq_report.sql.tpl` preserves non-payment checks and appends payment reconcile checks.

That means the safe learning-order is:

```text
order ADS done
  -> order DQ report
  -> payment reconcile pipeline
```

If this order is reversed, the order DQ report would overwrite the payment DQ rows for the same partition.
