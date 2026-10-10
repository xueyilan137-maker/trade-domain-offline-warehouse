USE hive_demo;

INSERT OVERWRITE TABLE ads_user_level_trade_day_overview PARTITION (dt='__RUN_DT__')
SELECT
  user_level,
  trade_user_cnt,
  raw_order_cnt,
  valid_order_cnt,
  cancel_order_cnt,
  gross_valid_gmv,
  refund_order_cnt,
  refund_amount,
  net_gmv,
  CAST(ROUND(refund_order_cnt / NULLIF(valid_order_cnt, 0), 4) AS DECIMAL(10,4)) AS refund_order_rate,
  CAST(ROUND(refund_amount / NULLIF(gross_valid_gmv, 0), 4) AS DECIMAL(10,4)) AS refund_gmv_rate
FROM dws_user_level_trade_day_agg
WHERE dt = '__RUN_DT__';
