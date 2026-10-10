USE hive_demo;

WITH orders AS (
  SELECT 'o1001' AS order_id, 'u01' AS user_id, CAST(100.00 AS DECIMAL(10,2)) AS amount
  UNION ALL
  SELECT 'o1002', 'u02', CAST(80.00 AS DECIMAL(10,2))
  UNION ALL
  SELECT 'o1003', 'u03', CAST(60.00 AS DECIMAL(10,2))
),
payments AS (
  SELECT 'p01' AS payment_id, 'o1001' AS order_id, CAST(100.00 AS DECIMAL(10,2)) AS pay_amount
  UNION ALL
  SELECT 'p02', 'o1002', CAST(30.00 AS DECIMAL(10,2))
  UNION ALL
  SELECT 'p03', 'o1002', CAST(50.00 AS DECIMAL(10,2))
  UNION ALL
  SELECT 'p04', 'o9999', CAST(20.00 AS DECIMAL(10,2))
),
payment_agg AS (
  SELECT
    order_id,
    SUM(pay_amount) AS pay_amount
  FROM payments
  GROUP BY order_id
),
left_join_detail AS (
  SELECT
    'left_join_detail_wrong_grain' AS case_name,
    COUNT(*) AS row_cnt,
    SUM(o.amount) AS order_amount_sum,
    SUM(COALESCE(p.pay_amount, 0)) AS pay_amount_sum
  FROM orders o
  LEFT JOIN payments p
    ON o.order_id = p.order_id
),
left_join_agg AS (
  SELECT
    'left_join_agg_correct_grain' AS case_name,
    COUNT(*) AS row_cnt,
    SUM(o.amount) AS order_amount_sum,
    SUM(COALESCE(p.pay_amount, 0)) AS pay_amount_sum
  FROM orders o
  LEFT JOIN payment_agg p
    ON o.order_id = p.order_id
),
inner_join_agg AS (
  SELECT
    'inner_join_only_paid_orders' AS case_name,
    COUNT(*) AS row_cnt,
    SUM(o.amount) AS order_amount_sum,
    SUM(p.pay_amount) AS pay_amount_sum
  FROM orders o
  INNER JOIN payment_agg p
    ON o.order_id = p.order_id
),
left_anti_unpaid AS (
  SELECT
    'left_anti_unpaid_orders' AS case_name,
    COUNT(*) AS row_cnt,
    SUM(o.amount) AS order_amount_sum,
    CAST(0 AS DECIMAL(10,2)) AS pay_amount_sum
  FROM orders o
  LEFT ANTI JOIN payment_agg p
    ON o.order_id = p.order_id
)
SELECT * FROM left_join_detail
UNION ALL
SELECT * FROM left_join_agg
UNION ALL
SELECT * FROM inner_join_agg
UNION ALL
SELECT * FROM left_anti_unpaid
ORDER BY case_name;
