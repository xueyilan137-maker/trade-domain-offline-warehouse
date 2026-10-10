USE hive_demo;

WITH status_stats AS (
  SELECT
    COUNT(DISTINCT user_id) AS raw_order_users,
    COUNT(*) AS raw_order_cnt,
    CAST(SUM(amount) AS DECIMAL(10,2)) AS raw_gmv,

    COUNT(DISTINCT CASE WHEN order_status = 'VALID' THEN user_id END) AS valid_order_users,
    SUM(CASE WHEN order_status = 'VALID' THEN 1 ELSE 0 END) AS valid_order_cnt,
    CAST(SUM(CASE WHEN order_status = 'VALID' THEN amount ELSE 0 END) AS DECIMAL(10,2)) AS valid_gmv,

    COUNT(DISTINCT CASE WHEN order_status = 'CANCELLED' THEN user_id END) AS cancel_order_users,
    SUM(CASE WHEN order_status = 'CANCELLED' THEN 1 ELSE 0 END) AS cancel_order_cnt,
    CAST(SUM(CASE WHEN order_status = 'CANCELLED' THEN amount ELSE 0 END) AS DECIMAL(10,2)) AS cancel_amount
  FROM fct_order_status_di
  WHERE dt = '__RUN_DT__'
)
INSERT OVERWRITE TABLE ads_order_status_day_overview PARTITION (dt='__RUN_DT__')
SELECT
  raw_order_users,
  raw_order_cnt,
  raw_gmv,
  valid_order_users,
  valid_order_cnt,
  valid_gmv,
  cancel_order_users,
  cancel_order_cnt,
  cancel_amount,
  CAST(ROUND(valid_order_cnt / NULLIF(raw_order_cnt, 0), 4) AS DECIMAL(10,4)) AS valid_order_rate,
  CAST(ROUND(cancel_order_cnt / NULLIF(raw_order_cnt, 0), 4) AS DECIMAL(10,4)) AS cancel_order_rate
FROM status_stats;
