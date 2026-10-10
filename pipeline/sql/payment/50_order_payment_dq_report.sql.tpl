USE hive_demo;

DROP TABLE IF EXISTS dq_check_result_order_payment_tmp;

CREATE TABLE dq_check_result_order_payment_tmp
USING parquet
AS
SELECT
  pipeline_name,
  layer_name,
  table_name,
  check_name,
  check_status,
  err_msg,
  checked_at
FROM dq_check_result_di
WHERE dt = '__RUN_DT__'
  AND pipeline_name <> 'order_payment_reconcile';

WITH reconcile_stats AS (
  SELECT
    COUNT(*) AS row_cnt,
    SUM(CASE WHEN reconcile_status = 'matched' THEN 1 ELSE 0 END) AS matched_cnt,
    SUM(CASE WHEN reconcile_status = 'amount_mismatch' THEN 1 ELSE 0 END) AS amount_mismatch_cnt,
    SUM(CASE WHEN reconcile_status = 'order_without_payment' THEN 1 ELSE 0 END) AS order_without_payment_cnt,
    SUM(CASE WHEN reconcile_status = 'payment_without_order' THEN 1 ELSE 0 END) AS payment_without_order_cnt
  FROM dq_order_payment_reconcile_di
  WHERE dt = '__RUN_DT__'
),
payment_clean_stats AS (
  SELECT COUNT(*) AS row_cnt
  FROM dwd_payment_clean_di
  WHERE dt = '__RUN_DT__'
),
payment_dirty_stats AS (
  SELECT
    COUNT(*) AS row_cnt,
    COALESCE(SUM(CASE WHEN dirty_reason IS NULL OR TRIM(dirty_reason) = '' THEN 1 ELSE 0 END), 0) AS null_reason_cnt
  FROM dwd_payment_dirty_di
  WHERE dt = '__RUN_DT__'
),
checks AS (
  SELECT
    'order_payment_reconcile' AS pipeline_name,
    'DWD' AS layer_name,
    'dwd_payment_clean_di' AS table_name,
    'row_count_positive' AS check_name,
    CASE WHEN payment_clean_stats.row_cnt > 0 THEN 'PASS' ELSE 'FAIL' END AS check_status,
    CASE WHEN payment_clean_stats.row_cnt > 0 THEN '' ELSE 'dwd_payment_clean_di row count is 0' END AS err_msg
  FROM payment_clean_stats

  UNION ALL
  SELECT
    'order_payment_reconcile',
    'DWD',
    'dwd_payment_dirty_di',
    'dirty_reason_not_null',
    CASE WHEN payment_dirty_stats.null_reason_cnt = 0 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN payment_dirty_stats.null_reason_cnt = 0 THEN '' ELSE 'dirty_reason is null or empty in dwd_payment_dirty_di' END
  FROM payment_dirty_stats

  UNION ALL
  SELECT
    'order_payment_reconcile',
    'DQ',
    'dq_order_payment_reconcile_di',
    'row_count_positive',
    CASE WHEN reconcile_stats.row_cnt > 0 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN reconcile_stats.row_cnt > 0 THEN '' ELSE 'dq_order_payment_reconcile_di row count is 0' END
  FROM reconcile_stats

  UNION ALL
  SELECT
    'order_payment_reconcile',
    'DQ',
    'dq_order_payment_reconcile_di',
    'all_orders_matched',
    CASE
      WHEN reconcile_stats.amount_mismatch_cnt = 0
       AND reconcile_stats.order_without_payment_cnt = 0
       AND reconcile_stats.payment_without_order_cnt = 0
      THEN 'PASS'
      ELSE 'FAIL'
    END,
    CASE
      WHEN reconcile_stats.amount_mismatch_cnt = 0
       AND reconcile_stats.order_without_payment_cnt = 0
       AND reconcile_stats.payment_without_order_cnt = 0
      THEN ''
      ELSE CONCAT(
        'amount_mismatch=', CAST(reconcile_stats.amount_mismatch_cnt AS STRING),
        ', order_without_payment=', CAST(reconcile_stats.order_without_payment_cnt AS STRING),
        ', payment_without_order=', CAST(reconcile_stats.payment_without_order_cnt AS STRING)
      )
    END
  FROM reconcile_stats
)
INSERT OVERWRITE TABLE dq_check_result_di PARTITION (dt='__RUN_DT__')
SELECT
  pipeline_name,
  layer_name,
  table_name,
  check_name,
  check_status,
  err_msg,
  checked_at
FROM dq_check_result_order_payment_tmp
UNION ALL
SELECT
  pipeline_name,
  layer_name,
  table_name,
  check_name,
  check_status,
  err_msg,
  CAST(current_timestamp() AS STRING) AS checked_at
FROM checks;

DROP TABLE IF EXISTS dq_check_result_order_payment_tmp;
