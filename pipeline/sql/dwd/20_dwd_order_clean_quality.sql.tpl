USE hive_demo;

SELECT 'dwd_order_clean_di row count check failed' AS err_msg
WHERE (
  SELECT COUNT(*)
  FROM dwd_order_clean_di
  WHERE dt = '__RUN_DT__'
) = 0;

SELECT 'dwd_order_clean_di duplicate order check failed' AS err_msg
WHERE EXISTS (
  SELECT order_id
  FROM dwd_order_clean_di
  WHERE dt = '__RUN_DT__'
  GROUP BY order_id
  HAVING COUNT(*) > 1
);

SELECT 'dwd_order_clean_di null key check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM dwd_order_clean_di
  WHERE dt = '__RUN_DT__'
    AND (
      order_id IS NULL
      OR TRIM(order_id) = ''
      OR user_id IS NULL
      OR TRIM(user_id) = ''
      OR order_date IS NULL
      OR TRIM(order_date) = ''
    )
);

SELECT 'dwd_order_clean_di negative amount check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM dwd_order_clean_di
  WHERE dt = '__RUN_DT__'
    AND amount < 0
);

WITH src_valid AS (
  SELECT COUNT(DISTINCT TRIM(order_id)) AS valid_order_cnt
  FROM dwd_order_p
  WHERE dt = '__RUN_DT__'
    AND order_id IS NOT NULL
    AND TRIM(order_id) <> ''
    AND user_id IS NOT NULL
    AND TRIM(user_id) <> ''
    AND order_date IS NOT NULL
    AND TRIM(order_date) <> ''
    AND amount IS NOT NULL
    AND amount >= 0
),
clean AS (
  SELECT COUNT(*) AS row_cnt
  FROM dwd_order_clean_di
  WHERE dt = '__RUN_DT__'
)
SELECT 'dwd_order_clean_di valid source row count reconcile check failed' AS err_msg
FROM src_valid
CROSS JOIN clean
WHERE src_valid.valid_order_cnt <> clean.row_cnt;

