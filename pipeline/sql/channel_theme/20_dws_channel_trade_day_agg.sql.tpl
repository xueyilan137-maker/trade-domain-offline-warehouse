USE hive_demo;

WITH order_with_channel AS (
  SELECT
    f.dt,
    f.order_id,
    f.user_id,
    COALESCE(c.channel_id, 'unknown') AS channel_id,
    COALESCE(ch.channel_name, 'unknown') AS channel_name,
    COALESCE(ch.channel_type, 'unknown') AS channel_type,
    f.amount,
    f.order_status,
    f.refund_amount,
    f.net_amount
  FROM fct_order_refund_status_di f
  LEFT JOIN fct_order_channel_di c
    ON f.order_id = c.order_id
   AND f.dt = c.dt
  LEFT JOIN dim_channel_snapshot_di ch
    ON c.channel_id = ch.channel_id
   AND c.dt = ch.dt
  WHERE f.dt = '__RUN_DT__'
)
INSERT OVERWRITE TABLE dws_channel_trade_day_agg PARTITION (dt='__RUN_DT__')
SELECT
  channel_name,
  channel_type,
  COUNT(DISTINCT user_id) AS trade_user_cnt,
  COUNT(*) AS raw_order_cnt,
  SUM(CASE WHEN order_status = 'VALID' THEN 1 ELSE 0 END) AS valid_order_cnt,
  SUM(CASE WHEN order_status = 'CANCELLED' THEN 1 ELSE 0 END) AS cancel_order_cnt,
  CAST(SUM(amount) AS DECIMAL(10,2)) AS raw_gmv,
  CAST(SUM(CASE WHEN order_status = 'VALID' THEN amount ELSE 0 END) AS DECIMAL(10,2)) AS gross_valid_gmv,
  CAST(SUM(CASE WHEN order_status = 'CANCELLED' THEN amount ELSE 0 END) AS DECIMAL(10,2)) AS cancel_amount,
  CAST(SUM(CASE WHEN order_status = 'VALID' THEN refund_amount ELSE 0 END) AS DECIMAL(10,2)) AS refund_amount,
  CAST(SUM(CASE WHEN order_status = 'VALID' THEN net_amount ELSE 0 END) AS DECIMAL(10,2)) AS net_gmv
FROM order_with_channel
GROUP BY channel_name, channel_type;
