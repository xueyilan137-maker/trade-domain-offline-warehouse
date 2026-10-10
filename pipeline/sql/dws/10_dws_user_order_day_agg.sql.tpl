USE hive_demo;

INSERT OVERWRITE TABLE dws_user_order_day_agg PARTITION (dt='__RUN_DT__')
SELECT
  o.user_id,
  COUNT(*) AS order_cnt,
  CAST(SUM(o.amount) AS DECIMAL(10,2)) AS order_amount,
  CAST(ROUND(SUM(o.amount) / COUNT(*), 2) AS DECIMAL(10,2)) AS avg_order_amount
FROM fct_order_di o
JOIN fct_order_status_di s
  ON o.order_id = s.order_id
 AND o.dt = s.dt
WHERE o.dt = '__RUN_DT__'
  AND s.order_status = 'VALID'
GROUP BY o.user_id;
