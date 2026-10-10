USE hive_demo;

WITH normalized AS (
  SELECT
    TRIM(order_id) AS order_id,
    TRIM(user_id) AS user_id,
    TRIM(order_date) AS order_date,
    CAST(amount AS DECIMAL(10,2)) AS amount
  FROM dwd_order_p
  WHERE dt = '__RUN_DT__'
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
deduped AS (
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
)
INSERT OVERWRITE TABLE dwd_order_clean_di PARTITION (dt='__RUN_DT__')
SELECT
  order_id,
  user_id,
  order_date,
  amount
FROM deduped
WHERE rn = 1;
