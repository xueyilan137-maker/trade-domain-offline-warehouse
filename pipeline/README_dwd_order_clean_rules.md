# DWD Order Clean Rules

This document records the DWD cleaning rules for the order subject pipeline.

## Purpose

The DWD layer has two outputs:

- `dwd_order_clean_di`: clean order detail data for downstream FCT/DWS/ADS tables.
- `dwd_order_dirty_di`: rejected or duplicate source rows with a clear `dirty_reason`.

The goal is not only to protect downstream metrics, but also to make rejected data traceable.

## Source And Targets

| Role | Table | Description |
| --- | --- | --- |
| Source | `dwd_order_p` | Order source input used by this practice project. |
| Clean target | `dwd_order_clean_di` | Valid, standardized, deduplicated order detail rows. |
| Dirty target | `dwd_order_dirty_di` | Invalid or duplicate rows rejected from the clean target. |

All tables are partitioned by `dt`.

## Standardization Rules

Before validation, string fields are standardized:

| Field | Rule | Example |
| --- | --- | --- |
| `order_id` | `TRIM(order_id)` | `'  o2005  '` -> `'o2005'` |
| `user_id` | `TRIM(user_id)` | `'  u14  '` -> `'u14'` |
| `order_date` | `TRIM(order_date)` | `' 2026-03-05 '` -> `'2026-03-05'` |
| `amount` | `CAST(amount AS DECIMAL(10,2))` | `100` -> `100.00` |

Rows fixed only by standardization can enter `dwd_order_clean_di`.

## Dirty Rules

Rows matching any of the following rules are written to `dwd_order_dirty_di`.

| Rule | `dirty_reason` | Clean Target | Dirty Target | Notes |
| --- | --- | --- | --- | --- |
| `order_id` is null or empty after trim | `order_id_empty` | No | Yes | Order primary key is required. |
| `user_id` is null or empty after trim | `user_id_empty` | No | Yes | User key is required for user-level analysis. |
| `order_date` is null or empty after trim | `order_date_empty` | No | Yes | Business date is required. |
| `amount` is null | `amount_null` | No | Yes | Amount cannot be used in GMV. |
| `amount < 0` | `amount_negative` | No | Yes | Negative order amount is invalid in this practice model. |
| Same `order_id` appears more than once among valid rows | `duplicate_order_id` | One row only | Duplicate rows | Keep the top-ranked row in clean, write the rest to dirty. |

## Deduplication Rule

For valid rows with the same `order_id`, the clean table keeps one row using:

```sql
ROW_NUMBER() OVER (
  PARTITION BY order_id
  ORDER BY order_date DESC, user_id ASC, amount DESC
) AS rn
```

The clean table keeps `rn = 1`.

Rows with `rn > 1` are written to `dwd_order_dirty_di` with:

```text
dirty_reason = duplicate_order_id
```

## Example

For `dt = 2026-03-05`, the source has 7 rows:

| Source Case | Result |
| --- | --- |
| `o2001`, valid | Enters clean. |
| `o2002`, amount `90.00` | Enters clean because it ranks first among duplicate `o2002` rows. |
| `o2002`, amount `80.00` | Enters dirty as `duplicate_order_id`. |
| Empty `order_id` | Enters dirty as `order_id_empty`. |
| Empty `user_id` | Enters dirty as `user_id_empty`. |
| Negative `amount` | Enters dirty as `amount_negative`. |
| `order_id` and `user_id` with spaces | Trimmed and enters clean. |

Result:

| Table | Row Count | GMV |
| --- | ---: | ---: |
| `dwd_order_clean_di` | 3 | 220.00 |
| `dwd_order_dirty_di` | 4 | 170.00 |

## Quality Checks

Clean table checks:

| Check | Meaning |
| --- | --- |
| `row_count_positive` | Clean partition is not empty. |
| `order_id_unique` | No duplicate `order_id` exists in clean data. |
| `key_not_null` | `order_id`, `user_id`, and `order_date` are not null or empty. |
| `amount_non_negative` | No negative amount exists in clean data. |
| `valid_source_row_count_reconcile` | Valid distinct source orders equal clean row count. |

Dirty table checks:

| Check | Meaning |
| --- | --- |
| `dirty_reason_not_null` | Every dirty row has a clear reason. |
| `dirty_row_count_reconcile` | Source invalid rows plus duplicate valid rows equal dirty row count. |

## Related Files

| File | Purpose |
| --- | --- |
| `pipeline/sql/dwd/00_init_order_clean_tables.sql` | Creates clean and dirty DWD tables. |
| `pipeline/sql/dwd/10_dwd_order_clean_di.sql.tpl` | Writes clean order rows. |
| `pipeline/sql/dwd/11_dwd_order_dirty_di.sql.tpl` | Writes dirty order rows. |
| `pipeline/sql/dwd/20_dwd_order_clean_quality.sql.tpl` | Runs clean table checks. |
| `pipeline/sql/dwd/30_dwd_order_dirty_quality.sql.tpl` | Runs dirty table checks. |
| `pipeline/run_dwd_order_clean_pipeline.ps1` | Windows DWD execution script. |
| `pipeline/run_dwd_order_clean_pipeline.sh` | Linux/Airflow DWD execution script. |
| `pipeline/sql/dq/10_order_subject_dq_report.sql.tpl` | Writes DQ summary results. |

## Working Principle

The DWD layer should answer three questions:

1. Which data is trusted and can flow downstream?
2. Which data is rejected and why?
3. Can source, clean, and dirty row counts reconcile?

This is the core difference between simply filtering data and building traceable data cleaning governance.
