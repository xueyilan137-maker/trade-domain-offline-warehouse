USE hive_demo;

WITH stats AS (
  SELECT
    COUNT(*) AS reconcile_cnt,
    SUM(CASE WHEN reconcile_status = 'matched' THEN 1 ELSE 0 END) AS matched_cnt,
    SUM(CASE WHEN reconcile_status = 'amount_mismatch' THEN 1 ELSE 0 END) AS amount_mismatch_cnt,
    SUM(CASE WHEN reconcile_status = 'order_without_payment' THEN 1 ELSE 0 END) AS order_without_payment_cnt,
    SUM(CASE WHEN reconcile_status = 'payment_without_order' THEN 1 ELSE 0 END) AS payment_without_order_cnt,
    CAST(SUM(CASE WHEN reconcile_status <> 'matched' THEN ABS(diff_amount) ELSE 0 END) AS DECIMAL(10,2)) AS total_diff_amount
  FROM dq_order_payment_reconcile_di
  WHERE dt = '__RUN_DT__'
)
INSERT OVERWRITE TABLE ads_order_payment_reconcile_overview PARTITION (dt='__RUN_DT__')
SELECT
  reconcile_cnt,
  matched_cnt,
  amount_mismatch_cnt,
  order_without_payment_cnt,
  payment_without_order_cnt,
  amount_mismatch_cnt + order_without_payment_cnt + payment_without_order_cnt AS abnormal_cnt,
  CAST(ROUND(matched_cnt / NULLIF(reconcile_cnt, 0), 4) AS DECIMAL(10,4)) AS matched_rate,
  CAST(ROUND((amount_mismatch_cnt + order_without_payment_cnt + payment_without_order_cnt) / NULLIF(reconcile_cnt, 0), 4) AS DECIMAL(10,4)) AS abnormal_rate,
  total_diff_amount
FROM stats;
