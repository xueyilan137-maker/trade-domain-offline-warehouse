USE hive_demo;

SELECT 'dwd_order_refund_clean_di duplicate order check failed' AS err_msg
WHERE EXISTS (
  SELECT order_id
  FROM dwd_order_refund_clean_di
  WHERE dt = '__RUN_DT__'
  GROUP BY order_id
  HAVING COUNT(*) > 1
);

SELECT 'dwd_order_refund_clean_di null key check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM dwd_order_refund_clean_di
  WHERE dt = '__RUN_DT__'
    AND (
      order_id IS NULL
      OR TRIM(order_id) = ''
      OR user_id IS NULL
      OR TRIM(user_id) = ''
      OR refund_date IS NULL
      OR TRIM(refund_date) = ''
      OR refund_amount IS NULL
    )
);

SELECT 'dwd_order_refund_clean_di refund amount check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM dwd_order_refund_clean_di
  WHERE dt = '__RUN_DT__'
    AND refund_amount <= 0
);

SELECT 'dwd_order_refund_clean_di unmatched order check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM dwd_order_refund_clean_di r
  LEFT JOIN dwd_order_clean_di o
    ON r.order_id = o.order_id
   AND o.dt <= r.dt
  WHERE r.dt = '__RUN_DT__'
    AND o.order_id IS NULL
);
