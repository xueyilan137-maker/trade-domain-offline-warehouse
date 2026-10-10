USE hive_demo;

SELECT 'dwd_payment_clean_di row count check failed' AS err_msg
WHERE (
  SELECT COUNT(*)
  FROM dwd_payment_clean_di
  WHERE dt = '__RUN_DT__'
) = 0;

SELECT 'dwd_payment_clean_di duplicate payment check failed' AS err_msg
WHERE EXISTS (
  SELECT payment_id
  FROM dwd_payment_clean_di
  WHERE dt = '__RUN_DT__'
  GROUP BY payment_id
  HAVING COUNT(*) > 1
);

SELECT 'dwd_payment_clean_di null key check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM dwd_payment_clean_di
  WHERE dt = '__RUN_DT__'
    AND (
      payment_id IS NULL
      OR TRIM(payment_id) = ''
      OR order_id IS NULL
      OR TRIM(order_id) = ''
      OR user_id IS NULL
      OR TRIM(user_id) = ''
      OR pay_date IS NULL
      OR TRIM(pay_date) = ''
    )
);

SELECT 'dwd_payment_clean_di invalid amount check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM dwd_payment_clean_di
  WHERE dt = '__RUN_DT__'
    AND (
      pay_amount IS NULL
      OR pay_amount < 0
    )
);

SELECT 'dwd_payment_clean_di pay status check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM dwd_payment_clean_di
  WHERE dt = '__RUN_DT__'
    AND pay_status <> 'SUCCESS'
);

SELECT 'dwd_payment_dirty_di dirty reason check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM dwd_payment_dirty_di
  WHERE dt = '__RUN_DT__'
    AND (
      dirty_reason IS NULL
      OR TRIM(dirty_reason) = ''
    )
);

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
invalid_stats AS (
  SELECT COUNT(*) AS invalid_cnt
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
valid_stats AS (
  SELECT
    COUNT(*) AS valid_row_cnt,
    COUNT(DISTINCT payment_id) AS valid_payment_cnt
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
clean_stats AS (
  SELECT COUNT(*) AS clean_cnt
  FROM dwd_payment_clean_di
  WHERE dt = '__RUN_DT__'
),
dirty_stats AS (
  SELECT COUNT(*) AS dirty_cnt
  FROM dwd_payment_dirty_di
  WHERE dt = '__RUN_DT__'
)
SELECT 'dwd_payment clean dirty row count reconcile check failed' AS err_msg
FROM invalid_stats
CROSS JOIN valid_stats
CROSS JOIN clean_stats
CROSS JOIN dirty_stats
WHERE valid_stats.valid_payment_cnt <> clean_stats.clean_cnt
   OR invalid_stats.invalid_cnt + (valid_stats.valid_row_cnt - valid_stats.valid_payment_cnt) <> dirty_stats.dirty_cnt;
