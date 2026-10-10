USE hive_demo;

SELECT 'fct_order_refund_status_di row count check failed' AS err_msg
WHERE (
  SELECT COUNT(*)
  FROM fct_order_refund_status_di
  WHERE dt = '__RUN_DT__'
) = 0;

SELECT 'fct_order_refund_status_di duplicate order check failed' AS err_msg
WHERE EXISTS (
  SELECT order_id
  FROM fct_order_refund_status_di
  WHERE dt = '__RUN_DT__'
  GROUP BY order_id
  HAVING COUNT(*) > 1
);

SELECT 'fct_order_refund_status_di invalid refund flag check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM fct_order_refund_status_di
  WHERE dt = '__RUN_DT__'
    AND (
      is_refunded NOT IN (0, 1)
      OR (is_refunded = 0 AND refund_amount <> 0)
      OR (is_refunded = 1 AND refund_amount <= 0)
      OR (is_refunded = 1 AND (refund_date IS NULL OR TRIM(refund_date) = ''))
    )
);

SELECT 'fct_order_refund_status_di net amount check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM fct_order_refund_status_di
  WHERE dt = '__RUN_DT__'
    AND (
      net_amount < 0
      OR (order_status = 'CANCELLED' AND net_amount <> 0)
      OR (order_status = 'VALID' AND net_amount <> amount - refund_amount)
      OR (order_status = 'VALID' AND refund_amount > amount)
    )
);

WITH status_fact AS (
  SELECT COUNT(*) AS row_cnt
  FROM fct_order_status_di
  WHERE dt = '__RUN_DT__'
),
refund_status_fact AS (
  SELECT COUNT(*) AS row_cnt
  FROM fct_order_refund_status_di
  WHERE dt = '__RUN_DT__'
)
SELECT 'fct_order_refund_status_di status row count reconcile check failed' AS err_msg
FROM status_fact
CROSS JOIN refund_status_fact
WHERE status_fact.row_cnt <> refund_status_fact.row_cnt;

WITH refund_dwd AS (
  SELECT COUNT(*) AS row_cnt
  FROM dwd_order_refund_clean_di r
  INNER JOIN fct_order_status_di s
    ON r.order_id = s.order_id
   AND s.dt <= r.dt
  WHERE s.dt = '__RUN_DT__'
),
refund_status AS (
  SELECT COUNT(*) AS row_cnt
  FROM fct_order_refund_status_di
  WHERE dt = '__RUN_DT__'
    AND is_refunded = 1
)
SELECT 'fct_order_refund_status_di refund row count reconcile check failed' AS err_msg
FROM refund_dwd
CROSS JOIN refund_status
WHERE refund_dwd.row_cnt <> refund_status.row_cnt;
