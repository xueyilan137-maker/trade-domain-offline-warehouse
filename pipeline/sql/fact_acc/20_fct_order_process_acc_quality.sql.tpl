USE hive_demo;

SELECT 'fct_order_process_acc row count check failed' AS err_msg
WHERE (
  SELECT COUNT(*)
  FROM fct_order_process_acc
) = 0;

SELECT 'fct_order_process_acc duplicate order check failed' AS err_msg
WHERE EXISTS (
  SELECT order_id
  FROM fct_order_process_acc
  GROUP BY order_id
  HAVING COUNT(*) > 1
);

SELECT 'fct_order_process_acc null key check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM fct_order_process_acc
  WHERE order_id IS NULL
     OR TRIM(order_id) = ''
     OR user_id IS NULL
     OR TRIM(user_id) = ''
);
