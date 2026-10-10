USE hive_demo;

WITH orders AS (
  SELECT 'u01' AS user_id, 'o1001' AS order_id, '2026-03-01' AS order_date, CAST(100.00 AS DECIMAL(10,2)) AS amount
  UNION ALL
  SELECT 'u01', 'o1002', '2026-03-02', CAST(80.00 AS DECIMAL(10,2))
  UNION ALL
  SELECT 'u01', 'o1003', '2026-03-03', CAST(80.00 AS DECIMAL(10,2))
  UNION ALL
  SELECT 'u01', 'o1004', '2026-03-05', CAST(150.00 AS DECIMAL(10,2))
  UNION ALL
  SELECT 'u02', 'o2001', '2026-03-01', CAST(60.00 AS DECIMAL(10,2))
  UNION ALL
  SELECT 'u02', 'o2002', '2026-03-04', CAST(120.00 AS DECIMAL(10,2))
)
SELECT
  user_id,
  order_id,
  order_date,
  amount,
  ROW_NUMBER() OVER (
    PARTITION BY user_id
    ORDER BY amount DESC, order_date ASC
  ) AS rn_by_amount,
  RANK() OVER (
    PARTITION BY user_id
    ORDER BY amount DESC
  ) AS rank_by_amount,
  DENSE_RANK() OVER (
    PARTITION BY user_id
    ORDER BY amount DESC
  ) AS dense_rank_by_amount,
  LAG(amount) OVER (
    PARTITION BY user_id
    ORDER BY order_date ASC
  ) AS prev_amount,
  LEAD(amount) OVER (
    PARTITION BY user_id
    ORDER BY order_date ASC
  ) AS next_amount,
  SUM(amount) OVER (
    PARTITION BY user_id
    ORDER BY order_date ASC
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  ) AS cumulative_amount,
  SUM(amount) OVER (
    PARTITION BY user_id
  ) AS user_total_amount
FROM orders
ORDER BY user_id, order_date;
