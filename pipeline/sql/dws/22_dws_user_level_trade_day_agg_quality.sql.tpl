USE hive_demo;

SELECT 'dws_user_level_trade_day_agg row count check failed' AS err_msg
WHERE (
  SELECT COUNT(*)
  FROM dws_user_level_trade_day_agg
  WHERE dt = '__RUN_DT__'
) = 0;

SELECT 'dws_user_level_trade_day_agg duplicate user_level check failed' AS err_msg
WHERE EXISTS (
  SELECT user_level
  FROM dws_user_level_trade_day_agg
  WHERE dt = '__RUN_DT__'
  GROUP BY user_level
  HAVING COUNT(*) > 1
);

SELECT 'dws_user_level_trade_day_agg negative metric check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM dws_user_level_trade_day_agg
  WHERE dt = '__RUN_DT__'
    AND (
      trade_user_cnt < 0
      OR raw_order_cnt < 0
      OR valid_order_cnt < 0
      OR cancel_order_cnt < 0
      OR gross_valid_gmv < 0
      OR refund_order_cnt < 0
      OR refund_amount < 0
      OR net_gmv < 0
    )
);

SELECT 'dws_user_level_trade_day_agg count split check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM dws_user_level_trade_day_agg
  WHERE dt = '__RUN_DT__'
    AND raw_order_cnt <> valid_order_cnt + cancel_order_cnt
);

SELECT 'dws_user_level_trade_day_agg net gmv check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM dws_user_level_trade_day_agg
  WHERE dt = '__RUN_DT__'
    AND net_gmv <> gross_valid_gmv - refund_amount
);

WITH fct AS (
  SELECT
    COALESCE(u.user_level, 'unknown') AS user_level,
    COUNT(DISTINCT f.user_id) AS trade_user_cnt,
    COUNT(*) AS raw_order_cnt,
    SUM(CASE WHEN f.order_status = 'VALID' THEN 1 ELSE 0 END) AS valid_order_cnt,
    SUM(CASE WHEN f.order_status = 'CANCELLED' THEN 1 ELSE 0 END) AS cancel_order_cnt,
    CAST(SUM(CASE WHEN f.order_status = 'VALID' THEN f.amount ELSE 0 END) AS DECIMAL(10,2)) AS gross_valid_gmv,
    SUM(CASE WHEN f.order_status = 'VALID' AND f.is_refunded = 1 THEN 1 ELSE 0 END) AS refund_order_cnt,
    CAST(SUM(CASE WHEN f.order_status = 'VALID' THEN f.refund_amount ELSE 0 END) AS DECIMAL(10,2)) AS refund_amount,
    CAST(SUM(CASE WHEN f.order_status = 'VALID' THEN f.net_amount ELSE 0 END) AS DECIMAL(10,2)) AS net_gmv
  FROM fct_order_refund_status_di f
  LEFT JOIN dim_user_snapshot_di u
    ON f.user_id = u.user_id
   AND f.dt = u.dt
  WHERE f.dt = '__RUN_DT__'
  GROUP BY COALESCE(u.user_level, 'unknown')
),
dws AS (
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
)
SELECT 'dws_user_level_trade_day_agg fct reconcile check failed' AS err_msg
FROM fct
FULL OUTER JOIN dws
  ON fct.user_level = dws.user_level
WHERE fct.user_level IS NULL
   OR dws.user_level IS NULL
   OR COALESCE(fct.trade_user_cnt, 0) <> COALESCE(dws.trade_user_cnt, 0)
   OR COALESCE(fct.raw_order_cnt, 0) <> COALESCE(dws.raw_order_cnt, 0)
   OR COALESCE(fct.valid_order_cnt, 0) <> COALESCE(dws.valid_order_cnt, 0)
   OR COALESCE(fct.cancel_order_cnt, 0) <> COALESCE(dws.cancel_order_cnt, 0)
   OR COALESCE(fct.gross_valid_gmv, 0) <> COALESCE(dws.gross_valid_gmv, 0)
   OR COALESCE(fct.refund_order_cnt, 0) <> COALESCE(dws.refund_order_cnt, 0)
   OR COALESCE(fct.refund_amount, 0) <> COALESCE(dws.refund_amount, 0)
   OR COALESCE(fct.net_gmv, 0) <> COALESCE(dws.net_gmv, 0);
