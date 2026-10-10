CREATE DATABASE IF NOT EXISTS hive_demo;

USE hive_demo;

CREATE TABLE IF NOT EXISTS ads_trade_multi_theme_day_overview (
  theme_name STRING,
  dimension_name STRING,
  dimension_value STRING,
  dimension_type STRING,
  trade_user_cnt BIGINT,
  raw_order_cnt BIGINT,
  valid_order_cnt BIGINT,
  cancel_order_cnt BIGINT,
  item_cnt BIGINT,
  raw_amount DECIMAL(10,2),
  valid_amount DECIMAL(10,2),
  cancel_amount DECIMAL(10,2),
  refund_amount DECIMAL(10,2),
  net_amount DECIMAL(10,2),
  cancel_rate DECIMAL(10,4),
  refund_rate DECIMAL(10,4)
)
USING parquet
PARTITIONED BY (dt STRING);
