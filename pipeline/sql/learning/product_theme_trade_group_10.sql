USE hive_demo;

-- Group 10: product theme joins trade domain.
-- Goal:
--   Analyze trade metrics by product category.
-- Core idea:
--   product snapshot + order item fact + order refund status fact
--   -> category-level trade overview.

WITH product_snapshot AS (
  SELECT '2026-03-05' AS dt, 'p01' AS product_id, 'Mouse' AS product_name, 'c01' AS category_id, 'Digital Accessories' AS category_name, 'Logitech' AS brand_name
  UNION ALL
  SELECT '2026-03-05', 'p02', 'Keyboard', 'c01', 'Digital Accessories', 'Keychron'
  UNION ALL
  SELECT '2026-03-05', 'p03', 'Bottle', 'c02', 'Daily Goods', 'Migo'
),
order_item AS (
  SELECT '2026-03-05' AS dt, 'o2001' AS order_id, 'u10' AS user_id, 'p01' AS product_id, 1 AS item_cnt, CAST(40.00 AS DECIMAL(10,2)) AS item_amount
  UNION ALL
  SELECT '2026-03-05', 'o2001', 'u10', 'p02', 1, CAST(60.00 AS DECIMAL(10,2))
  UNION ALL
  SELECT '2026-03-05', 'o2002', 'u11', 'p03', 1, CAST(90.00 AS DECIMAL(10,2))
  UNION ALL
  SELECT '2026-03-05', 'o2005', 'u14', 'p01', 1, CAST(30.00 AS DECIMAL(10,2))
),
order_status AS (
  SELECT
    '2026-03-05' AS dt,
    'o2001' AS order_id,
    'u10' AS user_id,
    CAST(100.00 AS DECIMAL(10,2)) AS order_amount,
    'VALID' AS order_status,
    CAST(20.00 AS DECIMAL(10,2)) AS refund_amount
  UNION ALL
  SELECT
    '2026-03-05',
    'o2002',
    'u11',
    CAST(90.00 AS DECIMAL(10,2)),
    'CANCELLED',
    CAST(0.00 AS DECIMAL(10,2))
  UNION ALL
  SELECT
    '2026-03-05',
    'o2005',
    'u14',
    CAST(30.00 AS DECIMAL(10,2)),
    'VALID',
    CAST(0.00 AS DECIMAL(10,2))
),
order_item_with_status AS (
  SELECT
    i.dt,
    i.order_id,
    i.user_id,
    i.product_id,
    i.item_cnt,
    i.item_amount,
    s.order_amount,
    s.order_status,
    CAST(
      CASE
        WHEN s.order_status = 'VALID' AND s.order_amount > 0
          THEN i.item_amount / s.order_amount * s.refund_amount
        ELSE 0
      END
      AS DECIMAL(10,2)
    ) AS item_refund_amount
  FROM order_item i
  LEFT JOIN order_status s
    ON i.order_id = s.order_id
   AND i.dt = s.dt
),
order_item_with_product AS (
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
  FROM order_item_with_status i
  LEFT JOIN product_snapshot p
    ON i.product_id = p.product_id
   AND i.dt = p.dt
),
category_trade_agg AS (
  SELECT
    dt,
    category_name,
    COUNT(DISTINCT order_id) AS raw_order_cnt,
    COUNT(DISTINCT user_id) AS trade_user_cnt,
    SUM(item_cnt) AS item_cnt,
    CAST(SUM(item_amount) AS DECIMAL(10,2)) AS raw_item_amount,
    CAST(SUM(CASE WHEN order_status = 'VALID' THEN item_amount ELSE 0 END) AS DECIMAL(10,2)) AS valid_item_amount,
    CAST(SUM(CASE WHEN order_status = 'CANCELLED' THEN item_amount ELSE 0 END) AS DECIMAL(10,2)) AS cancel_item_amount,
    CAST(SUM(item_refund_amount) AS DECIMAL(10,2)) AS refund_amount,
    CAST(SUM(CASE WHEN order_status = 'VALID' THEN item_amount ELSE 0 END) - SUM(item_refund_amount) AS DECIMAL(10,2)) AS net_item_amount
  FROM order_item_with_product
  GROUP BY dt, category_name
)

SELECT
  dt,
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
FROM category_trade_agg
ORDER BY category_name;
