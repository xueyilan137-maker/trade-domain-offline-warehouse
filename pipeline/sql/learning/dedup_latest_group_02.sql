USE hive_demo;

WITH order_raw AS (
  SELECT 'o1001' AS order_id, 'u01' AS user_id, '2026-03-01 10:00:00' AS update_time, CAST(100.00 AS DECIMAL(10,2)) AS amount, 'create' AS event_type
  UNION ALL
  SELECT 'o1002', 'u01', '2026-03-01 11:00:00', CAST(80.00 AS DECIMAL(10,2)), 'create'
  UNION ALL
  SELECT 'o1002', 'u01', '2026-03-01 12:00:00', CAST(90.00 AS DECIMAL(10,2)), 'update'
  UNION ALL
  SELECT 'o1003', 'u02', '2026-03-02 09:00:00', CAST(60.00 AS DECIMAL(10,2)), 'create'
  UNION ALL
  SELECT 'o1003', 'u02', '2026-03-02 09:30:00', CAST(60.00 AS DECIMAL(10,2)), 'update'
),
ranked_orders AS (
  SELECT
    order_id,
    user_id,
    update_time,
    amount,
    event_type,
    ROW_NUMBER() OVER (
      PARTITION BY order_id
      ORDER BY update_time DESC, amount DESC
    ) AS rn
  FROM order_raw
),
user_level_raw AS (
  SELECT 'u01' AS user_id, 'silver' AS user_level, '2026-03-01' AS change_date
  UNION ALL
  SELECT 'u01', 'gold', '2026-03-05'
  UNION ALL
  SELECT 'u02', 'normal', '2026-03-01'
  UNION ALL
  SELECT 'u02', 'silver', '2026-03-03'
  UNION ALL
  SELECT 'u02', 'gold', '2026-03-04'
),
ranked_user_level AS (
  SELECT
    user_id,
    user_level,
    change_date,
    ROW_NUMBER() OVER (
      PARTITION BY user_id
      ORDER BY change_date DESC
    ) AS rn
  FROM user_level_raw
)
SELECT
  'order_dedup_latest' AS case_name,
  order_id AS biz_id,
  user_id,
  update_time AS biz_time,
  CAST(amount AS STRING) AS biz_value,
  event_type AS extra_info
FROM ranked_orders
WHERE rn = 1
UNION ALL
SELECT
  'user_latest_level' AS case_name,
  user_id AS biz_id,
  user_id,
  change_date AS biz_time,
  user_level AS biz_value,
  'latest_level' AS extra_info
FROM ranked_user_level
WHERE rn = 1
ORDER BY case_name, biz_id;
