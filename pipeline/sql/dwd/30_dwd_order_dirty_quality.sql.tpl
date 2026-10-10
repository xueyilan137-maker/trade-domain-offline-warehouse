USE hive_demo;

SELECT 'dwd_order_dirty_di dirty reason check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM dwd_order_dirty_di
  WHERE dt = '__RUN_DT__'
    AND (
      dirty_reason IS NULL
      OR TRIM(dirty_reason) = ''
    )
);

WITH normalized AS (
  SELECT
    TRIM(order_id) AS order_id,
    TRIM(user_id) AS user_id,
    TRIM(order_date) AS order_date,
    CAST(amount AS DECIMAL(10,2)) AS amount
  FROM dwd_order_p
  WHERE dt = '__RUN_DT__'
),
invalid_stats AS (
  SELECT COUNT(*) AS invalid_cnt
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
valid_stats AS (
  SELECT
    COUNT(*) AS valid_row_cnt,
    COUNT(DISTINCT order_id) AS valid_order_cnt
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
dirty_stats AS (
  SELECT COUNT(*) AS dirty_cnt
  FROM dwd_order_dirty_di
  WHERE dt = '__RUN_DT__'
)
SELECT 'dwd_order_dirty_di source dirty row count reconcile check failed' AS err_msg
FROM invalid_stats
CROSS JOIN valid_stats
CROSS JOIN dirty_stats
WHERE invalid_stats.invalid_cnt + (valid_stats.valid_row_cnt - valid_stats.valid_order_cnt) <> dirty_stats.dirty_cnt;
