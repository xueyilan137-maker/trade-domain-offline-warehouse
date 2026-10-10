USE hive_demo;

SELECT 'ads_order_refund_day_overview row count check failed' AS err_msg
WHERE (
  SELECT COUNT(*)
  FROM ads_order_refund_day_overview
  WHERE dt = '__RUN_DT__'
) <> 1;

SELECT 'ads_order_refund_day_overview negative metric check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM ads_order_refund_day_overview
  WHERE dt = '__RUN_DT__'
    AND (
      raw_order_cnt < 0
      OR valid_order_cnt < 0
      OR cancel_order_cnt < 0
      OR gross_valid_gmv < 0
      OR refund_order_cnt < 0
      OR refund_amount < 0
      OR net_gmv < 0
    )
);

SELECT 'ads_order_refund_day_overview rate range check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM ads_order_refund_day_overview
  WHERE dt = '__RUN_DT__'
    AND (
      refund_order_rate < 0
      OR refund_order_rate > 1
      OR refund_gmv_rate < 0
      OR refund_gmv_rate > 1
    )
);

SELECT 'ads_order_refund_day_overview count split check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM ads_order_refund_day_overview
  WHERE dt = '__RUN_DT__'
    AND raw_order_cnt <> valid_order_cnt + cancel_order_cnt
);

SELECT 'ads_order_refund_day_overview net gmv check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM ads_order_refund_day_overview
  WHERE dt = '__RUN_DT__'
    AND net_gmv <> gross_valid_gmv - refund_amount
);
