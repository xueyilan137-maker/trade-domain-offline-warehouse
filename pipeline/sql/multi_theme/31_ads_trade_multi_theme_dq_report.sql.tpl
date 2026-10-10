USE hive_demo;

WITH
multi_stats AS (
  SELECT
    COUNT(*) AS row_cnt,
    SUM(CASE WHEN theme_name = 'user_theme' THEN 1 ELSE 0 END) AS user_theme_row_cnt,
    SUM(CASE WHEN theme_name = 'product_theme' THEN 1 ELSE 0 END) AS product_theme_row_cnt,
    SUM(CASE WHEN theme_name = 'channel_theme' THEN 1 ELSE 0 END) AS channel_theme_row_cnt,
    SUM(CASE
      WHEN COALESCE(trade_user_cnt, 0) < 0
        OR COALESCE(raw_order_cnt, 0) < 0
        OR COALESCE(valid_order_cnt, 0) < 0
        OR COALESCE(cancel_order_cnt, 0) < 0
        OR COALESCE(item_cnt, 0) < 0
        OR COALESCE(raw_amount, 0) < 0
        OR COALESCE(valid_amount, 0) < 0
        OR COALESCE(cancel_amount, 0) < 0
        OR COALESCE(refund_amount, 0) < 0
        OR COALESCE(net_amount, 0) < 0
      THEN 1 ELSE 0 END
    ) AS negative_metric_cnt,
    SUM(CASE
      WHEN cancel_rate < 0
        OR cancel_rate > 1
        OR refund_rate < 0
        OR refund_rate > 1
      THEN 1 ELSE 0 END
    ) AS invalid_rate_cnt
  FROM ads_trade_multi_theme_day_overview
  WHERE dt = '__RUN_DT__'
),
duplicate_stats AS (
  SELECT COUNT(*) AS duplicate_cnt
  FROM (
    SELECT theme_name, dimension_name, dimension_value, dimension_type
    FROM ads_trade_multi_theme_day_overview
    WHERE dt = '__RUN_DT__'
    GROUP BY theme_name, dimension_name, dimension_value, dimension_type
    HAVING COUNT(*) > 1
  ) t
),
source_row_stats AS (
  SELECT
    (
      SELECT COUNT(*)
      FROM ads_user_level_trade_day_overview
      WHERE dt = '__RUN_DT__'
    ) AS user_source_row_cnt,
    (
      SELECT COUNT(*)
      FROM ads_category_trade_day_overview
      WHERE dt = '__RUN_DT__'
    ) AS product_source_row_cnt,
    (
      SELECT COUNT(*)
      FROM ads_channel_trade_day_overview
      WHERE dt = '__RUN_DT__'
    ) AS channel_source_row_cnt
),
multi_amount_stats AS (
  SELECT
    theme_name,
    CAST(SUM(COALESCE(valid_amount, 0)) AS DECIMAL(10,2)) AS valid_amount,
    CAST(SUM(COALESCE(cancel_amount, 0)) AS DECIMAL(10,2)) AS cancel_amount,
    CAST(SUM(COALESCE(refund_amount, 0)) AS DECIMAL(10,2)) AS refund_amount,
    CAST(SUM(COALESCE(net_amount, 0)) AS DECIMAL(10,2)) AS net_amount
  FROM ads_trade_multi_theme_day_overview
  WHERE dt = '__RUN_DT__'
  GROUP BY theme_name
),
user_source_amount_stats AS (
  SELECT
    CAST(SUM(gross_valid_gmv) AS DECIMAL(10,2)) AS valid_amount,
    CAST(SUM(refund_amount) AS DECIMAL(10,2)) AS refund_amount,
    CAST(SUM(net_gmv) AS DECIMAL(10,2)) AS net_amount
  FROM ads_user_level_trade_day_overview
  WHERE dt = '__RUN_DT__'
),
product_source_amount_stats AS (
  SELECT
    CAST(SUM(valid_item_amount) AS DECIMAL(10,2)) AS valid_amount,
    CAST(SUM(cancel_item_amount) AS DECIMAL(10,2)) AS cancel_amount,
    CAST(SUM(refund_amount) AS DECIMAL(10,2)) AS refund_amount,
    CAST(SUM(net_item_amount) AS DECIMAL(10,2)) AS net_amount
  FROM ads_category_trade_day_overview
  WHERE dt = '__RUN_DT__'
),
channel_source_amount_stats AS (
  SELECT
    CAST(SUM(gross_valid_gmv) AS DECIMAL(10,2)) AS valid_amount,
    CAST(SUM(cancel_amount) AS DECIMAL(10,2)) AS cancel_amount,
    CAST(SUM(refund_amount) AS DECIMAL(10,2)) AS refund_amount,
    CAST(SUM(net_gmv) AS DECIMAL(10,2)) AS net_amount
  FROM ads_channel_trade_day_overview
  WHERE dt = '__RUN_DT__'
),
checks AS (
  SELECT
    'multi_theme_trade_pipeline' AS pipeline_name,
    'ADS' AS layer_name,
    'ads_trade_multi_theme_day_overview' AS table_name,
    'row_count_positive' AS check_name,
    CASE WHEN row_cnt > 0 THEN 'PASS' ELSE 'FAIL' END AS check_status,
    CONCAT('row_cnt=', row_cnt) AS err_msg
  FROM multi_stats

  UNION ALL

  SELECT
    'multi_theme_trade_pipeline',
    'ADS',
    'ads_trade_multi_theme_day_overview',
    'source_row_count_reconcile',
    CASE
      WHEN m.row_cnt = s.user_source_row_cnt + s.product_source_row_cnt + s.channel_source_row_cnt THEN 'PASS'
      ELSE 'FAIL'
    END,
    CONCAT(
      'multi_row_cnt=', m.row_cnt,
      ', source_row_cnt=', s.user_source_row_cnt + s.product_source_row_cnt + s.channel_source_row_cnt
    )
  FROM multi_stats m
  CROSS JOIN source_row_stats s

  UNION ALL

  SELECT
    'multi_theme_trade_pipeline',
    'ADS',
    'ads_trade_multi_theme_day_overview',
    'theme_row_count_reconcile',
    CASE
      WHEN m.user_theme_row_cnt = s.user_source_row_cnt
        AND m.product_theme_row_cnt = s.product_source_row_cnt
        AND m.channel_theme_row_cnt = s.channel_source_row_cnt
      THEN 'PASS'
      ELSE 'FAIL'
    END,
    CONCAT(
      'multi_user=', m.user_theme_row_cnt, ', source_user=', s.user_source_row_cnt,
      ', multi_product=', m.product_theme_row_cnt, ', source_product=', s.product_source_row_cnt,
      ', multi_channel=', m.channel_theme_row_cnt, ', source_channel=', s.channel_source_row_cnt
    )
  FROM multi_stats m
  CROSS JOIN source_row_stats s

  UNION ALL

  SELECT
    'multi_theme_trade_pipeline',
    'ADS',
    'ads_trade_multi_theme_day_overview',
    'dimension_unique',
    CASE WHEN duplicate_cnt = 0 THEN 'PASS' ELSE 'FAIL' END,
    CONCAT('duplicate_cnt=', duplicate_cnt)
  FROM duplicate_stats

  UNION ALL

  SELECT
    'multi_theme_trade_pipeline',
    'ADS',
    'ads_trade_multi_theme_day_overview',
    'metric_non_negative',
    CASE WHEN negative_metric_cnt = 0 THEN 'PASS' ELSE 'FAIL' END,
    CONCAT('negative_metric_cnt=', negative_metric_cnt)
  FROM multi_stats

  UNION ALL

  SELECT
    'multi_theme_trade_pipeline',
    'ADS',
    'ads_trade_multi_theme_day_overview',
    'rate_range_valid',
    CASE WHEN invalid_rate_cnt = 0 THEN 'PASS' ELSE 'FAIL' END,
    CONCAT('invalid_rate_cnt=', invalid_rate_cnt)
  FROM multi_stats

  UNION ALL

  SELECT
    'multi_theme_trade_pipeline',
    'ADS',
    'ads_trade_multi_theme_day_overview',
    'user_theme_amount_reconcile',
    CASE
      WHEN COALESCE(m.valid_amount, 0) = COALESCE(s.valid_amount, 0)
        AND COALESCE(m.refund_amount, 0) = COALESCE(s.refund_amount, 0)
        AND COALESCE(m.net_amount, 0) = COALESCE(s.net_amount, 0)
      THEN 'PASS'
      ELSE 'FAIL'
    END,
    CONCAT(
      'multi_valid=', COALESCE(m.valid_amount, 0), ', source_valid=', COALESCE(s.valid_amount, 0),
      ', multi_refund=', COALESCE(m.refund_amount, 0), ', source_refund=', COALESCE(s.refund_amount, 0),
      ', multi_net=', COALESCE(m.net_amount, 0), ', source_net=', COALESCE(s.net_amount, 0)
    )
  FROM user_source_amount_stats s
  LEFT JOIN multi_amount_stats m
    ON m.theme_name = 'user_theme'

  UNION ALL

  SELECT
    'multi_theme_trade_pipeline',
    'ADS',
    'ads_trade_multi_theme_day_overview',
    'product_theme_amount_reconcile',
    CASE
      WHEN COALESCE(m.valid_amount, 0) = COALESCE(s.valid_amount, 0)
        AND COALESCE(m.cancel_amount, 0) = COALESCE(s.cancel_amount, 0)
        AND COALESCE(m.refund_amount, 0) = COALESCE(s.refund_amount, 0)
        AND COALESCE(m.net_amount, 0) = COALESCE(s.net_amount, 0)
      THEN 'PASS'
      ELSE 'FAIL'
    END,
    CONCAT(
      'multi_valid=', COALESCE(m.valid_amount, 0), ', source_valid=', COALESCE(s.valid_amount, 0),
      ', multi_cancel=', COALESCE(m.cancel_amount, 0), ', source_cancel=', COALESCE(s.cancel_amount, 0),
      ', multi_refund=', COALESCE(m.refund_amount, 0), ', source_refund=', COALESCE(s.refund_amount, 0),
      ', multi_net=', COALESCE(m.net_amount, 0), ', source_net=', COALESCE(s.net_amount, 0)
    )
  FROM product_source_amount_stats s
  LEFT JOIN multi_amount_stats m
    ON m.theme_name = 'product_theme'

  UNION ALL

  SELECT
    'multi_theme_trade_pipeline',
    'ADS',
    'ads_trade_multi_theme_day_overview',
    'channel_theme_amount_reconcile',
    CASE
      WHEN COALESCE(m.valid_amount, 0) = COALESCE(s.valid_amount, 0)
        AND COALESCE(m.cancel_amount, 0) = COALESCE(s.cancel_amount, 0)
        AND COALESCE(m.refund_amount, 0) = COALESCE(s.refund_amount, 0)
        AND COALESCE(m.net_amount, 0) = COALESCE(s.net_amount, 0)
      THEN 'PASS'
      ELSE 'FAIL'
    END,
    CONCAT(
      'multi_valid=', COALESCE(m.valid_amount, 0), ', source_valid=', COALESCE(s.valid_amount, 0),
      ', multi_cancel=', COALESCE(m.cancel_amount, 0), ', source_cancel=', COALESCE(s.cancel_amount, 0),
      ', multi_refund=', COALESCE(m.refund_amount, 0), ', source_refund=', COALESCE(s.refund_amount, 0),
      ', multi_net=', COALESCE(m.net_amount, 0), ', source_net=', COALESCE(s.net_amount, 0)
    )
  FROM channel_source_amount_stats s
  LEFT JOIN multi_amount_stats m
    ON m.theme_name = 'channel_theme'
)

INSERT OVERWRITE TABLE dq_multi_theme_check_result_di PARTITION (dt='__RUN_DT__')
SELECT
  pipeline_name,
  layer_name,
  table_name,
  check_name,
  check_status,
  err_msg,
  CAST(current_timestamp() AS STRING) AS checked_at
FROM checks;
