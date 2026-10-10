USE hive_demo;

-- Group 11: channel theme joins trade domain.
-- Goal:
--   Analyze trade metrics by traffic/order channel.
-- Core idea:
--   channel dimension + order channel fact + order refund status fact
--   -> channel-level trade overview.

WITH channel_snapshot AS (
  SELECT '2026-03-05' AS dt, 'ch01' AS channel_id, 'App' AS channel_name, 'Owned' AS channel_type
  UNION ALL
  SELECT '2026-03-05', 'ch02', 'Mini Program', 'Owned'
  UNION ALL
  SELECT '2026-03-05', 'ch03', 'Ad Campaign', 'Paid'
),
order_channel AS (
  SELECT '2026-03-05' AS dt, 'o2001' AS order_id, 'u10' AS user_id, 'ch01' AS channel_id
  UNION ALL
  SELECT '2026-03-05', 'o2002', 'u11', 'ch03'
  UNION ALL
  SELECT '2026-03-05', 'o2005', 'u14', 'ch02'
),
order_status AS (
  SELECT
    '2026-03-05' AS dt,
    'o2001' AS order_id,
    'u10' AS user_id,
    CAST(100.00 AS DECIMAL(10,2)) AS amount,
    'VALID' AS order_status,
    CAST(20.00 AS DECIMAL(10,2)) AS refund_amount,
    CAST(80.00 AS DECIMAL(10,2)) AS net_amount
  UNION ALL
  SELECT
    '2026-03-05',
    'o2002',
    'u11',
    CAST(90.00 AS DECIMAL(10,2)),
    'CANCELLED',
    CAST(0.00 AS DECIMAL(10,2)),
    CAST(0.00 AS DECIMAL(10,2))
  UNION ALL
  SELECT
    '2026-03-05',
    'o2005',
    'u14',
    CAST(30.00 AS DECIMAL(10,2)),
    'VALID',
    CAST(0.00 AS DECIMAL(10,2)),
    CAST(30.00 AS DECIMAL(10,2))
),
order_with_channel AS (
  SELECT
    s.dt,
    s.order_id,
    s.user_id,
    COALESCE(c.channel_id, 'unknown') AS channel_id,
    COALESCE(ch.channel_name, 'unknown') AS channel_name,
    COALESCE(ch.channel_type, 'unknown') AS channel_type,
    s.amount,
    s.order_status,
    s.refund_amount,
    s.net_amount
  FROM order_status s
  LEFT JOIN order_channel c
    ON s.order_id = c.order_id
   AND s.dt = c.dt
  LEFT JOIN channel_snapshot ch
    ON c.channel_id = ch.channel_id
   AND c.dt = ch.dt
),
channel_trade_agg AS (
  SELECT
    dt,
    channel_name,
    channel_type,
    COUNT(DISTINCT user_id) AS trade_user_cnt,
    COUNT(*) AS raw_order_cnt,
    SUM(CASE WHEN order_status = 'VALID' THEN 1 ELSE 0 END) AS valid_order_cnt,
    SUM(CASE WHEN order_status = 'CANCELLED' THEN 1 ELSE 0 END) AS cancel_order_cnt,
    CAST(SUM(amount) AS DECIMAL(10,2)) AS raw_gmv,
    CAST(SUM(CASE WHEN order_status = 'VALID' THEN amount ELSE 0 END) AS DECIMAL(10,2)) AS gross_valid_gmv,
    CAST(SUM(CASE WHEN order_status = 'CANCELLED' THEN amount ELSE 0 END) AS DECIMAL(10,2)) AS cancel_amount,
    CAST(SUM(CASE WHEN order_status = 'VALID' THEN refund_amount ELSE 0 END) AS DECIMAL(10,2)) AS refund_amount,
    CAST(SUM(CASE WHEN order_status = 'VALID' THEN net_amount ELSE 0 END) AS DECIMAL(10,2)) AS net_gmv
  FROM order_with_channel
  GROUP BY dt, channel_name, channel_type
)

SELECT
  dt,
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
  net_gmv,
  CAST(ROUND(cancel_order_cnt / NULLIF(raw_order_cnt, 0), 4) AS DECIMAL(10,4)) AS cancel_order_rate,
  CAST(ROUND(refund_amount / NULLIF(gross_valid_gmv, 0), 4) AS DECIMAL(10,4)) AS refund_gmv_rate
FROM channel_trade_agg
ORDER BY channel_name;
