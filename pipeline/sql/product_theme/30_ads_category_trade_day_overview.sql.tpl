USE hive_demo;

INSERT OVERWRITE TABLE ads_category_trade_day_overview PARTITION (dt='__RUN_DT__')
SELECT
  category_name,
  raw_order_cnt,
  trade_user_cnt,
  item_cnt,
  raw_item_amount,
  valid_item_amount,
  cancel_item_amount,
  refund_amount,
  net_item_amount,
  CAST(ROUND(refund_amount / NULLIF(valid_item_amount, 0), 4) AS DECIMAL(10,4)) AS refund_amount_rate
FROM dws_category_trade_day_agg
WHERE dt = '__RUN_DT__';
