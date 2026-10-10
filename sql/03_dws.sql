USE hive_demo;

DROP TABLE IF EXISTS dws_register_daily;
CREATE TABLE dws_register_daily AS
SELECT
  dt,
  COUNT(DISTINCT user_id) AS register_users
FROM dwd_user
GROUP BY dt;

DROP TABLE IF EXISTS dws_order_daily;
CREATE TABLE dws_order_daily AS
SELECT
  dt,
  COUNT(DISTINCT user_id) AS order_users,
  SUM(amount) AS gmv
FROM dwd_order
GROUP BY dt;

DROP TABLE IF EXISTS dws_visit_daily;
CREATE TABLE dws_visit_daily AS
SELECT
  dt,
  COUNT(DISTINCT CASE WHEN event_type = 'visit' THEN user_id END) AS visit_users
FROM dwd_event
GROUP BY dt;

DROP TABLE IF EXISTS dws_conversion_daily;
CREATE TABLE dws_conversion_daily AS
SELECT
  e.dt,
  COUNT(DISTINCT CASE WHEN e.event_type = 'visit' THEN e.user_id END) AS visit_users,
  COUNT(DISTINCT CASE WHEN e.event_type = 'order' THEN e.user_id END) AS order_users,
  ROUND(
    COUNT(DISTINCT CASE WHEN e.event_type = 'order' THEN e.user_id END) /
    NULLIF(COUNT(DISTINCT CASE WHEN e.event_type = 'visit' THEN e.user_id END), 0),
    4
  ) AS conversion_rate
FROM dwd_event e
GROUP BY e.dt;
