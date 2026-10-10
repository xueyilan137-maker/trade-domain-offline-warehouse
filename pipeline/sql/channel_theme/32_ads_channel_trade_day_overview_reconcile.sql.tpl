USE hive_demo;

WITH dws AS (
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
    net_gmv
  FROM dws_channel_trade_day_agg
  WHERE dt = '__RUN_DT__'
),
ads AS (
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
    net_gmv
  FROM ads_channel_trade_day_overview
  WHERE dt = '__RUN_DT__'
)
SELECT 'ads_channel_trade_day_overview dws reconcile check failed' AS err_msg
FROM dws
FULL OUTER JOIN ads
  ON dws.channel_name = ads.channel_name
 AND dws.channel_type = ads.channel_type
WHERE dws.channel_name IS NULL
   OR ads.channel_name IS NULL
   OR COALESCE(dws.trade_user_cnt, 0) <> COALESCE(ads.trade_user_cnt, 0)
   OR COALESCE(dws.raw_order_cnt, 0) <> COALESCE(ads.raw_order_cnt, 0)
   OR COALESCE(dws.valid_order_cnt, 0) <> COALESCE(ads.valid_order_cnt, 0)
   OR COALESCE(dws.cancel_order_cnt, 0) <> COALESCE(ads.cancel_order_cnt, 0)
   OR COALESCE(dws.raw_gmv, 0) <> COALESCE(ads.raw_gmv, 0)
   OR COALESCE(dws.gross_valid_gmv, 0) <> COALESCE(ads.gross_valid_gmv, 0)
   OR COALESCE(dws.cancel_amount, 0) <> COALESCE(ads.cancel_amount, 0)
   OR COALESCE(dws.refund_amount, 0) <> COALESCE(ads.refund_amount, 0)
   OR COALESCE(dws.net_gmv, 0) <> COALESCE(ads.net_gmv, 0);
