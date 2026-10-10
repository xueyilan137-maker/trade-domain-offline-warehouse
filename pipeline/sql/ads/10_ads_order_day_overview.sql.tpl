USE hive_demo;

INSERT OVERWRITE TABLE ads_order_day_overview PARTITION (dt='__RUN_DT__')
SELECT
  COUNT(DISTINCT user_id) AS order_users,
  SUM(order_cnt) AS order_cnt,
  CAST(SUM(order_amount) AS DECIMAL(10,2)) AS gmv,
  CAST(ROUND(SUM(order_amount) / NULLIF(SUM(order_cnt), 0), 2) AS DECIMAL(10,2)) AS avg_order_amount
FROM dws_user_order_day_agg
WHERE dt = '__RUN_DT__';
