USE hive_demo;

WITH normalized AS (
  SELECT
    TRIM(order_id) AS order_id,
    TRIM(user_id) AS user_id,
    TRIM(refund_date) AS refund_date,
    refund_amount,
    TRIM(refund_reason) AS refund_reason
  FROM dwd_order_refund_p
  WHERE dt = '__RUN_DT__'
),
valid_rows AS (
  SELECT
    order_id,
    user_id,
    refund_date,
    refund_amount,
    COALESCE(NULLIF(refund_reason, ''), 'unknown') AS refund_reason
  FROM normalized
  WHERE order_id IS NOT NULL
    AND order_id <> ''
    AND user_id IS NOT NULL
    AND user_id <> ''
    AND refund_date IS NOT NULL
    AND refund_date <> ''
    AND refund_amount IS NOT NULL
    AND refund_amount > 0
),
deduped AS (
  SELECT
    order_id,
    user_id,
    refund_date,
    refund_amount,
    refund_reason,
    ROW_NUMBER() OVER (
      PARTITION BY order_id
      ORDER BY refund_date DESC, refund_amount DESC, user_id ASC, refund_reason ASC
    ) AS rn
  FROM valid_rows
)
INSERT OVERWRITE TABLE dwd_order_refund_clean_di PARTITION (dt='__RUN_DT__')
SELECT
  order_id,
  user_id,
  refund_date,
  refund_amount,
  refund_reason
FROM deduped
WHERE rn = 1;
