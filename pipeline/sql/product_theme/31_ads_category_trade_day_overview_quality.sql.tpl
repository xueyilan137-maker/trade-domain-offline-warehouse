USE hive_demo;

SELECT 'ads_category_trade_day_overview row count check failed' AS err_msg
WHERE (
  SELECT COUNT(*)
  FROM ads_category_trade_day_overview
  WHERE dt = '__RUN_DT__'
) = 0;

SELECT 'ads_category_trade_day_overview duplicate category check failed' AS err_msg
WHERE EXISTS (
  SELECT category_name
  FROM ads_category_trade_day_overview
  WHERE dt = '__RUN_DT__'
  GROUP BY category_name
  HAVING COUNT(*) > 1
);

SELECT 'ads_category_trade_day_overview negative metric check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM ads_category_trade_day_overview
  WHERE dt = '__RUN_DT__'
    AND (
      raw_order_cnt < 0
      OR trade_user_cnt < 0
      OR item_cnt < 0
      OR raw_item_amount < 0
      OR valid_item_amount < 0
      OR cancel_item_amount < 0
      OR refund_amount < 0
      OR net_item_amount < 0
    )
);

SELECT 'ads_category_trade_day_overview rate range check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM ads_category_trade_day_overview
  WHERE dt = '__RUN_DT__'
    AND (
      refund_amount_rate < 0
      OR refund_amount_rate > 1
    )
);

SELECT 'ads_category_trade_day_overview amount split check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM ads_category_trade_day_overview
  WHERE dt = '__RUN_DT__'
    AND raw_item_amount <> valid_item_amount + cancel_item_amount
);

SELECT 'ads_category_trade_day_overview net amount check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM ads_category_trade_day_overview
  WHERE dt = '__RUN_DT__'
    AND net_item_amount <> valid_item_amount - refund_amount
);
