USE hive_demo;

INSERT OVERWRITE TABLE dws_order_daily_dp PARTITION (dt='__RUN_DT__')
SELECT
  COUNT(DISTINCT user_id) AS order_users,
  SUM(amount) AS gmv
FROM dwd_order_p
WHERE dt = '__RUN_DT__';

INSERT OVERWRITE TABLE dws_visit_daily_dp PARTITION (dt='__RUN_DT__')
SELECT
  COUNT(DISTINCT CASE WHEN event_type = 'visit' THEN user_id END) AS visit_users
FROM dwd_event_p
WHERE dt = '__RUN_DT__';

INSERT OVERWRITE TABLE dws_conversion_daily_dp PARTITION (dt='__RUN_DT__')
SELECT
  COUNT(DISTINCT CASE WHEN event_type = 'visit' THEN user_id END) AS visit_users,
  COUNT(DISTINCT CASE WHEN event_type = 'order' THEN user_id END) AS order_users,
  ROUND(
    COUNT(DISTINCT CASE WHEN event_type = 'order' THEN user_id END) /
    NULLIF(COUNT(DISTINCT CASE WHEN event_type = 'visit' THEN user_id END), 0),
    4
  ) AS conversion_rate
FROM dwd_event_p
WHERE dt = '__RUN_DT__';
