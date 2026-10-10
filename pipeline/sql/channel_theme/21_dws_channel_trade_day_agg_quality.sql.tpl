USE hive_demo;

SELECT 'dws_channel_trade_day_agg row count check failed' AS err_msg
WHERE (
  SELECT COUNT(*)
  FROM dws_channel_trade_day_agg
  WHERE dt = '__RUN_DT__'
) = 0;

SELECT 'dws_channel_trade_day_agg duplicate channel check failed' AS err_msg
WHERE EXISTS (
  SELECT channel_name, channel_type
  FROM dws_channel_trade_day_agg
  WHERE dt = '__RUN_DT__'
  GROUP BY channel_name, channel_type
  HAVING COUNT(*) > 1
);

SELECT 'dws_channel_trade_day_agg negative metric check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM dws_channel_trade_day_agg
  WHERE dt = '__RUN_DT__'
    AND (
      trade_user_cnt < 0
      OR raw_order_cnt < 0
      OR valid_order_cnt < 0
      OR cancel_order_cnt < 0
      OR raw_gmv < 0
      OR gross_valid_gmv < 0
      OR cancel_amount < 0
      OR refund_amount < 0
      OR net_gmv < 0
    )
);

SELECT 'dws_channel_trade_day_agg count split check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM dws_channel_trade_day_agg
  WHERE dt = '__RUN_DT__'
    AND raw_order_cnt <> valid_order_cnt + cancel_order_cnt
);

SELECT 'dws_channel_trade_day_agg amount split check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM dws_channel_trade_day_agg
  WHERE dt = '__RUN_DT__'
    AND raw_gmv <> gross_valid_gmv + cancel_amount
);

SELECT 'dws_channel_trade_day_agg net gmv check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM dws_channel_trade_day_agg
  WHERE dt = '__RUN_DT__'
    AND net_gmv <> gross_valid_gmv - refund_amount
);

WITH source_agg AS (
  SELECT
    COALESCE(ch.channel_name, 'unknown') AS channel_name,
    COALESCE(ch.channel_type, 'unknown') AS channel_type,
    COUNT(DISTINCT f.user_id) AS trade_user_cnt,
    COUNT(*) AS raw_order_cnt,
    SUM(CASE WHEN f.order_status = 'VALID' THEN 1 ELSE 0 END) AS valid_order_cnt,
    SUM(CASE WHEN f.order_status = 'CANCELLED' THEN 1 ELSE 0 END) AS cancel_order_cnt,
    CAST(SUM(f.amount) AS DECIMAL(10,2)) AS raw_gmv,
    CAST(SUM(CASE WHEN f.order_status = 'VALID' THEN f.amount ELSE 0 END) AS DECIMAL(10,2)) AS gross_valid_gmv,
    CAST(SUM(CASE WHEN f.order_status = 'CANCELLED' THEN f.amount ELSE 0 END) AS DECIMAL(10,2)) AS cancel_amount,
    CAST(SUM(CASE WHEN f.order_status = 'VALID' THEN f.refund_amount ELSE 0 END) AS DECIMAL(10,2)) AS refund_amount,
    CAST(SUM(CASE WHEN f.order_status = 'VALID' THEN f.net_amount ELSE 0 END) AS DECIMAL(10,2)) AS net_gmv
  FROM fct_order_refund_status_di f
  LEFT JOIN fct_order_channel_di c
    ON f.order_id = c.order_id
   AND f.dt = c.dt
  LEFT JOIN dim_channel_snapshot_di ch
    ON c.channel_id = ch.channel_id
   AND c.dt = ch.dt
  WHERE f.dt = '__RUN_DT__'
  GROUP BY COALESCE(ch.channel_name, 'unknown'), COALESCE(ch.channel_type, 'unknown')
),
dws AS (
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
)
SELECT 'dws_channel_trade_day_agg source reconcile check failed' AS err_msg
FROM source_agg
FULL OUTER JOIN dws
  ON source_agg.channel_name = dws.channel_name
 AND source_agg.channel_type = dws.channel_type
WHERE source_agg.channel_name IS NULL
   OR dws.channel_name IS NULL
   OR COALESCE(source_agg.trade_user_cnt, 0) <> COALESCE(dws.trade_user_cnt, 0)
   OR COALESCE(source_agg.raw_order_cnt, 0) <> COALESCE(dws.raw_order_cnt, 0)
   OR COALESCE(source_agg.valid_order_cnt, 0) <> COALESCE(dws.valid_order_cnt, 0)
   OR COALESCE(source_agg.cancel_order_cnt, 0) <> COALESCE(dws.cancel_order_cnt, 0)
   OR COALESCE(source_agg.raw_gmv, 0) <> COALESCE(dws.raw_gmv, 0)
   OR COALESCE(source_agg.gross_valid_gmv, 0) <> COALESCE(dws.gross_valid_gmv, 0)
   OR COALESCE(source_agg.cancel_amount, 0) <> COALESCE(dws.cancel_amount, 0)
   OR COALESCE(source_agg.refund_amount, 0) <> COALESCE(dws.refund_amount, 0)
   OR COALESCE(source_agg.net_gmv, 0) <> COALESCE(dws.net_gmv, 0);
