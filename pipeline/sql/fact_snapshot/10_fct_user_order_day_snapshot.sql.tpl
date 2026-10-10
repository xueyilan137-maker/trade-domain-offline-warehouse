USE hive_demo;

INSERT OVERWRITE TABLE fct_user_order_day_snapshot PARTITION (dt='__RUN_DT__')
SELECT
  user_id,
  COUNT(*) AS order_cnt,
  CAST(SUM(amount) AS DECIMAL(10,2)) AS order_amount
FROM fct_order_di
WHERE dt = '__RUN_DT__'
GROUP BY user_id;
