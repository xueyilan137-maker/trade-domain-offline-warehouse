USE hive_demo;

WITH normalized AS (
  SELECT
    TRIM(payment_id) AS payment_id,
    TRIM(order_id) AS order_id,
    TRIM(user_id) AS user_id,
    TRIM(pay_date) AS pay_date,
    CAST(pay_amount AS DECIMAL(10,2)) AS pay_amount,
    UPPER(TRIM(pay_status)) AS pay_status
  FROM dwd_payment_p
  WHERE dt = '__RUN_DT__'
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
deduped AS (
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
)
INSERT OVERWRITE TABLE dwd_payment_clean_di PARTITION (dt='__RUN_DT__')
SELECT
  payment_id,
  order_id,
  user_id,
  pay_date,
  pay_amount,
  pay_status
FROM deduped
WHERE rn = 1;
