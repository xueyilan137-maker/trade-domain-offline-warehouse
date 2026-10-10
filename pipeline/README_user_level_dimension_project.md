# User Level Dimension Snapshot And Zipper Project

## Project Summary

This project builds two common dimension modeling patterns for user level data:

```text
daily full snapshot dimension
slowly changing zipper dimension
```

It uses the same cleaned DWD input to produce both:

```text
ods_user_info_di
  -> dwd_user_info_clean_di
  -> dim_user_snapshot_di
  -> dim_user_zipper
```

One-line interview version:

```text
Built a user level dimension modeling project with ODS to DWD cleansing, daily snapshot dimension, zipper dimension for historical changes, run_dt-based reruns, backfill scripts, quality checks, and Airflow orchestration.
```

## Why This Project Matters

User attributes such as user level, membership level, user type, city, or status can change over time.

For these attributes, a data warehouse often needs to answer two different questions:

```text
What was the user's status on a specific day?
When did the user's status change, and what was the effective date range?
```

The daily snapshot table answers the first question directly.

The zipper table answers the second question by storing historical versions with effective date ranges.

## Full Data Flow

```text
ods_user_info_di
  -> dwd_user_info_clean_di
  -> dim_user_snapshot_di

ods_user_info_di
  -> dwd_user_info_clean_di
  -> dim_user_zipper_tmp
  -> dim_user_zipper
```

## Table List

| Table | Layer | Grain | Purpose |
| --- | --- | --- | --- |
| `ods_user_info_di` | ODS | one user row per source partition | Daily source input for user level data. |
| `dwd_user_info_clean_di` | DWD | one valid user row per day | Cleans and deduplicates user information for downstream dimensions. |
| `dim_user_snapshot_di` | DIM snapshot | one user per day | Stores the full user level status of each day. |
| `dim_user_zipper` | DIM zipper | one user historical version | Stores user level history with `start_date`, `end_date`, and `is_current`. |
| `dim_user_zipper_tmp` | temporary table | same as zipper | Avoids reading and overwriting `dim_user_zipper` in the same Spark SQL statement. |

## Source Demo Data

Demo file:

```text
pipeline/sql/zipper/01_seed_ods_user_info_di_demo.sql
```

Demo date range:

```text
2026-04-20 to 2026-04-22
```

Business changes:

```text
u1001: NORMAL -> VIP
u1002: VIP -> SVIP
u1003: new user on 2026-04-21
u1004: new user on 2026-04-22
```

## DWD Cleansing

SQL template:

```text
pipeline/sql/zipper/10_dwd_user_info_clean.sql.tpl
```

Rules:

```text
TRIM user_id, user_name, user_level
normalize user_level to upper case
filter empty user_id
filter empty user_name
filter empty user_level
deduplicate by user_id
```

Deduplication rule:

```text
ROW_NUMBER() OVER (
  PARTITION BY user_id
  ORDER BY user_name DESC, user_level DESC
) AS rn
```

The DWD output is:

```text
dwd_user_info_clean_di
```

Why DWD is needed:

```text
Snapshot and zipper dimensions should consume standardized, trusted user data.
ODS is kept as source input, while DWD is the reusable clean layer.
```

## Daily Snapshot Dimension

SQL template:

```text
pipeline/sql/snapshot/10_dim_user_snapshot_di.sql.tpl
```

Target table:

```text
dim_user_snapshot_di
```

Grain:

```text
one user per day
```

Core write pattern:

```sql
INSERT OVERWRITE TABLE dim_user_snapshot_di PARTITION (dt='${run_dt}')
SELECT user_id, user_name, user_level
FROM dwd_user_info_clean_di
WHERE dt = '${run_dt}';
```

What it answers:

```text
What was each user's level on a given day?
```

Example query:

```sql
SELECT user_id, user_name, user_level
FROM hive_demo.dim_user_snapshot_di
WHERE dt = '2026-04-21'
ORDER BY user_id;
```

Pros:

```text
Simple to query.
Easy to understand.
Good for daily state lookup and downstream joins by dt.
```

Cons:

```text
Stores repeated unchanged user rows every day.
Does not naturally show when a status started or ended.
```

## Zipper Dimension

SQL template:

```text
pipeline/sql/zipper/20_dim_user_zipper_merge.sql.tpl
```

Target table:

```text
dim_user_zipper
```

Grain:

```text
one user historical version
```

Core fields:

```text
user_id
user_name
user_level
start_date
end_date
is_current
```

Current-row convention:

```text
end_date = '9999-12-31'
is_current = 1
```

Historical-row convention:

```text
end_date = day before the next version starts
is_current = 0
```

What it answers:

```text
When did a user's level change?
Which user level version was valid during a specific date range?
Which version is current now?
```

Example current query:

```sql
SELECT user_id, user_name, user_level
FROM hive_demo.dim_user_zipper
WHERE is_current = 1
ORDER BY user_id;
```

Example historical query:

```sql
SELECT user_id, user_name, user_level
FROM hive_demo.dim_user_zipper
WHERE user_id = 'u1001'
  AND TO_DATE('2026-04-21') BETWEEN TO_DATE(start_date) AND TO_DATE(end_date);
```

## Zipper Merge Logic

The merge SQL is organized into several logical groups:

```text
hist_closed
hist_curr
today
changed
carry_forward
closed
new_user
opened
```

Meaning:

```text
hist_closed: old historical versions, keep unchanged.
hist_curr: current versions before this run.
today: today's cleaned user data.
changed: users whose name or level changed compared with current version.
carry_forward: current versions that did not change, keep open.
closed: old current versions that need to be closed.
new_user: users appearing today but not in current history.
opened: new current versions for changed users and new users.
```

Core idea:

```text
compare first
split rows by status
rebuild the dimension table
```

For a changed user:

```text
close old current row:
  end_date = run_dt - 1
  is_current = 0

open new current row:
  start_date = run_dt
  end_date = 9999-12-31
  is_current = 1
```

## Why A Temporary Table Is Used

Spark SQL can have problems when a statement reads from and overwrites the same table.

So this project writes first to:

```text
dim_user_zipper_tmp
```

Then overwrites:

```text
dim_user_zipper
```

This avoids a read-write conflict and makes the merge process more stable in the learning environment.

## Snapshot Vs Zipper

| Topic | Snapshot Table | Zipper Table |
| --- | --- | --- |
| Main question | What was the state on this day? | What changed and when was it effective? |
| Grain | one user per day | one user historical version |
| Query by date | simple `WHERE dt = ...` | use effective date range |
| Storage | repeats unchanged rows | stores only historical versions |
| Best for | daily state lookup | slow-changing dimension history |

Interview wording:

```text
The snapshot table is easier to query by day, while the zipper table is better for tracking historical changes and effective intervals. They are not replacements for each other. They solve different query patterns.
```

## Scripts

Zipper single-day scripts:

```text
pipeline/run_user_zipper_pipeline.ps1
pipeline/run_user_zipper_pipeline.py
```

Zipper backfill script:

```text
pipeline/run_user_zipper_backfill.ps1
```

Snapshot single-day script:

```text
pipeline/run_user_snapshot_pipeline.ps1
```

Snapshot backfill script:

```text
pipeline/run_user_snapshot_backfill.ps1
```

Script responsibilities:

```text
validate run_dt
render SQL templates
copy generated SQL into hadoop-spark
execute spark-sql
write logs
fail fast when SQL or quality checks fail
support rerun and backfill
```

## Airflow DAG

DAG file:

```text
airflow/dags/dim_user_zipper_pipeline_dag.py
```

Current DAG tasks:

```text
init_user_zipper_tables
  -> run_user_zipper_pipeline
```

The Airflow DAG uses the Python version of the zipper script:

```text
python /opt/project/pipeline/run_user_zipper_pipeline.py --run-dt {{ dag_run.conf.get('run_dt', ds) }}
```

This is useful because the Python script is easier to reuse in Linux/Airflow environments than the Windows PowerShell script.

## Backfill And Rerun

Single-day run:

```powershell
powershell -ExecutionPolicy Bypass -File .\pipeline\run_user_zipper_pipeline.ps1 -RunDt 2026-04-22
```

Zipper range backfill:

```powershell
powershell -ExecutionPolicy Bypass -File .\pipeline\run_user_zipper_backfill.ps1 -StartDt 2026-04-20 -EndDt 2026-04-22 -InitTables
```

Snapshot range backfill:

```powershell
powershell -ExecutionPolicy Bypass -File .\pipeline\run_user_snapshot_backfill.ps1 -StartDt 2026-04-20 -EndDt 2026-04-22 -InitTables
```

Why `run_dt` matters:

```text
It makes the dimension pipeline reproducible.
It supports single-day rerun.
It supports historical backfill.
It keeps SQL templates reusable.
```

## Data Quality Checks

Zipper quality template:

```text
pipeline/sql/zipper/30_dim_user_zipper_quality.sql.tpl
```

Checks:

```text
dwd_user_info_clean_di is not empty for run_dt
current zipper row is unique by user_id
current row end_date must be 9999-12-31
historical row start_date must be <= end_date
```

Snapshot quality template:

```text
pipeline/sql/snapshot/20_dim_user_snapshot_quality.sql.tpl
```

Checks:

```text
snapshot partition is not empty
user_id is unique in the dt partition
key fields are not null or empty
```

## Expected Result For Demo Data

After running:

```text
2026-04-20
2026-04-21
2026-04-22
```

Expected zipper changes:

```text
u1001:
  NORMAL from 2026-04-20 to 2026-04-20
  VIP from 2026-04-21 to 9999-12-31

u1002:
  VIP from 2026-04-20 to 2026-04-21
  SVIP from 2026-04-22 to 9999-12-31

u1003:
  NORMAL from 2026-04-21 to 9999-12-31

u1004:
  NORMAL from 2026-04-22 to 9999-12-31
```

Expected snapshot behavior:

```text
2026-04-20 partition has u1001 and u1002.
2026-04-21 partition has u1001, u1002, and u1003.
2026-04-22 partition has u1001, u1002, u1003, and u1004.
```

Validation SQL:

```sql
SELECT user_id, user_name, user_level, start_date, end_date, is_current
FROM hive_demo.dim_user_zipper
ORDER BY user_id, start_date;
```

```sql
SELECT dt, user_id, user_name, user_level
FROM hive_demo.dim_user_snapshot_di
ORDER BY dt, user_id;
```

## How To Explain In Interview

Short version:

```text
I built a user level dimension project using both daily snapshot and zipper table modeling. The data first goes through ODS to DWD cleansing, then the same clean user data is used to build a daily full snapshot dimension and a zipper dimension. The snapshot table is used for simple daily state lookup, while the zipper table records historical versions with start_date, end_date, and is_current. The pipeline supports run_dt-based reruns, backfills, quality checks, and Airflow scheduling.
```

Problem and solution:

```text
User level changes over time. If we only keep the latest value, we lose history. If we only keep daily snapshots, queries are simple but storage is repetitive and change intervals are not explicit. So I implemented both patterns: snapshot for daily state lookup and zipper for slowly changing history.
```

Key technical points:

```text
DWD cleans and standardizes source data before dimension modeling.
The zipper merge compares today's clean data with current historical versions.
Changed users close the old row and open a new row.
Unchanged users are carried forward.
New users open a new current row.
A temporary table avoids Spark SQL read-overwrite conflicts.
Quality checks ensure current rows are unique and date ranges are valid.
```

Good follow-up answer:

```text
In production, I would also add delete/offline user handling, late-arriving dimension changes, stronger DQ reporting into a shared dq_check_result table, and a multi-task Airflow DAG that separates DWD clean, zipper merge, snapshot build, and quality checks.
```

## Future Improvements

Recommended improvements:

```text
Add a dedicated dirty table for invalid user rows.
Integrate zipper and snapshot DQ into dq_check_result_di.
Add Airflow tasks for snapshot table as well as zipper table.
Support user delete/offline status.
Support late-arriving dimension correction.
Write a Python backfill entrypoint to replace the PowerShell-only backfill.
Add a project-level verification SQL file for demo data.
```
