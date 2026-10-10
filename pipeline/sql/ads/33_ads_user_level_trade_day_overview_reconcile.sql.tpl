USE hive_demo;

WITH dws AS (
  SELECT
    user_level,
    trade_user_cnt,
    raw_order_cnt,
    valid_order_cnt,
    cancel_order_cnt,
    gross_valid_gmv,
    refund_order_cnt,
    refund_amount,
    net_gmv
  FROM dws_user_level_trade_day_agg
  WHERE dt = '__RUN_DT__'
),
ads AS (
  SELECT
    user_level,
    trade_user_cnt,
    raw_order_cnt,
    valid_order_cnt,
    cancel_order_cnt,
    gross_valid_gmv,
    refund_order_cnt,
    refund_amount,
    net_gmv
  FROM ads_user_level_trade_day_overview
  WHERE dt = '__RUN_DT__'
)
SELECT 'ads_user_level_trade_day_overview dws reconcile check failed' AS err_msg
FROM dws
FULL OUTER JOIN ads
  ON dws.user_level = ads.user_level
WHERE dws.user_level IS NULL
   OR ads.user_level IS NULL
   OR COALESCE(dws.trade_user_cnt, 0) <> COALESCE(ads.trade_user_cnt, 0)
   OR COALESCE(dws.raw_order_cnt, 0) <> COALESCE(ads.raw_order_cnt, 0)
   OR COALESCE(dws.valid_order_cnt, 0) <> COALESCE(ads.valid_order_cnt, 0)
   OR COALESCE(dws.cancel_order_cnt, 0) <> COALESCE(ads.cancel_order_cnt, 0)
   OR COALESCE(dws.gross_valid_gmv, 0) <> COALESCE(ads.gross_valid_gmv, 0)
   OR COALESCE(dws.refund_order_cnt, 0) <> COALESCE(ads.refund_order_cnt, 0)
   OR COALESCE(dws.refund_amount, 0) <> COALESCE(ads.refund_amount, 0)
   OR COALESCE(dws.net_gmv, 0) <> COALESCE(ads.net_gmv, 0);
