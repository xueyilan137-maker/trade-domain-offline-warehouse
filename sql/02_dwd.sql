USE hive_demo;

DROP TABLE IF EXISTS dwd_user;
CREATE TABLE dwd_user AS
SELECT
  user_id,
  reg_date,
  reg_date AS dt
FROM ods_users;

DROP TABLE IF EXISTS dwd_order;
CREATE TABLE dwd_order AS
SELECT
  order_id,
  user_id,
  order_date,
  amount,
  order_date AS dt
FROM ods_orders;

DROP TABLE IF EXISTS dwd_event;
CREATE TABLE dwd_event AS
SELECT
  user_id,
  event_time,
  event_type,
  event_time AS event_date,
  event_time AS dt
FROM ods_events;
