USE hive_demo;

WITH refund_stats AS (
  SELECT
    SUM(raw_order_cnt) AS raw_order_cnt,
    SUM(valid_order_cnt) AS valid_order_cnt,
    SUM(cancel_order_cnt) AS cancel_order_cnt,
    CAST(SUM(gross_valid_gmv) AS DECIMAL(10,2)) AS gross_valid_gmv,
    SUM(refund_order_cnt) AS refund_order_cnt,
    CAST(SUM(refund_amount) AS DECIMAL(10,2)) AS refund_amount,
    CAST(SUM(net_gmv) AS DECIMAL(10,2)) AS net_gmv
  FROM dws_user_order_refund_day_agg
  WHERE dt = '__RUN_DT__'
)
INSERT OVERWRITE TABLE ads_order_refund_day_overview PARTITION (dt='__RUN_DT__')
SELECT
  raw_order_cnt,
  valid_order_cnt,
  cancel_order_cnt,
  gross_valid_gmv,
  refund_order_cnt,
  refund_amount,
  net_gmv,
  CAST(ROUND(refund_order_cnt / NULLIF(valid_order_cnt, 0), 4) AS DECIMAL(10,4)) AS refund_order_rate,
  CAST(ROUND(refund_amount / NULLIF(gross_valid_gmv, 0), 4) AS DECIMAL(10,4)) AS refund_gmv_rate
FROM refund_stats;
