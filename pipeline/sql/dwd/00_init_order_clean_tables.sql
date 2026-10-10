CREATE DATABASE IF NOT EXISTS hive_demo;

USE hive_demo;

CREATE TABLE IF NOT EXISTS dwd_order_clean_di (
  order_id STRING,
  user_id STRING,
  order_date STRING,
  amount DECIMAL(10,2)
)
USING parquet
PARTITIONED BY (dt STRING);

CREATE TABLE IF NOT EXISTS dwd_order_dirty_di (
  order_id STRING,
  user_id STRING,
  order_date STRING,
  amount DECIMAL(10,2),
  dirty_reason STRING
)
USING parquet
PARTITIONED BY (dt STRING);

CREATE TABLE IF NOT EXISTS dwd_order_cancel_p (
  order_id STRING,
  user_id STRING,
  cancel_date STRING,
  cancel_reason STRING
)
USING parquet
PARTITIONED BY (dt STRING);

CREATE TABLE IF NOT EXISTS dwd_order_cancel_clean_di (
  order_id STRING,
  user_id STRING,
  cancel_date STRING,
  cancel_reason STRING
)
USING parquet
PARTITIONED BY (dt STRING);

CREATE TABLE IF NOT EXISTS dwd_order_refund_p (
  order_id STRING,
  user_id STRING,
  refund_date STRING,
  refund_amount DECIMAL(10,2),
  refund_reason STRING
)
USING parquet
PARTITIONED BY (dt STRING);

CREATE TABLE IF NOT EXISTS dwd_order_refund_clean_di (
  order_id STRING,
  user_id STRING,
  refund_date STRING,
  refund_amount DECIMAL(10,2),
  refund_reason STRING
)
USING parquet
PARTITIONED BY (dt STRING);
