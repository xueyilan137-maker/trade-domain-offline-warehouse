USE hive_demo;

-- 第八组：复杂 SQL 综合题（标准答案版）

WITH base_orders AS (
  SELECT '2026-03-01' AS dt, 'o1001' AS order_id, 'u01' AS user_id, CAST(100.00 AS DECIMAL(10,2)) AS amount, 'VALID' AS order_status
  UNION ALL
  SELECT '2026-03-01', 'o1002', 'u02', CAST(80.00 AS DECIMAL(10,2)), 'CANCELLED'
  UNION ALL
  SELECT '2026-03-01', 'o1003', 'u03', CAST(60.00 AS DECIMAL(10,2)), 'VALID'
  UNION ALL
  SELECT '2026-03-02', 'o2001', 'u01', CAST(120.00 AS DECIMAL(10,2)), 'VALID'
  UNION ALL
  SELECT '2026-03-02', 'o2002', 'u02', CAST(50.00 AS DECIMAL(10,2)), 'VALID'
  UNION ALL
  SELECT '2026-03-02', 'o2003', 'u04', CAST(90.00 AS DECIMAL(10,2)), 'VALID'
),
payments AS (
  SELECT '2026-03-01' AS dt, 'p01' AS payment_id, 'o1001' AS order_id, CAST(100.00 AS DECIMAL(10,2)) AS pay_amount
  UNION ALL
  SELECT '2026-03-01', 'p02', 'o1003', CAST(60.00 AS DECIMAL(10,2))
  UNION ALL
  SELECT '2026-03-02', 'p03', 'o2001', CAST(120.00 AS DECIMAL(10,2))
  UNION ALL
  SELECT '2026-03-02', 'p04', 'o2002', CAST(50.00 AS DECIMAL(10,2))
),
refunds AS (
  SELECT '2026-03-01' AS dt, 'o1001' AS order_id, CAST(20.00 AS DECIMAL(10,2)) AS refund_amount
  UNION ALL
  SELECT '2026-03-02', 'o2001', CAST(30.00 AS DECIMAL(10,2))
),
user_level_snapshot AS (
  SELECT '2026-03-01' AS dt, 'u01' AS user_id, 'gold' AS user_level
  UNION ALL
  SELECT '2026-03-01', 'u02', 'silver'
  UNION ALL
  SELECT '2026-03-01', 'u03', 'normal'
  UNION ALL
  SELECT '2026-03-02', 'u01', 'gold'
  UNION ALL
  SELECT '2026-03-02', 'u02', 'silver'
  UNION ALL
  SELECT '2026-03-02', 'u04', 'normal'
),
payment_agg AS (
  SELECT
    order_id,
    SUM(pay_amount) AS pay_amount
  FROM payments
  GROUP BY order_id
),
refund_agg AS (
  SELECT
    order_id,
    SUM(refund_amount) AS refund_amount
  FROM refunds
  GROUP BY order_id
),
order_wide AS (
  SELECT
    o.dt,
    o.order_id,
    o.user_id,
    o.amount,
    o.order_status,
    CASE WHEN o.order_status = 'VALID' THEN 1 ELSE 0 END AS is_valid,
    CASE WHEN o.order_status = 'CANCELLED' THEN 1 ELSE 0 END AS is_cancelled,
    COALESCE(p.pay_amount, CAST(0.00 AS DECIMAL(10,2))) AS pay_amount,
    COALESCE(r.refund_amount, CAST(0.00 AS DECIMAL(10,2))) AS refund_amount
  FROM base_orders o
  LEFT JOIN payment_agg p
    ON o.order_id = p.order_id
  LEFT JOIN refund_agg r
    ON o.order_id = r.order_id
),
trade_base AS (
  SELECT
    dt,
    COUNT(*) AS raw_order_cnt,
    SUM(is_valid) AS valid_order_cnt,
    SUM(is_cancelled) AS cancel_order_cnt,
    SUM(amount) AS raw_gmv,
    SUM(CASE WHEN is_valid = 1 THEN amount ELSE 0 END) AS gross_valid_gmv,
    SUM(CASE WHEN is_valid = 1 AND pay_amount > 0 THEN 1 ELSE 0 END) AS pay_order_cnt,
    SUM(CASE WHEN is_valid = 1 THEN pay_amount ELSE 0 END) AS pay_amount,
    SUM(CASE WHEN is_valid = 1 AND refund_amount > 0 THEN 1 ELSE 0 END) AS refund_order_cnt,
    SUM(CASE WHEN is_valid = 1 THEN refund_amount ELSE 0 END) AS refund_amount
  FROM order_wide
  GROUP BY dt
),
trade_day_metrics AS (
  SELECT
    dt,
    raw_order_cnt,
    valid_order_cnt,
    cancel_order_cnt,
    raw_gmv,
    gross_valid_gmv,
    pay_order_cnt,
    pay_amount,
    refund_order_cnt,
    refund_amount,
    gross_valid_gmv - refund_amount AS net_gmv,
    CASE
      WHEN valid_order_cnt = 0 THEN CAST(0.0000 AS DECIMAL(10,4))
      ELSE ROUND(pay_order_cnt / valid_order_cnt, 4)
    END AS pay_success_rate,
    CASE
      WHEN valid_order_cnt = 0 THEN CAST(0.0000 AS DECIMAL(10,4))
      ELSE ROUND(refund_order_cnt / valid_order_cnt, 4)
    END AS refund_order_rate
  FROM trade_base
),
valid_orders AS (
  SELECT
    dt,
    order_id,
    user_id,
    amount
  FROM base_orders
  WHERE order_status = 'VALID'
),
user_order_agg AS (
  SELECT
    user_id,
    MIN(dt) AS first_order_dt,
    COUNT(*) AS valid_order_cnt,
    SUM(amount) AS valid_gmv
  FROM valid_orders
  GROUP BY user_id
),
user_first_level AS (
  SELECT
    u.user_id,
    u.first_order_dt,
    u.valid_order_cnt,
    u.valid_gmv,
    COALESCE(s.user_level, 'unknown') AS user_level
  FROM user_order_agg u
  LEFT JOIN user_level_snapshot s
    ON u.user_id = s.user_id
   AND u.first_order_dt = s.dt
),
user_level_repurchase_metrics AS (
  SELECT
    user_level,
    COUNT(DISTINCT user_id) AS first_order_users,
    COUNT(DISTINCT CASE WHEN valid_order_cnt >= 2 THEN user_id END) AS repurchase_users,
    CASE
      WHEN COUNT(DISTINCT user_id) = 0 THEN CAST(0.0000 AS DECIMAL(10,4))
      ELSE ROUND(
        COUNT(DISTINCT CASE WHEN valid_order_cnt >= 2 THEN user_id END)
        / COUNT(DISTINCT user_id),
        4
      )
    END AS repurchase_rate,
    SUM(valid_gmv) AS valid_gmv
  FROM user_first_level
  GROUP BY user_level
)

SELECT
  'A_trade_day_metrics' AS result_name,
  CAST(dt AS STRING) AS col_1,
  CAST(raw_order_cnt AS STRING) AS col_2,
  CAST(valid_order_cnt AS STRING) AS col_3,
  CAST(cancel_order_cnt AS STRING) AS col_4,
  CAST(raw_gmv AS STRING) AS col_5,
  CAST(gross_valid_gmv AS STRING) AS col_6,
  CAST(pay_order_cnt AS STRING) AS col_7,
  CAST(pay_amount AS STRING) AS col_8,
  CAST(refund_order_cnt AS STRING) AS col_9,
  CAST(refund_amount AS STRING) AS col_10,
  CAST(net_gmv AS STRING) AS col_11,
  CAST(pay_success_rate AS STRING) AS col_12,
  CAST(refund_order_rate AS STRING) AS col_13
FROM trade_day_metrics
UNION ALL
SELECT
  'B_user_level_repurchase_metrics' AS result_name,
  CAST(user_level AS STRING) AS col_1,
  CAST(first_order_users AS STRING) AS col_2,
  CAST(repurchase_users AS STRING) AS col_3,
  CAST(repurchase_rate AS STRING) AS col_4,
  CAST(valid_gmv AS STRING) AS col_5,
  NULL AS col_6,
  NULL AS col_7,
  NULL AS col_8,
  NULL AS col_9,
  NULL AS col_10,
  NULL AS col_11,
  NULL AS col_12,
  NULL AS col_13
FROM user_level_repurchase_metrics
ORDER BY result_name, col_1;
