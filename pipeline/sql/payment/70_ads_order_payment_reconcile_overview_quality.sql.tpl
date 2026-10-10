USE hive_demo;

SELECT 'ads_order_payment_reconcile_overview row count check failed' AS err_msg
WHERE (
  SELECT COUNT(*)
  FROM ads_order_payment_reconcile_overview
  WHERE dt = '__RUN_DT__'
) <> 1;

SELECT 'ads_order_payment_reconcile_overview count reconcile check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM ads_order_payment_reconcile_overview
  WHERE dt = '__RUN_DT__'
    AND reconcile_cnt <> matched_cnt + abnormal_cnt
);

SELECT 'ads_order_payment_reconcile_overview rate range check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM ads_order_payment_reconcile_overview
  WHERE dt = '__RUN_DT__'
    AND (
      matched_rate < 0
      OR matched_rate > 1
      OR abnormal_rate < 0
      OR abnormal_rate > 1
    )
);

WITH detail_stats AS (
  SELECT
    COUNT(*) AS reconcile_cnt,
    SUM(CASE WHEN reconcile_status = 'matched' THEN 1 ELSE 0 END) AS matched_cnt,
    SUM(CASE WHEN reconcile_status <> 'matched' THEN 1 ELSE 0 END) AS abnormal_cnt,
    CAST(SUM(CASE WHEN reconcile_status <> 'matched' THEN ABS(diff_amount) ELSE 0 END) AS DECIMAL(10,2)) AS total_diff_amount
  FROM dq_order_payment_reconcile_di
  WHERE dt = '__RUN_DT__'
),
ads_stats AS (
  SELECT
    reconcile_cnt,
    matched_cnt,
    abnormal_cnt,
    total_diff_amount
  FROM ads_order_payment_reconcile_overview
  WHERE dt = '__RUN_DT__'
)
SELECT 'ads_order_payment_reconcile_overview detail reconcile check failed' AS err_msg
FROM detail_stats
CROSS JOIN ads_stats
WHERE detail_stats.reconcile_cnt <> ads_stats.reconcile_cnt
   OR detail_stats.matched_cnt <> ads_stats.matched_cnt
   OR detail_stats.abnormal_cnt <> ads_stats.abnormal_cnt
   OR COALESCE(detail_stats.total_diff_amount, 0) <> COALESCE(ads_stats.total_diff_amount, 0);
