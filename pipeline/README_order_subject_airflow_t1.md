# Order Subject Airflow T+1 DAG

This practice DAG shows how an offline warehouse job uses a schedule date to process the previous business day.

## DAG

```text
order_subject_daily_t1
```

Task dependency:

```text
run_fct_order
  -> run_dws_user_order_day_agg
  -> run_ads_order_day_overview
```

## Schedule

```text
0 1 * * *
```

This means Airflow schedules the DAG every day at 01:00.

For a daily cron schedule, Airflow's `ds` is the logical business date for the completed data interval.

Example:

```text
Schedule fire time: 2026-03-02 01:00
ds:                 2026-03-01
run_dt:             2026-03-01
Hive partition:     dt='2026-03-01'
```

## Manual Override

The DAG uses:

```text
{{ dag_run.conf.get('run_dt') or ds }}
```

So:

```text
If run_dt is passed manually, use run_dt.
If run_dt is not passed, use ds.
```

This matches a common production pattern:

```text
Normal schedule: use ds
Manual backfill/retry: pass run_dt
```

