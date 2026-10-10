USE hive_demo;

WITH normalized AS (
  SELECT
    payment_id AS raw_payment_id,
    order_id AS raw_order_id,
    user_id AS raw_user_id,
    pay_date AS raw_pay_date,
    CAST(pay_amount AS DECIMAL(10,2)) AS pay_amount,
    pay_status AS raw_pay_status,
    TRIM(payment_id) AS payment_id,
    TRIM(order_id) AS order_id,
    TRIM(user_id) AS user_id,
    TRIM(pay_date) AS pay_date,
    UPPER(TRIM(pay_status)) AS pay_status
  FROM dwd_payment_p
  WHERE dt = '__RUN_DT__'
),
invalid_rows AS (
  SELECT
    raw_payment_id AS payment_id,
    raw_order_id AS order_id,
    raw_user_id AS user_id,
    raw_pay_date AS pay_date,
    pay_amount,
    raw_pay_status AS pay_status,
    CASE
      WHEN payment_id IS NULL OR payment_id = '' THEN 'payment_id_empty'
      WHEN order_id IS NULL OR order_id = '' THEN 'order_id_empty'
      WHEN user_id IS NULL OR user_id = '' THEN 'user_id_empty'
      WHEN pay_date IS NULL OR pay_date = '' THEN 'pay_date_empty'
      WHEN pay_amount IS NULL THEN 'pay_amount_null'
      WHEN pay_amount < 0 THEN 'pay_amount_negative'
      WHEN pay_status IS NULL OR pay_status <> 'SUCCESS' THEN 'pay_status_not_success'
      ELSE 'unknown_dirty'
    END AS dirty_reason
  FROM normalized
  WHERE payment_id IS NULL
    OR payment_id = ''
    OR order_id IS NULL
    OR order_id = ''
    OR user_id IS NULL
    OR user_id = ''
    OR pay_date IS NULL
    OR pay_date = ''
    OR pay_amount IS NULL
    OR pay_amount < 0
    OR pay_status IS NULL
    OR pay_status <> 'SUCCESS'
),
valid_rows AS (
  SELECT
    payment_id,
    order_id,
    user_id,
    pay_date,
    pay_amount,
    pay_status
  FROM normalized
  WHERE payment_id IS NOT NULL
    AND payment_id <> ''
    AND order_id IS NOT NULL
    AND order_id <> ''
    AND user_id IS NOT NULL
    AND user_id <> ''
    AND pay_date IS NOT NULL
    AND pay_date <> ''
    AND pay_amount IS NOT NULL
    AND pay_amount >= 0
    AND pay_status = 'SUCCESS'
),
ranked_valid_rows AS (
  SELECT
    payment_id,
    order_id,
    user_id,
    pay_date,
    pay_amount,
    pay_status,
    ROW_NUMBER() OVER (
      PARTITION BY payment_id
      ORDER BY pay_date DESC, order_id ASC, pay_amount DESC
    ) AS rn
  FROM valid_rows
),
duplicate_rows AS (
  SELECT
    payment_id,
    order_id,
    user_id,
    pay_date,
    pay_amount,
    pay_status,
    'duplicate_payment_id' AS dirty_reason
  FROM ranked_valid_rows
  WHERE rn > 1
)
INSERT OVERWRITE TABLE dwd_payment_dirty_di PARTITION (dt='__RUN_DT__')
SELECT
  payment_id,
  order_id,
  user_id,
  pay_date,
  pay_amount,
  pay_status,
  dirty_reason
FROM invalid_rows
UNION ALL
SELECT
  payment_id,
  order_id,
  user_id,
  pay_date,
  pay_amount,
  pay_status,
  dirty_reason
FROM duplicate_rows;
