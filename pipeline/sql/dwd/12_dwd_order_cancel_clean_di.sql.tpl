USE hive_demo;

WITH normalized AS (
  SELECT
    TRIM(order_id) AS order_id,
    TRIM(user_id) AS user_id,
    TRIM(cancel_date) AS cancel_date,
    TRIM(cancel_reason) AS cancel_reason
  FROM dwd_order_cancel_p
  WHERE dt = '__RUN_DT__'
),
valid_rows AS (
  SELECT
    order_id,
    user_id,
    cancel_date,
    COALESCE(NULLIF(cancel_reason, ''), 'unknown') AS cancel_reason
  FROM normalized
  WHERE order_id IS NOT NULL
    AND order_id <> ''
    AND user_id IS NOT NULL
    AND user_id <> ''
    AND cancel_date IS NOT NULL
    AND cancel_date <> ''
),
deduped AS (
  SELECT
    order_id,
    user_id,
    cancel_date,
    cancel_reason,
    ROW_NUMBER() OVER (
      PARTITION BY order_id
      ORDER BY cancel_date DESC, user_id ASC, cancel_reason ASC
    ) AS rn
  FROM valid_rows
)
INSERT OVERWRITE TABLE dwd_order_cancel_clean_di PARTITION (dt='__RUN_DT__')
SELECT
  order_id,
  user_id,
  cancel_date,
  cancel_reason
FROM deduped
WHERE rn = 1;
