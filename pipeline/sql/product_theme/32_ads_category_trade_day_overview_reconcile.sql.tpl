USE hive_demo;

WITH dws AS (
  SELECT
    category_name,
    raw_order_cnt,
    trade_user_cnt,
    item_cnt,
    raw_item_amount,
    valid_item_amount,
    cancel_item_amount,
    refund_amount,
    net_item_amount
  FROM dws_category_trade_day_agg
  WHERE dt = '__RUN_DT__'
),
ads AS (
  SELECT
    category_name,
    raw_order_cnt,
    trade_user_cnt,
    item_cnt,
    raw_item_amount,
    valid_item_amount,
    cancel_item_amount,
    refund_amount,
    net_item_amount
  FROM ads_category_trade_day_overview
  WHERE dt = '__RUN_DT__'
)
SELECT 'ads_category_trade_day_overview dws reconcile check failed' AS err_msg
FROM dws
FULL OUTER JOIN ads
  ON dws.category_name = ads.category_name
WHERE dws.category_name IS NULL
   OR ads.category_name IS NULL
   OR COALESCE(dws.raw_order_cnt, 0) <> COALESCE(ads.raw_order_cnt, 0)
   OR COALESCE(dws.trade_user_cnt, 0) <> COALESCE(ads.trade_user_cnt, 0)
   OR COALESCE(dws.item_cnt, 0) <> COALESCE(ads.item_cnt, 0)
   OR COALESCE(dws.raw_item_amount, 0) <> COALESCE(ads.raw_item_amount, 0)
   OR COALESCE(dws.valid_item_amount, 0) <> COALESCE(ads.valid_item_amount, 0)
   OR COALESCE(dws.cancel_item_amount, 0) <> COALESCE(ads.cancel_item_amount, 0)
   OR COALESCE(dws.refund_amount, 0) <> COALESCE(ads.refund_amount, 0)
   OR COALESCE(dws.net_item_amount, 0) <> COALESCE(ads.net_item_amount, 0);
