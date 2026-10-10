USE hive_demo;

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
item_with_product AS (
  SELECT
    i.dt,
    i.order_id,
    i.user_id,
    i.product_id,
    COALESCE(p.category_name, 'unknown') AS category_name,
    i.item_cnt,
    i.item_amount,
    i.order_status,
    i.item_refund_amount
  FROM item_with_status i
  LEFT JOIN dim_product_snapshot_di p
    ON i.product_id = p.product_id
   AND i.dt = p.dt
)
INSERT OVERWRITE TABLE dws_category_trade_day_agg PARTITION (dt='__RUN_DT__')
SELECT
  category_name,
  COUNT(DISTINCT order_id) AS raw_order_cnt,
  COUNT(DISTINCT user_id) AS trade_user_cnt,
  SUM(item_cnt) AS item_cnt,
  CAST(SUM(item_amount) AS DECIMAL(10,2)) AS raw_item_amount,
  CAST(SUM(CASE WHEN order_status = 'VALID' THEN item_amount ELSE 0 END) AS DECIMAL(10,2)) AS valid_item_amount,
  CAST(SUM(CASE WHEN order_status = 'CANCELLED' THEN item_amount ELSE 0 END) AS DECIMAL(10,2)) AS cancel_item_amount,
  CAST(SUM(item_refund_amount) AS DECIMAL(10,2)) AS refund_amount,
  CAST(SUM(CASE WHEN order_status = 'VALID' THEN item_amount ELSE 0 END) - SUM(item_refund_amount) AS DECIMAL(10,2)) AS net_item_amount
FROM item_with_product
GROUP BY category_name;
