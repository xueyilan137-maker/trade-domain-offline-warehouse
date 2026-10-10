# Order Payment Subject Offline DW Project

## Project Summary

This project builds an offline data warehouse pipeline for the order subject, with payment reconciliation and data quality governance.

It covers:

```text
DWD clean/dirty governance
transaction fact tables
DWS daily user aggregate
ADS daily overview
order-payment reconciliation detail
payment reconciliation ADS
DQ result summary
Airflow multi-task orchestration
```

One-line interview version:

```text
Built an offline order subject data warehouse pipeline with DWD clean/dirty governance, order and payment fact tables, ADS indicators, order-payment reconciliation, DQ summary, idempotent partition writes, and Airflow scheduling.
```

## Full Data Flow

```text
dwd_order_p
  -> dwd_order_dirty_di
  -> dwd_order_clean_di
  -> fct_order_di
  -> dws_user_order_day_agg
  -> ads_order_day_overview
  -> dq_check_result_di

dwd_payment_p
  -> dwd_payment_dirty_di
  -> dwd_payment_clean_di
  -> fct_payment_di

fct_order_di + fct_payment_di
  -> dq_order_payment_reconcile_di
  -> ads_order_payment_reconcile_overview
  -> dq_check_result_di
```

## Airflow DAG

DAG file:

```text
airflow/dags/order_subject_daily_multi_task_dag.py
```

Task dependency:

```text
validate_run_dt
  -> run_dwd_order_clean
  -> run_fct_order
  -> run_dws_user_order_day_agg
  -> run_ads_order_day_overview
  -> run_order_subject_dq_report
  -> run_order_payment_reconcile
```

Design notes:

```text
validate_run_dt checks the business date format and allowed sample date range.
run_dwd_order_clean builds order clean and dirty tables.
run_fct_order builds the order transaction fact table.
run_dws_user_order_day_agg builds user daily order aggregates.
run_ads_order_day_overview builds the final order daily ADS and checks FCT/DWS/ADS consistency.
run_order_subject_dq_report writes order subject DQ checks into dq_check_result_di.
run_order_payment_reconcile builds payment clean/dirty, payment fact, order-payment reconciliation detail, payment reconciliation ADS, and payment DQ checks.
```

The payment task runs after the order DQ report because:

```text
10_order_subject_dq_report.sql.tpl overwrites dq_check_result_di for the current dt.
50_order_payment_dq_report.sql.tpl preserves non-payment DQ rows and appends payment DQ rows.
```

So the safe order is:

```text
order ADS
  -> order DQ report
  -> payment reconciliation DQ append
```

## Table List

| Table | Layer | Grain | Purpose |
| --- | --- | --- | --- |
| `dwd_order_p` | source practice table | one raw order row | Order source input for the current practice project. |
| `dwd_order_clean_di` | DWD | one valid order | Clean order detail for downstream fact and metric calculation. |
| `dwd_order_dirty_di` | DWD | one dirty source row | Captures invalid or duplicate order rows with `dirty_reason`. |
| `fct_order_di` | FCT | one valid order | Transaction fact table for valid orders. |
| `dws_user_order_day_agg` | DWS | one user per day | User daily order count and amount aggregate. |
| `ads_order_day_overview` | ADS | one day | Daily order overview: order users, order count, GMV, average order amount. |
| `dwd_payment_p` | source practice table | one raw payment row | Payment source input for the current practice project. |
| `dwd_payment_clean_di` | DWD | one valid payment | Clean payment detail for payment fact and reconciliation. |
| `dwd_payment_dirty_di` | DWD | one dirty payment row | Captures invalid payment rows with `dirty_reason`. |
| `fct_payment_di` | FCT | one valid payment | Transaction fact table for valid payments. |
| `dq_order_payment_reconcile_di` | DQ detail | one reconciled order id | Order-payment reconciliation detail. |
| `ads_order_payment_reconcile_overview` | ADS | one day | Daily payment reconciliation overview. |
| `dq_check_result_di` | DQ summary | one check item | Summary of DQ checks and PASS/FAIL status. |

## DWD Governance

The project uses a clean/dirty double-output pattern.

Order DWD rules:

```text
TRIM order_id, user_id, order_date
filter empty order_id
filter empty user_id
filter empty order_date
filter null amount
filter negative amount
deduplicate by order_id
```

Duplicate order rule:

```text
Keep rn = 1 by order_date DESC, user_id ASC, amount DESC.
Other duplicate rows go to dwd_order_dirty_di with dirty_reason = duplicate_order_id.
```

Payment DWD rules:

```text
TRIM payment_id, order_id, user_id, pay_date
normalize pay_status
filter empty keys
filter null or negative pay_amount
keep successful payments
deduplicate payment_id
```

Why this matters:

```text
DWD clean protects downstream FCT/DWS/ADS from dirty source data.
DWD dirty keeps rejected rows visible and explainable.
DQ summary records whether quality checks pass.
```

## Fact Modeling

Order fact:

```text
fct_order_di
grain: one valid order
source: dwd_order_clean_di
```

Payment fact:

```text
fct_payment_di
grain: one valid payment
source: dwd_payment_clean_di
```

The key modeling idea:

```text
Facts should read trusted clean detail, not dirty source input.
```

## DWS And ADS

DWS:

```text
dws_user_order_day_agg
grain: one user per day
metrics: order_cnt, order_amount, avg_order_amount
```

ADS:

```text
ads_order_day_overview
grain: one day
metrics: order_users, order_cnt, gmv, avg_order_amount
```

ADS reconcile checks verify:

```text
FCT order count = DWS order count = ADS order count
FCT GMV = DWS GMV = ADS GMV
DWS distinct users = ADS order users
DWS average order amount = ADS average order amount
```

## Order Payment Reconciliation

Detail table:

```text
dq_order_payment_reconcile_di
```

Core logic:

```text
FULL OUTER JOIN fct_order_di and fct_payment_di by order_id.
```

Reconciliation statuses:

```text
matched
amount_mismatch
order_without_payment
payment_without_order
```

ADS table:

```text
ads_order_payment_reconcile_overview
```

Metrics:

```text
reconcile_cnt
matched_cnt
amount_mismatch_cnt
order_without_payment_cnt
payment_without_order_cnt
abnormal_cnt
matched_rate
abnormal_rate
total_diff_amount
```

Important distinction:

```text
Airflow success means the pipeline produced data successfully.
DQ FAIL can still exist when business data has explainable reconciliation exceptions.
```

For example, amount mismatch and payment without order are business exceptions. They should be recorded in DQ and ADS, not necessarily make the Airflow task fail.

## DQ Design

DQ detail table:

```text
dq_order_payment_reconcile_di
```

DQ summary table:

```text
dq_check_result_di
```

Typical DQ checks:

```text
row count positive
key not null
amount non-negative
duplicate key check
dirty reason not null
source-clean-dirty row count reconcile
FCT/DWS/ADS metric reconcile
order-payment reconciliation status check
all orders matched business check
```

How to read DQ:

```text
dq_check_result_di tells whether each check passed or failed.
dq_order_payment_reconcile_di tells which exact order/payment rows caused reconciliation exceptions.
dwd_order_dirty_di and dwd_payment_dirty_di tell which source rows were rejected by DWD governance.
```

## Idempotency

Most daily outputs use partition overwrite:

```sql
INSERT OVERWRITE TABLE xxx PARTITION (dt='${run_dt}')
```

Meaning:

```text
Rerunning the same run_dt will not append duplicate rows.
The target dt partition is replaced with the latest result.
If source data and logic are unchanged, the output remains stable.
```

Current idempotent daily tables:

```text
dwd_order_clean_di
dwd_order_dirty_di
fct_order_di
dws_user_order_day_agg
ads_order_day_overview
dwd_payment_clean_di
dwd_payment_dirty_di
fct_payment_di
dq_order_payment_reconcile_di
ads_order_payment_reconcile_overview
dq_check_result_di
```

## Verified Run

Run date:

```text
2026-03-05
```

Airflow DAG run:

```text
manual_order_payment_reconcile_2026_03_05_codex_api
```

Task result:

```text
All tasks succeeded.
```

Order result:

```text
dwd_order_p              7 rows, GMV 390.00
dwd_order_clean_di       3 rows, GMV 220.00
dwd_order_dirty_di       4 rows, GMV 170.00
fct_order_di             3 rows, GMV 220.00
dws_user_order_day_agg   3 user-day rows, order_cnt 3, GMV 220.00
ads_order_day_overview   order_users 3, order_cnt 3, GMV 220.00, avg_order_amount 73.33
```

Payment result:

```text
dwd_payment_p            5 rows, pay_amount 270.00
dwd_payment_clean_di     4 rows, pay_amount 250.00
dwd_payment_dirty_di     1 row, pay_amount 20.00
fct_payment_di           4 rows, pay_amount 250.00
```

Reconciliation result:

```text
matched                 2 rows, abs_diff_amount 0.00
amount_mismatch         1 row, abs_diff_amount 10.00
payment_without_order   1 row, abs_diff_amount 40.00
```

Payment reconciliation ADS:

```text
reconcile_cnt                 4
matched_cnt                   2
amount_mismatch_cnt           1
order_without_payment_cnt     0
payment_without_order_cnt     1
abnormal_cnt                  2
matched_rate                  0.5000
abnormal_rate                 0.5000
total_diff_amount             50.00
```

DQ summary:

```text
order_subject_daily       PASS 21
order_payment_reconcile   PASS 3
order_payment_reconcile   FAIL 1
```

The single FAIL is expected business data:

```text
check_name: all_orders_matched
err_msg: amount_mismatch=1, order_without_payment=0, payment_without_order=1
```

Detail:

```text
o2002: order amount 90.00, payment amount 80.00, amount_mismatch
o9999: no order, payment amount 40.00, payment_without_order
```

## How To Explain In Interview

Short version:

```text
I built an offline order subject data warehouse pipeline. The pipeline first performs DWD clean/dirty governance on order and payment data, then builds transaction fact tables, DWS user daily aggregates, ADS daily overview metrics, and order-payment reconciliation outputs. Airflow orchestrates the pipeline by layer, and DQ results are written into a summary table. The pipeline is idempotent by daily partition overwrite and supports reruns/backfills by run_dt.
```

Problem and solution:

```text
Source data can contain empty keys, negative amounts, duplicates, and inconsistent payment records.
I used DWD clean/dirty double outputs to protect downstream metrics while keeping dirty details traceable.
Then I used FCT/DWS/ADS metric reconciliation to ensure final indicators match upstream facts.
For payment reconciliation, I used a FULL OUTER JOIN between order facts and payment facts to capture matched, amount mismatch, order without payment, and payment without order cases.
```

Key engineering points:

```text
Airflow Task success means the technical pipeline ran successfully.
DQ FAIL means the data has quality or business exceptions.
The two are intentionally separated.
```

Potential follow-up improvements:

```text
Split payment reconciliation into multiple Airflow tasks.
Add refund and cancellation facts.
Add net GMV and paid GMV indicators.
Move repeated shell logic into Python utilities.
Add a separate DQ blocking policy for checks that should stop downstream tasks.
```
