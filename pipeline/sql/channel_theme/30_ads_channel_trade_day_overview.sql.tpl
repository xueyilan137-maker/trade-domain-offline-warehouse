USE hive_demo;

INSERT OVERWRITE TABLE ads_channel_trade_day_overview PARTITION (dt='__RUN_DT__')
SELECT
  channel_name,
  channel_type,
  trade_user_cnt,
  raw_order_cnt,
  valid_order_cnt,
  cancel_order_cnt,
  raw_gmv,
  gross_valid_gmv,
  cancel_amount,
  refund_amount,
  net_gmv,
  CAST(ROUND(cancel_order_cnt / NULLIF(raw_order_cnt, 0), 4) AS DECIMAL(10,4)) AS cancel_order_rate,
  CAST(ROUND(refund_amount / NULLIF(gross_valid_gmv, 0), 4) AS DECIMAL(10,4)) AS refund_gmv_rate
FROM dws_channel_trade_day_agg
WHERE dt = '__RUN_DT__';
