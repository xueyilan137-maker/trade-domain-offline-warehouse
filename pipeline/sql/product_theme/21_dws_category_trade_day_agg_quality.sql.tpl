USE hive_demo;

SELECT 'dws_category_trade_day_agg row count check failed' AS err_msg
WHERE (
  SELECT COUNT(*)
  FROM dws_category_trade_day_agg
  WHERE dt = '__RUN_DT__'
) = 0;

SELECT 'dws_category_trade_day_agg duplicate category check failed' AS err_msg
WHERE EXISTS (
  SELECT category_name
  FROM dws_category_trade_day_agg
  WHERE dt = '__RUN_DT__'
  GROUP BY category_name
  HAVING COUNT(*) > 1
);

SELECT 'dws_category_trade_day_agg negative metric check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM dws_category_trade_day_agg
  WHERE dt = '__RUN_DT__'
    AND (
      raw_order_cnt < 0
      OR trade_user_cnt < 0
      OR item_cnt < 0
      OR raw_item_amount < 0
      OR valid_item_amount < 0
      OR cancel_item_amount < 0
      OR refund_amount < 0
      OR net_item_amount < 0
    )
);

SELECT 'dws_category_trade_day_agg amount split check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM dws_category_trade_day_agg
  WHERE dt = '__RUN_DT__'
    AND raw_item_amount <> valid_item_amount + cancel_item_amount
);

SELECT 'dws_category_trade_day_agg net amount check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM dws_category_trade_day_agg
  WHERE dt = '__RUN_DT__'
    AND net_item_amount <> valid_item_amount - refund_amount
);

WITH item_with_status AS (
  SELECT
    i.dt,
    i.order_id,
    i.user_id,
    i.product_id,
    i.item_cnt,
    i.item_amount,
    s.amount AS order_amount,
    s.order_status,
    CAST(
      CASE
        WHEN s.order_status = 'VALID'
          AND s.amount > 0
          THEN i.item_amount / s.amount * s.refund_amount
        ELSE 0
      END
      AS DECIMAL(10,2)
    ) AS item_refund_amount
  FROM fct_order_item_di i
  LEFT JOIN fct_order_refund_status_di s
    ON i.order_id = s.order_id
   AND i.dt = s.dt
  WHERE i.dt = '__RUN_DT__'
),
source_agg AS (
  SELECT
    COALESCE(p.category_name, 'unknown') AS category_name,
    COUNT(DISTINCT i.order_id) AS raw_order_cnt,
    COUNT(DISTINCT i.user_id) AS trade_user_cnt,
    SUM(i.item_cnt) AS item_cnt,
    CAST(SUM(i.item_amount) AS DECIMAL(10,2)) AS raw_item_amount,
    CAST(SUM(CASE WHEN i.order_status = 'VALID' THEN i.item_amount ELSE 0 END) AS DECIMAL(10,2)) AS valid_item_amount,
    CAST(SUM(CASE WHEN i.order_status = 'CANCELLED' THEN i.item_amount ELSE 0 END) AS DECIMAL(10,2)) AS cancel_item_amount,
    CAST(SUM(i.item_refund_amount) AS DECIMAL(10,2)) AS refund_amount,
    CAST(SUM(CASE WHEN i.order_status = 'VALID' THEN i.item_amount ELSE 0 END) - SUM(i.item_refund_amount) AS DECIMAL(10,2)) AS net_item_amount
  FROM item_with_status i
  LEFT JOIN dim_product_snapshot_di p
    ON i.product_id = p.product_id
   AND i.dt = p.dt
  GROUP BY COALESCE(p.category_name, 'unknown')
),
dws AS (
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
)
SELECT 'dws_category_trade_day_agg source reconcile check failed' AS err_msg
FROM source_agg
FULL OUTER JOIN dws
  ON source_agg.category_name = dws.category_name
WHERE source_agg.category_name IS NULL
   OR dws.category_name IS NULL
   OR COALESCE(source_agg.raw_order_cnt, 0) <> COALESCE(dws.raw_order_cnt, 0)
   OR COALESCE(source_agg.trade_user_cnt, 0) <> COALESCE(dws.trade_user_cnt, 0)
   OR COALESCE(source_agg.item_cnt, 0) <> COALESCE(dws.item_cnt, 0)
   OR COALESCE(source_agg.raw_item_amount, 0) <> COALESCE(dws.raw_item_amount, 0)
   OR COALESCE(source_agg.valid_item_amount, 0) <> COALESCE(dws.valid_item_amount, 0)
   OR COALESCE(source_agg.cancel_item_amount, 0) <> COALESCE(dws.cancel_item_amount, 0)
   OR COALESCE(source_agg.refund_amount, 0) <> COALESCE(dws.refund_amount, 0)
   OR COALESCE(source_agg.net_item_amount, 0) <> COALESCE(dws.net_item_amount, 0);
