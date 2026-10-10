USE hive_demo;

WITH register_events AS (
  SELECT 'u01' AS user_id, '2026-03-01' AS register_date
  UNION ALL
  SELECT 'u02', '2026-03-01'
  UNION ALL
  SELECT 'u03', '2026-03-01'
  UNION ALL
  SELECT 'u04', '2026-03-02'
),
visit_events AS (
  SELECT 'u01' AS user_id, '2026-03-01' AS visit_date
  UNION ALL
  SELECT 'u01', '2026-03-02'
  UNION ALL
  SELECT 'u02', '2026-03-01'
  UNION ALL
  SELECT 'u03', '2026-03-01'
  UNION ALL
  SELECT 'u03', '2026-03-02'
  UNION ALL
  SELECT 'u04', '2026-03-02'
),
order_events AS (
  SELECT 'u01' AS user_id, 'o1001' AS order_id, '2026-03-01' AS order_date, CAST(100.00 AS DECIMAL(10,2)) AS amount
  UNION ALL
  SELECT 'u01', 'o1002', '2026-03-05', CAST(80.00 AS DECIMAL(10,2))
  UNION ALL
  SELECT 'u02', 'o2001', '2026-03-01', CAST(60.00 AS DECIMAL(10,2))
  UNION ALL
  SELECT 'u03', 'o3001', '2026-03-08', CAST(120.00 AS DECIMAL(10,2))
),
payment_events AS (
  SELECT 'u01' AS user_id, 'o1001' AS order_id, '2026-03-01' AS pay_date, CAST(100.00 AS DECIMAL(10,2)) AS pay_amount
  UNION ALL
  SELECT 'u01', 'o1002', '2026-03-05', CAST(80.00 AS DECIMAL(10,2))
  UNION ALL
  SELECT 'u02', 'o2001', '2026-03-01', CAST(60.00 AS DECIMAL(10,2))
),

-- 次日留存：某天注册用户，在注册次日是否访问。
next_day_retention AS (
  SELECT
    r.register_date AS stat_date,
    COUNT(DISTINCT r.user_id) AS register_users,
    COUNT(DISTINCT CASE WHEN v.user_id IS NOT NULL THEN r.user_id END) AS next_day_retained_users,
    CASE
      WHEN COUNT(DISTINCT r.user_id) = 0 THEN CAST(0.0000 AS DECIMAL(10,4))
      ELSE ROUND(
        COUNT(DISTINCT CASE WHEN v.user_id IS NOT NULL THEN r.user_id END)
        / COUNT(DISTINCT r.user_id),
        4
      )
    END AS next_day_retention_rate
  FROM register_events r
  LEFT JOIN visit_events v
    ON r.user_id = v.user_id
   AND v.visit_date = DATE_ADD(r.register_date, 1)
  GROUP BY r.register_date
),

-- 7 日复购：某天首单用户，在首单后 7 天内是否再次下单。
first_order AS (
  SELECT
    user_id,
    MIN(order_date) AS first_order_date
  FROM order_events
  GROUP BY user_id
),
repurchase_7d AS (
  SELECT
    f.first_order_date AS stat_date,
    COUNT(DISTINCT f.user_id) AS first_order_users,
    COUNT(DISTINCT CASE WHEN o.user_id IS NOT NULL THEN f.user_id END) AS repurchase_users_7d,
    CASE
      WHEN COUNT(DISTINCT f.user_id) = 0 THEN CAST(0.0000 AS DECIMAL(10,4))
      ELSE ROUND(
        COUNT(DISTINCT CASE WHEN o.user_id IS NOT NULL THEN f.user_id END)
        / COUNT(DISTINCT f.user_id),
        4
      )
    END AS repurchase_rate_7d
  FROM first_order f
  LEFT JOIN order_events o
    ON f.user_id = o.user_id
   AND o.order_date > f.first_order_date
   AND o.order_date <= DATE_ADD(f.first_order_date, 7)
  GROUP BY f.first_order_date
),

-- 漏斗：访问 -> 下单 -> 支付，按天统计用户数和转化率。
visit_user_day AS (
  SELECT DISTINCT
    user_id,
    visit_date AS stat_date
  FROM visit_events
),
order_user_day AS (
  SELECT DISTINCT
    user_id,
    order_date AS stat_date
  FROM order_events
),
payment_user_day AS (
  SELECT DISTINCT
    user_id,
    pay_date AS stat_date
  FROM payment_events
),
funnel AS (
  SELECT
    v.stat_date,
    COUNT(DISTINCT v.user_id) AS visit_users,
    COUNT(DISTINCT o.user_id) AS order_users,
    COUNT(DISTINCT p.user_id) AS pay_users,
    CASE
      WHEN COUNT(DISTINCT v.user_id) = 0 THEN CAST(0.0000 AS DECIMAL(10,4))
      ELSE ROUND(COUNT(DISTINCT o.user_id) / COUNT(DISTINCT v.user_id), 4)
    END AS visit_to_order_rate,
    CASE
      WHEN COUNT(DISTINCT o.user_id) = 0 THEN CAST(0.0000 AS DECIMAL(10,4))
      ELSE ROUND(COUNT(DISTINCT p.user_id) / COUNT(DISTINCT o.user_id), 4)
    END AS order_to_pay_rate,
    CASE
      WHEN COUNT(DISTINCT v.user_id) = 0 THEN CAST(0.0000 AS DECIMAL(10,4))
      ELSE ROUND(COUNT(DISTINCT p.user_id) / COUNT(DISTINCT v.user_id), 4)
    END AS visit_to_pay_rate
  FROM visit_user_day v
  LEFT JOIN order_user_day o
    ON v.user_id = o.user_id
   AND v.stat_date = o.stat_date
  LEFT JOIN payment_user_day p
    ON o.user_id = p.user_id
   AND o.stat_date = p.stat_date
  GROUP BY v.stat_date
)

SELECT
  'next_day_retention' AS metric_group,
  stat_date,
  register_users AS metric_1,
  next_day_retained_users AS metric_2,
  next_day_retention_rate AS metric_3,
  CAST(NULL AS DECIMAL(10,4)) AS metric_4,
  CAST(NULL AS DECIMAL(10,4)) AS metric_5,
  CAST(NULL AS DECIMAL(10,4)) AS metric_6
FROM next_day_retention
UNION ALL
SELECT
  'repurchase_7d' AS metric_group,
  stat_date,
  first_order_users AS metric_1,
  repurchase_users_7d AS metric_2,
  repurchase_rate_7d AS metric_3,
  CAST(NULL AS DECIMAL(10,4)) AS metric_4,
  CAST(NULL AS DECIMAL(10,4)) AS metric_5,
  CAST(NULL AS DECIMAL(10,4)) AS metric_6
FROM repurchase_7d
UNION ALL
SELECT
  'funnel' AS metric_group,
  stat_date,
  visit_users AS metric_1,
  order_users AS metric_2,
  pay_users AS metric_3,
  visit_to_order_rate AS metric_4,
  order_to_pay_rate AS metric_5,
  visit_to_pay_rate AS metric_6
FROM funnel
ORDER BY metric_group, stat_date;
