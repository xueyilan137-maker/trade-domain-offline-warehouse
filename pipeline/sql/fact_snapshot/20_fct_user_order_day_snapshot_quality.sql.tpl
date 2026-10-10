USE hive_demo;

SELECT 'fct_user_order_day_snapshot row count check failed' AS err_msg
WHERE (
  SELECT COUNT(*)
  FROM fct_user_order_day_snapshot
  WHERE dt = '__RUN_DT__'
) = 0;

SELECT 'fct_user_order_day_snapshot duplicate user check failed' AS err_msg
WHERE EXISTS (
  SELECT user_id
  FROM fct_user_order_day_snapshot
  WHERE dt = '__RUN_DT__'
  GROUP BY user_id
  HAVING COUNT(*) > 1
);

SELECT 'fct_user_order_day_snapshot null key check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM fct_user_order_day_snapshot
  WHERE dt = '__RUN_DT__'
    AND (
      user_id IS NULL
      OR TRIM(user_id) = ''
    )
);

SELECT 'fct_user_order_day_snapshot negative metric check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM fct_user_order_day_snapshot
  WHERE dt = '__RUN_DT__'
    AND (
      order_cnt < 0
      OR order_amount < 0
    )
);
