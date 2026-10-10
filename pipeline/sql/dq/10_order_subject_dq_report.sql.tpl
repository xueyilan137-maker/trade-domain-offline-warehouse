USE hive_demo;

WITH
fct_stats AS (
  SELECT
    COUNT(*) AS row_cnt,
    COUNT(DISTINCT order_id) AS distinct_order_cnt,
    SUM(CASE WHEN order_id IS NULL OR TRIM(order_id) = '' OR user_id IS NULL OR TRIM(user_id) = '' THEN 1 ELSE 0 END) AS null_key_cnt,
    SUM(CASE WHEN amount < 0 THEN 1 ELSE 0 END) AS negative_amount_cnt,
    CAST(SUM(amount) AS DECIMAL(10,2)) AS gmv
  FROM fct_order_di
  WHERE dt = '__RUN_DT__'
),
valid_fct_stats AS (
  SELECT
    COUNT(*) AS row_cnt,
    COUNT(DISTINCT order_id) AS distinct_order_cnt,
    COUNT(DISTINCT user_id) AS distinct_user_cnt,
    CAST(SUM(amount) AS DECIMAL(10,2)) AS gmv
  FROM fct_order_status_di
  WHERE dt = '__RUN_DT__'
    AND order_status = 'VALID'
),
fct_status_stats AS (
  SELECT
    COUNT(*) AS row_cnt,
    COUNT(DISTINCT order_id) AS distinct_order_cnt,
    SUM(CASE WHEN order_status NOT IN ('VALID', 'CANCELLED') OR is_cancelled NOT IN (0, 1) THEN 1 ELSE 0 END) AS invalid_status_cnt,
    SUM(CASE WHEN order_status = 'CANCELLED' THEN 1 ELSE 0 END) AS cancelled_cnt
  FROM fct_order_status_di
  WHERE dt = '__RUN_DT__'
),
fct_refund_status_stats AS (
  SELECT
    COUNT(*) AS row_cnt,
    COUNT(DISTINCT order_id) AS distinct_order_cnt,
    SUM(CASE
      WHEN is_refunded NOT IN (0, 1)
        OR (is_refunded = 0 AND refund_amount <> 0)
        OR (is_refunded = 1 AND refund_amount <= 0)
        OR (is_refunded = 1 AND (refund_date IS NULL OR TRIM(refund_date) = ''))
      THEN 1 ELSE 0 END
    ) AS invalid_refund_flag_cnt,
    SUM(CASE
      WHEN net_amount < 0
        OR (order_status = 'CANCELLED' AND net_amount <> 0)
        OR (order_status = 'VALID' AND net_amount <> amount - refund_amount)
        OR (order_status = 'VALID' AND refund_amount > amount)
      THEN 1 ELSE 0 END
    ) AS invalid_net_amount_cnt,
    SUM(CASE WHEN is_refunded = 1 THEN 1 ELSE 0 END) AS refunded_cnt,
    CAST(SUM(CASE WHEN order_status = 'VALID' THEN amount ELSE 0 END) AS DECIMAL(10,2)) AS gross_valid_gmv,
    CAST(SUM(CASE WHEN order_status = 'VALID' THEN refund_amount ELSE 0 END) AS DECIMAL(10,2)) AS refund_amount,
    CAST(SUM(CASE WHEN order_status = 'VALID' THEN net_amount ELSE 0 END) AS DECIMAL(10,2)) AS net_gmv
  FROM fct_order_refund_status_di
  WHERE dt = '__RUN_DT__'
),
cancel_stats AS (
  SELECT
    COUNT(*) AS row_cnt,
    COUNT(DISTINCT order_id) AS distinct_order_cnt,
    SUM(CASE WHEN order_id IS NULL OR TRIM(order_id) = '' OR user_id IS NULL OR TRIM(user_id) = '' OR cancel_date IS NULL OR TRIM(cancel_date) = '' THEN 1 ELSE 0 END) AS null_key_cnt
  FROM dwd_order_cancel_clean_di
  WHERE dt = '__RUN_DT__'
),
refund_stats AS (
  SELECT
    COUNT(*) AS row_cnt,
    COUNT(DISTINCT order_id) AS distinct_order_cnt,
    SUM(CASE WHEN order_id IS NULL OR TRIM(order_id) = '' OR user_id IS NULL OR TRIM(user_id) = '' OR refund_date IS NULL OR TRIM(refund_date) = '' OR refund_amount IS NULL THEN 1 ELSE 0 END) AS null_key_cnt,
    SUM(CASE WHEN refund_amount <= 0 THEN 1 ELSE 0 END) AS invalid_refund_amount_cnt
  FROM dwd_order_refund_clean_di
  WHERE dt = '__RUN_DT__'
),
refund_match_stats AS (
  SELECT COUNT(*) AS matched_row_cnt
  FROM dwd_order_refund_clean_di r
  INNER JOIN dwd_order_clean_di o
    ON r.order_id = o.order_id
   AND r.dt = o.dt
  WHERE r.dt = '__RUN_DT__'
),
src_stats AS (
  SELECT
    COUNT(*) AS row_cnt,
    COUNT(DISTINCT order_id) AS distinct_order_cnt,
    SUM(CASE WHEN order_id IS NULL OR TRIM(order_id) = '' OR user_id IS NULL OR TRIM(user_id) = '' THEN 1 ELSE 0 END) AS null_key_cnt,
    SUM(CASE WHEN amount < 0 THEN 1 ELSE 0 END) AS negative_amount_cnt,
    CAST(SUM(amount) AS DECIMAL(10,2)) AS gmv
  FROM dwd_order_p
  WHERE dt = '__RUN_DT__'
),
src_valid_stats AS (
  SELECT
    COUNT(*) AS valid_row_cnt,
    COUNT(DISTINCT TRIM(order_id)) AS valid_distinct_order_cnt
  FROM dwd_order_p
  WHERE dt = '__RUN_DT__'
    AND order_id IS NOT NULL
    AND TRIM(order_id) <> ''
    AND user_id IS NOT NULL
    AND TRIM(user_id) <> ''
    AND order_date IS NOT NULL
    AND TRIM(order_date) <> ''
    AND amount IS NOT NULL
    AND amount >= 0
),
src_invalid_stats AS (
  SELECT
    COUNT(*) AS invalid_row_cnt
  FROM dwd_order_p
  WHERE dt = '__RUN_DT__'
    AND (
      order_id IS NULL
      OR TRIM(order_id) = ''
      OR user_id IS NULL
      OR TRIM(user_id) = ''
      OR order_date IS NULL
      OR TRIM(order_date) = ''
      OR amount IS NULL
      OR amount < 0
    )
),
dwd_stats AS (
  SELECT
    COUNT(*) AS row_cnt,
    COUNT(DISTINCT order_id) AS distinct_order_cnt,
    SUM(CASE WHEN order_id IS NULL OR TRIM(order_id) = '' OR user_id IS NULL OR TRIM(user_id) = '' THEN 1 ELSE 0 END) AS null_key_cnt,
    SUM(CASE WHEN amount < 0 THEN 1 ELSE 0 END) AS negative_amount_cnt,
    CAST(SUM(amount) AS DECIMAL(10,2)) AS gmv
  FROM dwd_order_clean_di
  WHERE dt = '__RUN_DT__'
),
dwd_dirty_stats AS (
  SELECT
    COUNT(*) AS row_cnt,
    SUM(CASE WHEN dirty_reason IS NULL OR TRIM(dirty_reason) = '' THEN 1 ELSE 0 END) AS null_reason_cnt
  FROM dwd_order_dirty_di
  WHERE dt = '__RUN_DT__'
),
dws_stats AS (
  SELECT
    COUNT(*) AS row_cnt,
    COUNT(DISTINCT user_id) AS distinct_user_cnt,
    SUM(order_cnt) AS order_cnt,
    CAST(SUM(order_amount) AS DECIMAL(10,2)) AS gmv,
    CAST(ROUND(SUM(order_amount) / NULLIF(SUM(order_cnt), 0), 2) AS DECIMAL(10,2)) AS avg_order_amount,
    SUM(CASE WHEN order_cnt < 0 OR order_amount < 0 OR avg_order_amount < 0 THEN 1 ELSE 0 END) AS negative_metric_cnt
  FROM dws_user_order_day_agg
  WHERE dt = '__RUN_DT__'
),
dws_refund_stats AS (
  SELECT
    COUNT(*) AS row_cnt,
    COUNT(DISTINCT user_id) AS distinct_user_cnt,
    SUM(raw_order_cnt) AS raw_order_cnt,
    SUM(valid_order_cnt) AS valid_order_cnt,
    SUM(cancel_order_cnt) AS cancel_order_cnt,
    CAST(SUM(gross_valid_gmv) AS DECIMAL(10,2)) AS gross_valid_gmv,
    SUM(refund_order_cnt) AS refund_order_cnt,
    CAST(SUM(refund_amount) AS DECIMAL(10,2)) AS refund_amount,
    CAST(SUM(net_gmv) AS DECIMAL(10,2)) AS net_gmv,
    SUM(CASE
      WHEN raw_order_cnt < 0
        OR valid_order_cnt < 0
        OR cancel_order_cnt < 0
        OR gross_valid_gmv < 0
        OR refund_order_cnt < 0
        OR refund_amount < 0
        OR net_gmv < 0
      THEN 1 ELSE 0 END
    ) AS negative_metric_cnt
  FROM dws_user_order_refund_day_agg
  WHERE dt = '__RUN_DT__'
),
ads_stats AS (
  SELECT
    COUNT(*) AS row_cnt,
    MAX(order_users) AS order_users,
    MAX(order_cnt) AS order_cnt,
    CAST(MAX(gmv) AS DECIMAL(10,2)) AS gmv,
    CAST(MAX(avg_order_amount) AS DECIMAL(10,2)) AS avg_order_amount,
    SUM(CASE WHEN order_users < 0 OR order_cnt < 0 OR gmv < 0 OR avg_order_amount < 0 THEN 1 ELSE 0 END) AS negative_metric_cnt
  FROM ads_order_day_overview
  WHERE dt = '__RUN_DT__'
),
ads_status_stats AS (
  SELECT
    COUNT(*) AS row_cnt,
    MAX(raw_order_users) AS raw_order_users,
    MAX(raw_order_cnt) AS raw_order_cnt,
    CAST(MAX(raw_gmv) AS DECIMAL(10,2)) AS raw_gmv,
    MAX(valid_order_users) AS valid_order_users,
    MAX(valid_order_cnt) AS valid_order_cnt,
    CAST(MAX(valid_gmv) AS DECIMAL(10,2)) AS valid_gmv,
    MAX(cancel_order_users) AS cancel_order_users,
    MAX(cancel_order_cnt) AS cancel_order_cnt,
    CAST(MAX(cancel_amount) AS DECIMAL(10,2)) AS cancel_amount,
    CAST(MAX(valid_order_rate) AS DECIMAL(10,4)) AS valid_order_rate,
    CAST(MAX(cancel_order_rate) AS DECIMAL(10,4)) AS cancel_order_rate,
    SUM(CASE
      WHEN raw_order_users < 0
        OR raw_order_cnt < 0
        OR raw_gmv < 0
        OR valid_order_users < 0
        OR valid_order_cnt < 0
        OR valid_gmv < 0
        OR cancel_order_users < 0
        OR cancel_order_cnt < 0
        OR cancel_amount < 0
      THEN 1 ELSE 0 END
    ) AS negative_metric_cnt,
    SUM(CASE
      WHEN valid_order_rate < 0
        OR valid_order_rate > 1
        OR cancel_order_rate < 0
        OR cancel_order_rate > 1
      THEN 1 ELSE 0 END
    ) AS invalid_rate_cnt
  FROM ads_order_status_day_overview
  WHERE dt = '__RUN_DT__'
),
ads_refund_stats AS (
  SELECT
    COUNT(*) AS row_cnt,
    MAX(raw_order_cnt) AS raw_order_cnt,
    MAX(valid_order_cnt) AS valid_order_cnt,
    MAX(cancel_order_cnt) AS cancel_order_cnt,
    CAST(MAX(gross_valid_gmv) AS DECIMAL(10,2)) AS gross_valid_gmv,
    MAX(refund_order_cnt) AS refund_order_cnt,
    CAST(MAX(refund_amount) AS DECIMAL(10,2)) AS refund_amount,
    CAST(MAX(net_gmv) AS DECIMAL(10,2)) AS net_gmv,
    CAST(MAX(refund_order_rate) AS DECIMAL(10,4)) AS refund_order_rate,
    CAST(MAX(refund_gmv_rate) AS DECIMAL(10,4)) AS refund_gmv_rate,
    SUM(CASE
      WHEN raw_order_cnt < 0
        OR valid_order_cnt < 0
        OR cancel_order_cnt < 0
        OR gross_valid_gmv < 0
        OR refund_order_cnt < 0
        OR refund_amount < 0
        OR net_gmv < 0
      THEN 1 ELSE 0 END
    ) AS negative_metric_cnt,
    SUM(CASE
      WHEN refund_order_rate < 0
        OR refund_order_rate > 1
        OR refund_gmv_rate < 0
        OR refund_gmv_rate > 1
      THEN 1 ELSE 0 END
    ) AS invalid_rate_cnt
  FROM ads_order_refund_day_overview
  WHERE dt = '__RUN_DT__'
),
checks AS (
  SELECT
    'order_subject_daily' AS pipeline_name,
    'DWD' AS layer_name,
    'dwd_order_clean_di' AS table_name,
    'row_count_positive' AS check_name,
    CASE WHEN dwd_stats.row_cnt > 0 THEN 'PASS' ELSE 'FAIL' END AS check_status,
    CASE WHEN dwd_stats.row_cnt > 0 THEN '' ELSE 'dwd_order_clean_di row count is 0' END AS err_msg
  FROM dwd_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'DWD',
    'dwd_order_clean_di',
    'order_id_unique',
    CASE WHEN dwd_stats.row_cnt = dwd_stats.distinct_order_cnt THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN dwd_stats.row_cnt = dwd_stats.distinct_order_cnt THEN '' ELSE 'duplicate order_id exists in dwd_order_clean_di' END
  FROM dwd_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'DWD',
    'dwd_order_clean_di',
    'key_not_null',
    CASE WHEN dwd_stats.null_key_cnt = 0 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN dwd_stats.null_key_cnt = 0 THEN '' ELSE 'order_id or user_id is null or empty in dwd_order_clean_di' END
  FROM dwd_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'DWD',
    'dwd_order_clean_di',
    'amount_non_negative',
    CASE WHEN dwd_stats.negative_amount_cnt = 0 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN dwd_stats.negative_amount_cnt = 0 THEN '' ELSE 'negative amount exists in dwd_order_clean_di' END
  FROM dwd_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'DWD',
    'dwd_order_clean_di',
    'valid_source_row_count_reconcile',
    CASE WHEN src_valid_stats.valid_distinct_order_cnt = dwd_stats.row_cnt THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN src_valid_stats.valid_distinct_order_cnt = dwd_stats.row_cnt THEN '' ELSE 'valid source distinct order count does not match dwd_order_clean_di' END
  FROM src_valid_stats CROSS JOIN dwd_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'DWD',
    'dwd_order_cancel_clean_di',
    'order_id_unique',
    CASE WHEN cancel_stats.row_cnt = cancel_stats.distinct_order_cnt THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN cancel_stats.row_cnt = cancel_stats.distinct_order_cnt THEN '' ELSE 'duplicate order_id exists in dwd_order_cancel_clean_di' END
  FROM cancel_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'DWD',
    'dwd_order_cancel_clean_di',
    'key_not_null',
    CASE WHEN cancel_stats.null_key_cnt = 0 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN cancel_stats.null_key_cnt = 0 THEN '' ELSE 'order_id, user_id or cancel_date is null or empty in dwd_order_cancel_clean_di' END
  FROM cancel_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'DWD',
    'dwd_order_refund_clean_di',
    'order_id_unique',
    CASE WHEN refund_stats.row_cnt = refund_stats.distinct_order_cnt THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN refund_stats.row_cnt = refund_stats.distinct_order_cnt THEN '' ELSE 'duplicate order_id exists in dwd_order_refund_clean_di' END
  FROM refund_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'DWD',
    'dwd_order_refund_clean_di',
    'key_not_null',
    CASE WHEN refund_stats.null_key_cnt = 0 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN refund_stats.null_key_cnt = 0 THEN '' ELSE 'order_id, user_id, refund_date or refund_amount is null or empty in dwd_order_refund_clean_di' END
  FROM refund_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'DWD',
    'dwd_order_refund_clean_di',
    'refund_amount_positive',
    CASE WHEN refund_stats.invalid_refund_amount_cnt = 0 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN refund_stats.invalid_refund_amount_cnt = 0 THEN '' ELSE 'refund_amount <= 0 exists in dwd_order_refund_clean_di' END
  FROM refund_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'DWD',
    'dwd_order_refund_clean_di',
    'order_match_reconcile',
    CASE WHEN refund_stats.row_cnt = refund_match_stats.matched_row_cnt THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN refund_stats.row_cnt = refund_match_stats.matched_row_cnt THEN '' ELSE 'refund order does not match dwd_order_clean_di' END
  FROM refund_stats CROSS JOIN refund_match_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'DWD',
    'dwd_order_dirty_di',
    'dirty_reason_not_null',
    CASE WHEN dwd_dirty_stats.null_reason_cnt = 0 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN dwd_dirty_stats.null_reason_cnt = 0 THEN '' ELSE 'dirty_reason is null or empty in dwd_order_dirty_di' END
  FROM dwd_dirty_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'DWD',
    'dwd_order_dirty_di',
    'dirty_row_count_reconcile',
    CASE
      WHEN src_invalid_stats.invalid_row_cnt + (src_valid_stats.valid_row_cnt - src_valid_stats.valid_distinct_order_cnt) = dwd_dirty_stats.row_cnt
      THEN 'PASS'
      ELSE 'FAIL'
    END,
    CASE
      WHEN src_invalid_stats.invalid_row_cnt + (src_valid_stats.valid_row_cnt - src_valid_stats.valid_distinct_order_cnt) = dwd_dirty_stats.row_cnt
      THEN ''
      ELSE 'source dirty row count does not match dwd_order_dirty_di'
    END
  FROM src_invalid_stats CROSS JOIN src_valid_stats CROSS JOIN dwd_dirty_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'FCT' AS layer_name,
    'fct_order_di' AS table_name,
    'row_count_positive' AS check_name,
    CASE WHEN fct_stats.row_cnt > 0 THEN 'PASS' ELSE 'FAIL' END AS check_status,
    CASE WHEN fct_stats.row_cnt > 0 THEN '' ELSE 'fct_order_di row count is 0' END AS err_msg
  FROM fct_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'FCT',
    'fct_order_di',
    'order_id_unique',
    CASE WHEN fct_stats.row_cnt = fct_stats.distinct_order_cnt THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN fct_stats.row_cnt = fct_stats.distinct_order_cnt THEN '' ELSE 'duplicate order_id exists in fct_order_di' END
  FROM fct_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'FCT',
    'fct_order_di',
    'key_not_null',
    CASE WHEN fct_stats.null_key_cnt = 0 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN fct_stats.null_key_cnt = 0 THEN '' ELSE 'order_id or user_id is null or empty' END
  FROM fct_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'FCT',
    'fct_order_di',
    'amount_non_negative',
    CASE WHEN fct_stats.negative_amount_cnt = 0 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN fct_stats.negative_amount_cnt = 0 THEN '' ELSE 'negative amount exists in fct_order_di' END
  FROM fct_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'FCT',
    'fct_order_di',
    'source_row_count_reconcile',
    CASE WHEN dwd_stats.row_cnt = fct_stats.row_cnt THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN dwd_stats.row_cnt = fct_stats.row_cnt THEN '' ELSE 'dwd_order_clean_di row count does not match fct_order_di' END
  FROM dwd_stats CROSS JOIN fct_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'FCT',
    'fct_order_di',
    'source_gmv_reconcile',
    CASE WHEN COALESCE(dwd_stats.gmv, 0) = COALESCE(fct_stats.gmv, 0) THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN COALESCE(dwd_stats.gmv, 0) = COALESCE(fct_stats.gmv, 0) THEN '' ELSE 'dwd_order_clean_di gmv does not match fct_order_di' END
  FROM dwd_stats CROSS JOIN fct_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'FCT',
    'fct_order_status_di',
    'row_count_reconcile',
    CASE WHEN fct_status_stats.row_cnt = fct_stats.row_cnt THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN fct_status_stats.row_cnt = fct_stats.row_cnt THEN '' ELSE 'fct_order_status_di row count does not match fct_order_di' END
  FROM fct_status_stats CROSS JOIN fct_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'FCT',
    'fct_order_status_di',
    'order_id_unique',
    CASE WHEN fct_status_stats.row_cnt = fct_status_stats.distinct_order_cnt THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN fct_status_stats.row_cnt = fct_status_stats.distinct_order_cnt THEN '' ELSE 'duplicate order_id exists in fct_order_status_di' END
  FROM fct_status_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'FCT',
    'fct_order_status_di',
    'status_valid',
    CASE WHEN fct_status_stats.invalid_status_cnt = 0 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN fct_status_stats.invalid_status_cnt = 0 THEN '' ELSE 'invalid order_status or is_cancelled exists in fct_order_status_di' END
  FROM fct_status_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'FCT',
    'fct_order_status_di',
    'cancel_count_reconcile',
    CASE WHEN fct_status_stats.cancelled_cnt = cancel_stats.row_cnt THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN fct_status_stats.cancelled_cnt = cancel_stats.row_cnt THEN '' ELSE 'cancelled order count does not match dwd_order_cancel_clean_di' END
  FROM fct_status_stats CROSS JOIN cancel_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'FCT',
    'fct_order_refund_status_di',
    'row_count_reconcile',
    CASE WHEN fct_refund_status_stats.row_cnt = fct_status_stats.row_cnt THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN fct_refund_status_stats.row_cnt = fct_status_stats.row_cnt THEN '' ELSE 'fct_order_refund_status_di row count does not match fct_order_status_di' END
  FROM fct_refund_status_stats CROSS JOIN fct_status_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'FCT',
    'fct_order_refund_status_di',
    'order_id_unique',
    CASE WHEN fct_refund_status_stats.row_cnt = fct_refund_status_stats.distinct_order_cnt THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN fct_refund_status_stats.row_cnt = fct_refund_status_stats.distinct_order_cnt THEN '' ELSE 'duplicate order_id exists in fct_order_refund_status_di' END
  FROM fct_refund_status_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'FCT',
    'fct_order_refund_status_di',
    'refund_flag_valid',
    CASE WHEN fct_refund_status_stats.invalid_refund_flag_cnt = 0 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN fct_refund_status_stats.invalid_refund_flag_cnt = 0 THEN '' ELSE 'invalid refund flag or refund info exists in fct_order_refund_status_di' END
  FROM fct_refund_status_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'FCT',
    'fct_order_refund_status_di',
    'net_amount_valid',
    CASE WHEN fct_refund_status_stats.invalid_net_amount_cnt = 0 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN fct_refund_status_stats.invalid_net_amount_cnt = 0 THEN '' ELSE 'invalid net_amount exists in fct_order_refund_status_di' END
  FROM fct_refund_status_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'FCT',
    'fct_order_refund_status_di',
    'refund_count_reconcile',
    CASE WHEN fct_refund_status_stats.refunded_cnt = refund_stats.row_cnt THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN fct_refund_status_stats.refunded_cnt = refund_stats.row_cnt THEN '' ELSE 'refunded order count does not match dwd_order_refund_clean_di' END
  FROM fct_refund_status_stats CROSS JOIN refund_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'DWS',
    'dws_user_order_day_agg',
    'row_count_positive',
    CASE WHEN dws_stats.row_cnt > 0 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN dws_stats.row_cnt > 0 THEN '' ELSE 'dws_user_order_day_agg row count is 0' END
  FROM dws_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'DWS',
    'dws_user_order_day_agg',
    'metric_non_negative',
    CASE WHEN dws_stats.negative_metric_cnt = 0 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN dws_stats.negative_metric_cnt = 0 THEN '' ELSE 'negative metric exists in dws_user_order_day_agg' END
  FROM dws_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'DWS',
    'dws_user_order_refund_day_agg',
    'row_count_positive',
    CASE WHEN dws_refund_stats.row_cnt > 0 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN dws_refund_stats.row_cnt > 0 THEN '' ELSE 'dws_user_order_refund_day_agg row count is 0' END
  FROM dws_refund_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'DWS',
    'dws_user_order_refund_day_agg',
    'user_id_unique',
    CASE WHEN dws_refund_stats.row_cnt = dws_refund_stats.distinct_user_cnt THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN dws_refund_stats.row_cnt = dws_refund_stats.distinct_user_cnt THEN '' ELSE 'duplicate user_id exists in dws_user_order_refund_day_agg' END
  FROM dws_refund_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'DWS',
    'dws_user_order_refund_day_agg',
    'metric_non_negative',
    CASE WHEN dws_refund_stats.negative_metric_cnt = 0 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN dws_refund_stats.negative_metric_cnt = 0 THEN '' ELSE 'negative metric exists in dws_user_order_refund_day_agg' END
  FROM dws_refund_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'DWS',
    'dws_user_order_refund_day_agg',
    'count_split_reconcile',
    CASE WHEN COALESCE(dws_refund_stats.raw_order_cnt, 0) = COALESCE(dws_refund_stats.valid_order_cnt, 0) + COALESCE(dws_refund_stats.cancel_order_cnt, 0) THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN COALESCE(dws_refund_stats.raw_order_cnt, 0) = COALESCE(dws_refund_stats.valid_order_cnt, 0) + COALESCE(dws_refund_stats.cancel_order_cnt, 0) THEN '' ELSE 'raw_order_cnt does not equal valid_order_cnt + cancel_order_cnt in dws_user_order_refund_day_agg' END
  FROM dws_refund_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'DWS',
    'dws_user_order_refund_day_agg',
    'net_gmv_reconcile',
    CASE WHEN COALESCE(dws_refund_stats.net_gmv, 0) = COALESCE(dws_refund_stats.gross_valid_gmv, 0) - COALESCE(dws_refund_stats.refund_amount, 0) THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN COALESCE(dws_refund_stats.net_gmv, 0) = COALESCE(dws_refund_stats.gross_valid_gmv, 0) - COALESCE(dws_refund_stats.refund_amount, 0) THEN '' ELSE 'net_gmv does not equal gross_valid_gmv - refund_amount in dws_user_order_refund_day_agg' END
  FROM dws_refund_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'DWS',
    'dws_user_order_refund_day_agg',
    'fct_refund_reconcile',
    CASE
      WHEN COALESCE(fct_stats.row_cnt, 0) = COALESCE(dws_refund_stats.raw_order_cnt, 0)
       AND COALESCE(valid_fct_stats.row_cnt, 0) = COALESCE(dws_refund_stats.valid_order_cnt, 0)
       AND COALESCE(fct_status_stats.cancelled_cnt, 0) = COALESCE(dws_refund_stats.cancel_order_cnt, 0)
       AND COALESCE(fct_refund_status_stats.gross_valid_gmv, 0) = COALESCE(dws_refund_stats.gross_valid_gmv, 0)
       AND COALESCE(fct_refund_status_stats.refunded_cnt, 0) = COALESCE(dws_refund_stats.refund_order_cnt, 0)
       AND COALESCE(fct_refund_status_stats.refund_amount, 0) = COALESCE(dws_refund_stats.refund_amount, 0)
       AND COALESCE(fct_refund_status_stats.net_gmv, 0) = COALESCE(dws_refund_stats.net_gmv, 0)
      THEN 'PASS'
      ELSE 'FAIL'
    END,
    CASE
      WHEN COALESCE(fct_stats.row_cnt, 0) = COALESCE(dws_refund_stats.raw_order_cnt, 0)
       AND COALESCE(valid_fct_stats.row_cnt, 0) = COALESCE(dws_refund_stats.valid_order_cnt, 0)
       AND COALESCE(fct_status_stats.cancelled_cnt, 0) = COALESCE(dws_refund_stats.cancel_order_cnt, 0)
       AND COALESCE(fct_refund_status_stats.gross_valid_gmv, 0) = COALESCE(dws_refund_stats.gross_valid_gmv, 0)
       AND COALESCE(fct_refund_status_stats.refunded_cnt, 0) = COALESCE(dws_refund_stats.refund_order_cnt, 0)
       AND COALESCE(fct_refund_status_stats.refund_amount, 0) = COALESCE(dws_refund_stats.refund_amount, 0)
       AND COALESCE(fct_refund_status_stats.net_gmv, 0) = COALESCE(dws_refund_stats.net_gmv, 0)
      THEN ''
      ELSE 'dws_user_order_refund_day_agg does not match fct_order_refund_status_di'
    END
  FROM dws_refund_stats CROSS JOIN fct_stats CROSS JOIN valid_fct_stats CROSS JOIN fct_status_stats CROSS JOIN fct_refund_status_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'ADS',
    'ads_order_day_overview',
    'row_count_equals_one',
    CASE WHEN ads_stats.row_cnt = 1 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN ads_stats.row_cnt = 1 THEN '' ELSE 'ads_order_day_overview row count is not 1' END
  FROM ads_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'ADS',
    'ads_order_status_day_overview',
    'row_count_equals_one',
    CASE WHEN ads_status_stats.row_cnt = 1 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN ads_status_stats.row_cnt = 1 THEN '' ELSE 'ads_order_status_day_overview row count is not 1' END
  FROM ads_status_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'ADS',
    'ads_order_status_day_overview',
    'metric_non_negative',
    CASE WHEN ads_status_stats.negative_metric_cnt = 0 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN ads_status_stats.negative_metric_cnt = 0 THEN '' ELSE 'negative metric exists in ads_order_status_day_overview' END
  FROM ads_status_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'ADS',
    'ads_order_status_day_overview',
    'rate_range_valid',
    CASE WHEN ads_status_stats.invalid_rate_cnt = 0 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN ads_status_stats.invalid_rate_cnt = 0 THEN '' ELSE 'invalid rate exists in ads_order_status_day_overview' END
  FROM ads_status_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'ADS',
    'ads_order_status_day_overview',
    'raw_count_split_reconcile',
    CASE WHEN COALESCE(ads_status_stats.raw_order_cnt, 0) = COALESCE(ads_status_stats.valid_order_cnt, 0) + COALESCE(ads_status_stats.cancel_order_cnt, 0) THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN COALESCE(ads_status_stats.raw_order_cnt, 0) = COALESCE(ads_status_stats.valid_order_cnt, 0) + COALESCE(ads_status_stats.cancel_order_cnt, 0) THEN '' ELSE 'raw_order_cnt does not equal valid_order_cnt + cancel_order_cnt' END
  FROM ads_status_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'ADS',
    'ads_order_status_day_overview',
    'raw_gmv_split_reconcile',
    CASE WHEN COALESCE(ads_status_stats.raw_gmv, 0) = COALESCE(ads_status_stats.valid_gmv, 0) + COALESCE(ads_status_stats.cancel_amount, 0) THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN COALESCE(ads_status_stats.raw_gmv, 0) = COALESCE(ads_status_stats.valid_gmv, 0) + COALESCE(ads_status_stats.cancel_amount, 0) THEN '' ELSE 'raw_gmv does not equal valid_gmv + cancel_amount' END
  FROM ads_status_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'ADS',
    'ads_order_status_day_overview',
    'fct_status_reconcile',
    CASE
      WHEN COALESCE(valid_fct_stats.row_cnt, 0) = COALESCE(ads_status_stats.valid_order_cnt, 0)
       AND COALESCE(valid_fct_stats.gmv, 0) = COALESCE(ads_status_stats.valid_gmv, 0)
       AND COALESCE(fct_stats.row_cnt, 0) = COALESCE(ads_status_stats.raw_order_cnt, 0)
       AND COALESCE(fct_stats.gmv, 0) = COALESCE(ads_status_stats.raw_gmv, 0)
       AND COALESCE(fct_status_stats.cancelled_cnt, 0) = COALESCE(ads_status_stats.cancel_order_cnt, 0)
      THEN 'PASS'
      ELSE 'FAIL'
    END,
    CASE
      WHEN COALESCE(valid_fct_stats.row_cnt, 0) = COALESCE(ads_status_stats.valid_order_cnt, 0)
       AND COALESCE(valid_fct_stats.gmv, 0) = COALESCE(ads_status_stats.valid_gmv, 0)
       AND COALESCE(fct_stats.row_cnt, 0) = COALESCE(ads_status_stats.raw_order_cnt, 0)
       AND COALESCE(fct_stats.gmv, 0) = COALESCE(ads_status_stats.raw_gmv, 0)
       AND COALESCE(fct_status_stats.cancelled_cnt, 0) = COALESCE(ads_status_stats.cancel_order_cnt, 0)
      THEN ''
      ELSE 'ads_order_status_day_overview does not match fct_order_status_di'
    END
  FROM ads_status_stats CROSS JOIN valid_fct_stats CROSS JOIN fct_stats CROSS JOIN fct_status_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'ADS',
    'ads_order_refund_day_overview',
    'row_count_equals_one',
    CASE WHEN ads_refund_stats.row_cnt = 1 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN ads_refund_stats.row_cnt = 1 THEN '' ELSE 'ads_order_refund_day_overview row count is not 1' END
  FROM ads_refund_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'ADS',
    'ads_order_refund_day_overview',
    'metric_non_negative',
    CASE WHEN ads_refund_stats.negative_metric_cnt = 0 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN ads_refund_stats.negative_metric_cnt = 0 THEN '' ELSE 'negative metric exists in ads_order_refund_day_overview' END
  FROM ads_refund_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'ADS',
    'ads_order_refund_day_overview',
    'rate_range_valid',
    CASE WHEN ads_refund_stats.invalid_rate_cnt = 0 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN ads_refund_stats.invalid_rate_cnt = 0 THEN '' ELSE 'invalid rate exists in ads_order_refund_day_overview' END
  FROM ads_refund_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'ADS',
    'ads_order_refund_day_overview',
    'count_split_reconcile',
    CASE WHEN COALESCE(ads_refund_stats.raw_order_cnt, 0) = COALESCE(ads_refund_stats.valid_order_cnt, 0) + COALESCE(ads_refund_stats.cancel_order_cnt, 0) THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN COALESCE(ads_refund_stats.raw_order_cnt, 0) = COALESCE(ads_refund_stats.valid_order_cnt, 0) + COALESCE(ads_refund_stats.cancel_order_cnt, 0) THEN '' ELSE 'raw_order_cnt does not equal valid_order_cnt + cancel_order_cnt' END
  FROM ads_refund_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'ADS',
    'ads_order_refund_day_overview',
    'net_gmv_reconcile',
    CASE WHEN COALESCE(ads_refund_stats.net_gmv, 0) = COALESCE(ads_refund_stats.gross_valid_gmv, 0) - COALESCE(ads_refund_stats.refund_amount, 0) THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN COALESCE(ads_refund_stats.net_gmv, 0) = COALESCE(ads_refund_stats.gross_valid_gmv, 0) - COALESCE(ads_refund_stats.refund_amount, 0) THEN '' ELSE 'net_gmv does not equal gross_valid_gmv - refund_amount' END
  FROM ads_refund_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'ADS',
    'ads_order_refund_day_overview',
    'dws_refund_reconcile',
    CASE
      WHEN COALESCE(dws_refund_stats.raw_order_cnt, 0) = COALESCE(ads_refund_stats.raw_order_cnt, 0)
       AND COALESCE(dws_refund_stats.valid_order_cnt, 0) = COALESCE(ads_refund_stats.valid_order_cnt, 0)
       AND COALESCE(dws_refund_stats.cancel_order_cnt, 0) = COALESCE(ads_refund_stats.cancel_order_cnt, 0)
       AND COALESCE(dws_refund_stats.gross_valid_gmv, 0) = COALESCE(ads_refund_stats.gross_valid_gmv, 0)
       AND COALESCE(dws_refund_stats.refund_order_cnt, 0) = COALESCE(ads_refund_stats.refund_order_cnt, 0)
       AND COALESCE(dws_refund_stats.refund_amount, 0) = COALESCE(ads_refund_stats.refund_amount, 0)
       AND COALESCE(dws_refund_stats.net_gmv, 0) = COALESCE(ads_refund_stats.net_gmv, 0)
      THEN 'PASS'
      ELSE 'FAIL'
    END,
    CASE
      WHEN COALESCE(dws_refund_stats.raw_order_cnt, 0) = COALESCE(ads_refund_stats.raw_order_cnt, 0)
       AND COALESCE(dws_refund_stats.valid_order_cnt, 0) = COALESCE(ads_refund_stats.valid_order_cnt, 0)
       AND COALESCE(dws_refund_stats.cancel_order_cnt, 0) = COALESCE(ads_refund_stats.cancel_order_cnt, 0)
       AND COALESCE(dws_refund_stats.gross_valid_gmv, 0) = COALESCE(ads_refund_stats.gross_valid_gmv, 0)
       AND COALESCE(dws_refund_stats.refund_order_cnt, 0) = COALESCE(ads_refund_stats.refund_order_cnt, 0)
       AND COALESCE(dws_refund_stats.refund_amount, 0) = COALESCE(ads_refund_stats.refund_amount, 0)
       AND COALESCE(dws_refund_stats.net_gmv, 0) = COALESCE(ads_refund_stats.net_gmv, 0)
      THEN ''
      ELSE 'ads_order_refund_day_overview does not match dws_user_order_refund_day_agg'
    END
  FROM ads_refund_stats CROSS JOIN dws_refund_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'ADS',
    'ads_order_day_overview',
    'metric_non_negative',
    CASE WHEN ads_stats.negative_metric_cnt = 0 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN ads_stats.negative_metric_cnt = 0 THEN '' ELSE 'negative metric exists in ads_order_day_overview' END
  FROM ads_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'ADS',
    'ads_order_day_overview',
    'order_count_reconcile',
    CASE WHEN COALESCE(valid_fct_stats.row_cnt, 0) = COALESCE(dws_stats.order_cnt, 0) AND COALESCE(valid_fct_stats.row_cnt, 0) = COALESCE(ads_stats.order_cnt, 0) THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN COALESCE(valid_fct_stats.row_cnt, 0) = COALESCE(dws_stats.order_cnt, 0) AND COALESCE(valid_fct_stats.row_cnt, 0) = COALESCE(ads_stats.order_cnt, 0) THEN '' ELSE 'valid order count does not match across FCT/DWS/ADS' END
  FROM valid_fct_stats CROSS JOIN dws_stats CROSS JOIN ads_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'ADS',
    'ads_order_day_overview',
    'gmv_reconcile',
    CASE WHEN COALESCE(valid_fct_stats.gmv, 0) = COALESCE(dws_stats.gmv, 0) AND COALESCE(valid_fct_stats.gmv, 0) = COALESCE(ads_stats.gmv, 0) THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN COALESCE(valid_fct_stats.gmv, 0) = COALESCE(dws_stats.gmv, 0) AND COALESCE(valid_fct_stats.gmv, 0) = COALESCE(ads_stats.gmv, 0) THEN '' ELSE 'valid order gmv does not match across FCT/DWS/ADS' END
  FROM valid_fct_stats CROSS JOIN dws_stats CROSS JOIN ads_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'ADS',
    'ads_order_day_overview',
    'order_users_reconcile',
    CASE WHEN COALESCE(dws_stats.distinct_user_cnt, 0) = COALESCE(ads_stats.order_users, 0) THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN COALESCE(dws_stats.distinct_user_cnt, 0) = COALESCE(ads_stats.order_users, 0) THEN '' ELSE 'order users does not match across DWS/ADS' END
  FROM dws_stats CROSS JOIN ads_stats

  UNION ALL
  SELECT
    'order_subject_daily',
    'ADS',
    'ads_order_day_overview',
    'avg_order_amount_reconcile',
    CASE WHEN COALESCE(dws_stats.avg_order_amount, 0) = COALESCE(ads_stats.avg_order_amount, 0) THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN COALESCE(dws_stats.avg_order_amount, 0) = COALESCE(ads_stats.avg_order_amount, 0) THEN '' ELSE 'avg order amount does not match across DWS/ADS' END
  FROM dws_stats CROSS JOIN ads_stats
)
INSERT OVERWRITE TABLE dq_check_result_di PARTITION (dt='__RUN_DT__')
SELECT
  pipeline_name,
  layer_name,
  table_name,
  check_name,
  check_status,
  err_msg,
  CAST(current_timestamp() AS STRING) AS checked_at
FROM checks;
