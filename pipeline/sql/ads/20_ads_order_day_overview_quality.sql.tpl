USE hive_demo;

SELECT 'ads_order_day_overview row count check failed' AS err_msg
WHERE (
  SELECT COUNT(*)
  FROM ads_order_day_overview
  WHERE dt = '__RUN_DT__'
) <> 1;

SELECT 'ads_order_day_overview negative metric check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM ads_order_day_overview
  WHERE dt = '__RUN_DT__'
    AND (
      order_users < 0
      OR order_cnt < 0
      OR gmv < 0
      OR avg_order_amount < 0
    )
);

SELECT 'ads_order_day_overview empty upstream check failed' AS err_msg
WHERE (
  SELECT COUNT(*)
  FROM dws_user_order_day_agg
  WHERE dt = '__RUN_DT__'
) = 0;
