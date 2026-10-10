USE hive_demo;

SELECT 'ads_order_status_day_overview row count check failed' AS err_msg
WHERE (
  SELECT COUNT(*)
  FROM ads_order_status_day_overview
  WHERE dt = '__RUN_DT__'
) <> 1;

SELECT 'ads_order_status_day_overview negative metric check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM ads_order_status_day_overview
  WHERE dt = '__RUN_DT__'
    AND (
      raw_order_users < 0
      OR raw_order_cnt < 0
      OR raw_gmv < 0
      OR valid_order_users < 0
      OR valid_order_cnt < 0
      OR valid_gmv < 0
      OR cancel_order_users < 0
      OR cancel_order_cnt < 0
      OR cancel_amount < 0
    )
);

SELECT 'ads_order_status_day_overview rate range check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM ads_order_status_day_overview
  WHERE dt = '__RUN_DT__'
    AND (
      valid_order_rate < 0
      OR valid_order_rate > 1
      OR cancel_order_rate < 0
      OR cancel_order_rate > 1
    )
);

SELECT 'ads_order_status_day_overview raw count split check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM ads_order_status_day_overview
  WHERE dt = '__RUN_DT__'
    AND raw_order_cnt <> valid_order_cnt + cancel_order_cnt
);

SELECT 'ads_order_status_day_overview raw gmv split check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM ads_order_status_day_overview
  WHERE dt = '__RUN_DT__'
    AND raw_gmv <> valid_gmv + cancel_amount
);
