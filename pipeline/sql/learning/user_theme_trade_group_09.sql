USE hive_demo;

-- Group 09: user theme joins trade domain.
-- Goal:
--   Add user_level as an analysis dimension for order/cancel/refund metrics.
-- Core idea:
--   user snapshot dimension + trade fact metrics -> user-level trade overview.

WITH user_snapshot AS (
  SELECT '2026-03-05' AS dt, 'u10' AS user_id, 'Alice' AS user_name, 'gold' AS user_level
  UNION ALL
  SELECT '2026-03-05', 'u11', 'Bob', 'silver'
  UNION ALL
  SELECT '2026-03-05', 'u14', 'Cindy', 'normal'
  UNION ALL
  SELECT '2026-03-05', 'u99', 'NoOrderUser', 'normal'
),
trade_fact AS (
  SELECT
    '2026-03-05' AS dt,
    'o2001' AS order_id,
    'u10' AS user_id,
    CAST(100.00 AS DECIMAL(10,2)) AS amount,
    'VALID' AS order_status,
    0 AS is_cancelled,
    1 AS is_refunded,
    CAST(20.00 AS DECIMAL(10,2)) AS refund_amount,
    CAST(80.00 AS DECIMAL(10,2)) AS net_amount
  UNION ALL
  SELECT
    '2026-03-05',
    'o2002',
    'u11',
    CAST(90.00 AS DECIMAL(10,2)),
    'CANCELLED',
    1,
    0,
    CAST(0.00 AS DECIMAL(10,2)),
    CAST(0.00 AS DECIMAL(10,2))
  UNION ALL
  SELECT
    '2026-03-05',
    'o2005',
    'u14',
    CAST(30.00 AS DECIMAL(10,2)),
    'VALID',
    0,
    0,
    CAST(0.00 AS DECIMAL(10,2)),
    CAST(30.00 AS DECIMAL(10,2))
),
trade_with_user_level AS (
  SELECT
    t.dt,
    t.order_id,
    t.user_id,
    COALESCE(u.user_level, 'unknown') AS user_level,
    t.amount,
    t.order_status,
    t.is_cancelled,
    t.is_refunded,
    t.refund_amount,
    t.net_amount
  FROM trade_fact t
  LEFT JOIN user_snapshot u
    ON t.user_id = u.user_id
   AND t.dt = u.dt
),
user_level_trade_agg AS (
  SELECT
    dt,
    user_level,
    COUNT(DISTINCT user_id) AS trade_user_cnt,
    COUNT(*) AS raw_order_cnt,
    SUM(CASE WHEN order_status = 'VALID' THEN 1 ELSE 0 END) AS valid_order_cnt,
    SUM(CASE WHEN order_status = 'CANCELLED' THEN 1 ELSE 0 END) AS cancel_order_cnt,
    CAST(SUM(CASE WHEN order_status = 'VALID' THEN amount ELSE 0 END) AS DECIMAL(10,2)) AS gross_valid_gmv,
    SUM(CASE WHEN order_status = 'VALID' AND is_refunded = 1 THEN 1 ELSE 0 END) AS refund_order_cnt,
    CAST(SUM(CASE WHEN order_status = 'VALID' THEN refund_amount ELSE 0 END) AS DECIMAL(10,2)) AS refund_amount,
    CAST(SUM(CASE WHEN order_status = 'VALID' THEN net_amount ELSE 0 END) AS DECIMAL(10,2)) AS net_gmv
  FROM trade_with_user_level
  GROUP BY dt, user_level
)

SELECT
  dt,
  user_level,
  trade_user_cnt,
  raw_order_cnt,
  valid_order_cnt,
  cancel_order_cnt,
  gross_valid_gmv,
  refund_order_cnt,
  refund_amount,
  net_gmv,
  ROUND(refund_order_cnt / NULLIF(valid_order_cnt, 0), 4) AS refund_order_rate,
  ROUND(refund_amount / NULLIF(gross_valid_gmv, 0), 4) AS refund_gmv_rate
FROM user_level_trade_agg
ORDER BY user_level;
