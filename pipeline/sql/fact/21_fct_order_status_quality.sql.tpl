USE hive_demo;

SELECT 'fct_order_status_di row count check failed' AS err_msg
WHERE (
  SELECT COUNT(*)
  FROM fct_order_status_di
  WHERE dt = '__RUN_DT__'
) = 0;

SELECT 'fct_order_status_di duplicate order check failed' AS err_msg
WHERE EXISTS (
  SELECT order_id
  FROM fct_order_status_di
  WHERE dt = '__RUN_DT__'
  GROUP BY order_id
  HAVING COUNT(*) > 1
);

SELECT 'fct_order_status_di invalid status check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM fct_order_status_di
  WHERE dt = '__RUN_DT__'
    AND (
      order_status NOT IN ('VALID', 'CANCELLED')
      OR is_cancelled NOT IN (0, 1)
      OR (order_status = 'VALID' AND is_cancelled <> 0)
      OR (order_status = 'CANCELLED' AND is_cancelled <> 1)
    )
);

SELECT 'fct_order_status_di cancelled info check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM fct_order_status_di
  WHERE dt = '__RUN_DT__'
    AND order_status = 'CANCELLED'
    AND (
      cancel_date IS NULL
      OR TRIM(cancel_date) = ''
      OR cancel_reason IS NULL
      OR TRIM(cancel_reason) = ''
    )
);

WITH order_fact AS (
  SELECT COUNT(*) AS row_cnt
  FROM fct_order_di
  WHERE dt = '__RUN_DT__'
),
status_fact AS (
  SELECT COUNT(*) AS row_cnt
  FROM fct_order_status_di
  WHERE dt = '__RUN_DT__'
)
SELECT 'fct_order_status_di fct row count reconcile check failed' AS err_msg
FROM order_fact
CROSS JOIN status_fact
WHERE order_fact.row_cnt <> status_fact.row_cnt;

WITH cancel_dwd AS (
  SELECT COUNT(*) AS row_cnt
  FROM dwd_order_cancel_clean_di
  WHERE dt = '__RUN_DT__'
),
cancel_status AS (
  SELECT COUNT(*) AS row_cnt
  FROM fct_order_status_di
  WHERE dt = '__RUN_DT__'
    AND order_status = 'CANCELLED'
)
SELECT 'fct_order_status_di cancel row count reconcile check failed' AS err_msg
FROM cancel_dwd
CROSS JOIN cancel_status
WHERE cancel_dwd.row_cnt <> cancel_status.row_cnt;
