CREATE DATABASE IF NOT EXISTS hive_demo;

USE hive_demo;

DROP TABLE IF EXISTS ods_users;
CREATE EXTERNAL TABLE ods_users (
  user_id STRING,
  reg_date STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/dw_demo/ods/users'
TBLPROPERTIES ('skip.header.line.count'='1');

DROP TABLE IF EXISTS ods_orders;
CREATE EXTERNAL TABLE ods_orders (
  order_id STRING,
  user_id STRING,
  order_date STRING,
  amount DECIMAL(10,2)
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/dw_demo/ods/orders'
TBLPROPERTIES ('skip.header.line.count'='1');

DROP TABLE IF EXISTS ods_events;
CREATE EXTERNAL TABLE ods_events (
  user_id STRING,
  event_time STRING,
  event_type STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/dw_demo/ods/events'
TBLPROPERTIES ('skip.header.line.count'='1');

SELECT 'ods_users' AS table_name, COUNT(*) AS cnt FROM ods_users
UNION ALL
SELECT 'ods_orders' AS table_name, COUNT(*) AS cnt FROM ods_orders
UNION ALL
SELECT 'ods_events' AS table_name, COUNT(*) AS cnt FROM ods_events;
