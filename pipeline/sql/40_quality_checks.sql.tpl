USE hive_demo;

SELECT 'dwd_order_p count check failed' AS err_msg
WHERE (
  SELECT COUNT(*)
  FROM dwd_order_p
  WHERE dt = '__RUN_DT__'
) = 0;

SELECT 'dwd_event_p count check failed' AS err_msg
WHERE (
  SELECT COUNT(*)
  FROM dwd_event_p
  WHERE dt = '__RUN_DT__'
) = 0;

SELECT 'dwd_order_p primary key null check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM dwd_order_p
  WHERE dt = '__RUN_DT__'
    AND (
      order_id IS NULL
      OR TRIM(order_id) = ''
      OR user_id IS NULL
      OR TRIM(user_id) = ''
    )
);

SELECT 'dwd_order_p negative amount check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM dwd_order_p
  WHERE dt = '__RUN_DT__'
    AND amount < 0
);

SELECT 'ads_daily_overview_dp row count check failed' AS err_msg
WHERE (
  SELECT COUNT(*)
  FROM ads_daily_overview_dp
  WHERE dt = '__RUN_DT__'
) <> 1;
