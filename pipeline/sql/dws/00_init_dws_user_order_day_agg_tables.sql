CREATE DATABASE IF NOT EXISTS hive_demo;

USE hive_demo;

CREATE TABLE IF NOT EXISTS dws_user_order_day_agg (
  user_id STRING,
  order_cnt BIGINT,
  order_amount DECIMAL(10,2),
  avg_order_amount DECIMAL(10,2)
)
USING parquet
PARTITIONED BY (dt STRING);

CREATE TABLE IF NOT EXISTS dws_user_order_refund_day_agg (
  user_id STRING,
  raw_order_cnt BIGINT,
  valid_order_cnt BIGINT,
  cancel_order_cnt BIGINT,
  gross_valid_gmv DECIMAL(10,2),
  refund_order_cnt BIGINT,
  refund_amount DECIMAL(10,2),
  net_gmv DECIMAL(10,2)
)
USING parquet
PARTITIONED BY (dt STRING);

CREATE TABLE IF NOT EXISTS dws_user_level_trade_day_agg (
  user_level STRING,
  trade_user_cnt BIGINT,
  raw_order_cnt BIGINT,
  valid_order_cnt BIGINT,
  cancel_order_cnt BIGINT,
  gross_valid_gmv DECIMAL(10,2),
  refund_order_cnt BIGINT,
  refund_amount DECIMAL(10,2),
  net_gmv DECIMAL(10,2)
)
USING parquet
PARTITIONED BY (dt STRING);
