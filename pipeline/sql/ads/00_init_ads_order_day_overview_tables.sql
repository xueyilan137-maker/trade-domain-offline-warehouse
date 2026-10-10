CREATE DATABASE IF NOT EXISTS hive_demo;

USE hive_demo;

CREATE TABLE IF NOT EXISTS ads_order_day_overview (
  order_users BIGINT,
  order_cnt BIGINT,
  gmv DECIMAL(10,2),
  avg_order_amount DECIMAL(10,2)
)
USING parquet
PARTITIONED BY (dt STRING);

CREATE TABLE IF NOT EXISTS ads_order_status_day_overview (
  raw_order_users BIGINT,
  raw_order_cnt BIGINT,
  raw_gmv DECIMAL(10,2),
  valid_order_users BIGINT,
  valid_order_cnt BIGINT,
  valid_gmv DECIMAL(10,2),
  cancel_order_users BIGINT,
  cancel_order_cnt BIGINT,
  cancel_amount DECIMAL(10,2),
  valid_order_rate DECIMAL(10,4),
  cancel_order_rate DECIMAL(10,4)
)
USING parquet
PARTITIONED BY (dt STRING);

CREATE TABLE IF NOT EXISTS ads_order_refund_day_overview (
  raw_order_cnt BIGINT,
  valid_order_cnt BIGINT,
  cancel_order_cnt BIGINT,
  gross_valid_gmv DECIMAL(10,2),
  refund_order_cnt BIGINT,
  refund_amount DECIMAL(10,2),
  net_gmv DECIMAL(10,2),
  refund_order_rate DECIMAL(10,4),
  refund_gmv_rate DECIMAL(10,4)
)
USING parquet
PARTITIONED BY (dt STRING);

CREATE TABLE IF NOT EXISTS ads_user_level_trade_day_overview (
  user_level STRING,
  trade_user_cnt BIGINT,
  raw_order_cnt BIGINT,
  valid_order_cnt BIGINT,
  cancel_order_cnt BIGINT,
  gross_valid_gmv DECIMAL(10,2),
  refund_order_cnt BIGINT,
  refund_amount DECIMAL(10,2),
  net_gmv DECIMAL(10,2),
  refund_order_rate DECIMAL(10,4),
  refund_gmv_rate DECIMAL(10,4)
)
USING parquet
PARTITIONED BY (dt STRING);
