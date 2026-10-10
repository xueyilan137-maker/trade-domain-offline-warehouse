USE hive_demo;

SELECT 'ads_trade_multi_theme_day_overview row count check failed' AS err_msg
WHERE (
  SELECT COUNT(*)
  FROM ads_trade_multi_theme_day_overview
  WHERE dt = '__RUN_DT__'
) = 0;

SELECT 'ads_trade_multi_theme_day_overview duplicate dimension check failed' AS err_msg
WHERE EXISTS (
  SELECT theme_name, dimension_name, dimension_value, dimension_type
  FROM ads_trade_multi_theme_day_overview
  WHERE dt = '__RUN_DT__'
  GROUP BY theme_name, dimension_name, dimension_value, dimension_type
  HAVING COUNT(*) > 1
);

SELECT 'ads_trade_multi_theme_day_overview negative metric check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM ads_trade_multi_theme_day_overview
  WHERE dt = '__RUN_DT__'
    AND (
      COALESCE(trade_user_cnt, 0) < 0
      OR COALESCE(raw_order_cnt, 0) < 0
      OR COALESCE(valid_order_cnt, 0) < 0
      OR COALESCE(cancel_order_cnt, 0) < 0
      OR COALESCE(item_cnt, 0) < 0
      OR COALESCE(raw_amount, 0) < 0
      OR COALESCE(valid_amount, 0) < 0
      OR COALESCE(cancel_amount, 0) < 0
      OR COALESCE(refund_amount, 0) < 0
      OR COALESCE(net_amount, 0) < 0
    )
);

SELECT 'ads_trade_multi_theme_day_overview rate range check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM ads_trade_multi_theme_day_overview
  WHERE dt = '__RUN_DT__'
    AND (
      cancel_rate < 0
      OR cancel_rate > 1
      OR refund_rate < 0
      OR refund_rate > 1
    )
);

SELECT 'ads_trade_multi_theme_day_overview source row count reconcile failed' AS err_msg
WHERE (
  SELECT COUNT(*)
  FROM ads_trade_multi_theme_day_overview
  WHERE dt = '__RUN_DT__'
) <> (
  SELECT
    (
      SELECT COUNT(*)
      FROM ads_user_level_trade_day_overview
      WHERE dt = '__RUN_DT__'
    )
    + (
      SELECT COUNT(*)
      FROM ads_category_trade_day_overview
      WHERE dt = '__RUN_DT__'
    )
    + (
      SELECT COUNT(*)
      FROM ads_channel_trade_day_overview
      WHERE dt = '__RUN_DT__'
    )
);
