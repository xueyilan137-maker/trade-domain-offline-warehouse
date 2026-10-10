USE hive_demo;

WITH normalized AS (
  SELECT
    order_id AS raw_order_id,
    user_id AS raw_user_id,
    order_date AS raw_order_date,
    CAST(amount AS DECIMAL(10,2)) AS amount,
    TRIM(order_id) AS order_id,
    TRIM(user_id) AS user_id,
    TRIM(order_date) AS order_date
  FROM dwd_order_p
  WHERE dt = '__RUN_DT__'
),
invalid_rows AS (
  SELECT
    raw_order_id AS order_id,
    raw_user_id AS user_id,
    raw_order_date AS order_date,
    amount,
    CASE
      WHEN order_id IS NULL OR order_id = '' THEN 'order_id_empty'
      WHEN user_id IS NULL OR user_id = '' THEN 'user_id_empty'
      WHEN order_date IS NULL OR order_date = '' THEN 'order_date_empty'
      WHEN amount IS NULL THEN 'amount_null'
      WHEN amount < 0 THEN 'amount_negative'
      ELSE 'unknown_dirty'
    END AS dirty_reason
  FROM normalized
  WHERE order_id IS NULL
    OR order_id = ''
    OR user_id IS NULL
    OR user_id = ''
    OR order_date IS NULL
    OR order_date = ''
    OR amount IS NULL
    OR amount < 0
),
valid_rows AS (
  SELECT
    order_id,
    user_id,
    order_date,
    amount
  FROM normalized
  WHERE order_id IS NOT NULL
    AND order_id <> ''
    AND user_id IS NOT NULL
    AND user_id <> ''
    AND order_date IS NOT NULL
    AND order_date <> ''
    AND amount IS NOT NULL
    AND amount >= 0
),
ranked_valid_rows AS (
  SELECT
    order_id,
    user_id,
    order_date,
    amount,
    ROW_NUMBER() OVER (
      PARTITION BY order_id
      ORDER BY order_date DESC, user_id ASC, amount DESC
    ) AS rn
  FROM valid_rows
),
duplicate_rows AS (
  SELECT
    order_id,
    user_id,
    order_date,
    amount,
    'duplicate_order_id' AS dirty_reason
  FROM ranked_valid_rows
  WHERE rn > 1
)
INSERT OVERWRITE TABLE dwd_order_dirty_di PARTITION (dt='__RUN_DT__')
SELECT
  order_id,
  user_id,
  order_date,
  amount,
  dirty_reason
FROM invalid_rows
UNION ALL
SELECT
  order_id,
  user_id,
  order_date,
  amount,
  dirty_reason
FROM duplicate_rows;
