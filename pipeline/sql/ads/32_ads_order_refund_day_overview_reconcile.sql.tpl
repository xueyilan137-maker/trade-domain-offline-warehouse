USE hive_demo;

WITH dws AS (
  SELECT
    SUM(raw_order_cnt) AS raw_order_cnt,
    SUM(valid_order_cnt) AS valid_order_cnt,
    SUM(cancel_order_cnt) AS cancel_order_cnt,
    CAST(SUM(gross_valid_gmv) AS DECIMAL(10,2)) AS gross_valid_gmv,
    SUM(refund_order_cnt) AS refund_order_cnt,
    CAST(SUM(refund_amount) AS DECIMAL(10,2)) AS refund_amount,
    CAST(SUM(net_gmv) AS DECIMAL(10,2)) AS net_gmv
  FROM dws_user_order_refund_day_agg
  WHERE dt = '__RUN_DT__'
),
ads AS (
  SELECT
    raw_order_cnt,
    valid_order_cnt,
    cancel_order_cnt,
    gross_valid_gmv,
    refund_order_cnt,
    refund_amount,
    net_gmv
  FROM ads_order_refund_day_overview
  WHERE dt = '__RUN_DT__'
)
SELECT 'ads_order_refund_day_overview dws reconcile check failed' AS err_msg
FROM dws
CROSS JOIN ads
WHERE COALESCE(dws.raw_order_cnt, 0) <> COALESCE(ads.raw_order_cnt, 0)
   OR COALESCE(dws.valid_order_cnt, 0) <> COALESCE(ads.valid_order_cnt, 0)
   OR COALESCE(dws.cancel_order_cnt, 0) <> COALESCE(ads.cancel_order_cnt, 0)
   OR COALESCE(dws.gross_valid_gmv, 0) <> COALESCE(ads.gross_valid_gmv, 0)
   OR COALESCE(dws.refund_order_cnt, 0) <> COALESCE(ads.refund_order_cnt, 0)
   OR COALESCE(dws.refund_amount, 0) <> COALESCE(ads.refund_amount, 0)
   OR COALESCE(dws.net_gmv, 0) <> COALESCE(ads.net_gmv, 0);
