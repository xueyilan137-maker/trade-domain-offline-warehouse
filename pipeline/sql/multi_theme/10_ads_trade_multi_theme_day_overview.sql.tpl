USE hive_demo;

INSERT OVERWRITE TABLE ads_trade_multi_theme_day_overview PARTITION (dt='__RUN_DT__')
SELECT
  'user_theme' AS theme_name,
  'user_level' AS dimension_name,
  user_level AS dimension_value,
  'USER' AS dimension_type,
  trade_user_cnt,
  raw_order_cnt,
  valid_order_cnt,
  cancel_order_cnt,
  CAST(NULL AS BIGINT) AS item_cnt,
  CAST(NULL AS DECIMAL(10,2)) AS raw_amount,
  gross_valid_gmv AS valid_amount,
  CAST(NULL AS DECIMAL(10,2)) AS cancel_amount,
  refund_amount,
  net_gmv AS net_amount,
  CAST(cancel_order_cnt / NULLIF(raw_order_cnt, 0) AS DECIMAL(10,4)) AS cancel_rate,
  refund_gmv_rate AS refund_rate
FROM ads_user_level_trade_day_overview
WHERE dt = '__RUN_DT__'

UNION ALL

SELECT
  'product_theme' AS theme_name,
  'category_name' AS dimension_name,
  category_name AS dimension_value,
  'PRODUCT' AS dimension_type,
  trade_user_cnt,
  raw_order_cnt,
  CAST(NULL AS BIGINT) AS valid_order_cnt,
  CAST(NULL AS BIGINT) AS cancel_order_cnt,
  item_cnt,
  raw_item_amount AS raw_amount,
  valid_item_amount AS valid_amount,
  cancel_item_amount AS cancel_amount,
  refund_amount,
  net_item_amount AS net_amount,
  CAST(cancel_item_amount / NULLIF(raw_item_amount, 0) AS DECIMAL(10,4)) AS cancel_rate,
  refund_amount_rate AS refund_rate
FROM ads_category_trade_day_overview
WHERE dt = '__RUN_DT__'

UNION ALL

SELECT
  'channel_theme' AS theme_name,
  'channel_name' AS dimension_name,
  channel_name AS dimension_value,
  channel_type AS dimension_type,
  trade_user_cnt,
  raw_order_cnt,
  valid_order_cnt,
  cancel_order_cnt,
  CAST(NULL AS BIGINT) AS item_cnt,
  raw_gmv AS raw_amount,
  gross_valid_gmv AS valid_amount,
  cancel_amount,
  refund_amount,
  net_gmv AS net_amount,
  cancel_order_rate AS cancel_rate,
  refund_gmv_rate AS refund_rate
FROM ads_channel_trade_day_overview
WHERE dt = '__RUN_DT__';
