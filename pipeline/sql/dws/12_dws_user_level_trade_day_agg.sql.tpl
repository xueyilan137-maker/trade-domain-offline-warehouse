USE hive_demo;

INSERT OVERWRITE TABLE dws_user_level_trade_day_agg PARTITION (dt='__RUN_DT__')
SELECT
  COALESCE(u.user_level, 'unknown') AS user_level,
  COUNT(DISTINCT f.user_id) AS trade_user_cnt,
  COUNT(*) AS raw_order_cnt,
  SUM(CASE WHEN f.order_status = 'VALID' THEN 1 ELSE 0 END) AS valid_order_cnt,
  SUM(CASE WHEN f.order_status = 'CANCELLED' THEN 1 ELSE 0 END) AS cancel_order_cnt,
  CAST(SUM(CASE WHEN f.order_status = 'VALID' THEN f.amount ELSE 0 END) AS DECIMAL(10,2)) AS gross_valid_gmv,
  SUM(CASE WHEN f.order_status = 'VALID' AND f.is_refunded = 1 THEN 1 ELSE 0 END) AS refund_order_cnt,
  CAST(SUM(CASE WHEN f.order_status = 'VALID' THEN f.refund_amount ELSE 0 END) AS DECIMAL(10,2)) AS refund_amount,
  CAST(SUM(CASE WHEN f.order_status = 'VALID' THEN f.net_amount ELSE 0 END) AS DECIMAL(10,2)) AS net_gmv
FROM fct_order_refund_status_di f
LEFT JOIN dim_user_snapshot_di u
  ON f.user_id = u.user_id
 AND f.dt = u.dt
WHERE f.dt = '__RUN_DT__'
GROUP BY COALESCE(u.user_level, 'unknown');
