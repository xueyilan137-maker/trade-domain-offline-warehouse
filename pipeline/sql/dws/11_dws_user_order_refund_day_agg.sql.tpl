USE hive_demo;

INSERT OVERWRITE TABLE dws_user_order_refund_day_agg PARTITION (dt='__RUN_DT__')
SELECT
  user_id,
  COUNT(*) AS raw_order_cnt,
  SUM(CASE WHEN order_status = 'VALID' THEN 1 ELSE 0 END) AS valid_order_cnt,
  SUM(CASE WHEN order_status = 'CANCELLED' THEN 1 ELSE 0 END) AS cancel_order_cnt,
  CAST(SUM(CASE WHEN order_status = 'VALID' THEN amount ELSE 0 END) AS DECIMAL(10,2)) AS gross_valid_gmv,
  SUM(CASE WHEN order_status = 'VALID' AND is_refunded = 1 THEN 1 ELSE 0 END) AS refund_order_cnt,
  CAST(SUM(CASE WHEN order_status = 'VALID' THEN refund_amount ELSE 0 END) AS DECIMAL(10,2)) AS refund_amount,
  CAST(SUM(CASE WHEN order_status = 'VALID' THEN net_amount ELSE 0 END) AS DECIMAL(10,2)) AS net_gmv
FROM fct_order_refund_status_di
WHERE dt = '__RUN_DT__'
GROUP BY user_id;
