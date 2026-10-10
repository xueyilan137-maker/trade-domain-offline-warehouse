CREATE DATABASE IF NOT EXISTS hive_demo;

USE hive_demo;

CREATE TABLE IF NOT EXISTS fct_order_di (
  order_id STRING,
  user_id STRING,
  order_date STRING,
  amount DECIMAL(10,2)
)
USING parquet
PARTITIONED BY (dt STRING);

CREATE TABLE IF NOT EXISTS fct_order_status_di (
  order_id STRING,
  user_id STRING,
  order_date STRING,
  amount DECIMAL(10,2),
  order_status STRING,
  is_cancelled INT,
  cancel_date STRING,
  cancel_reason STRING
)
USING parquet
PARTITIONED BY (dt STRING);

CREATE TABLE IF NOT EXISTS fct_order_refund_status_di (
  order_id STRING,
  user_id STRING,
  order_date STRING,
  amount DECIMAL(10,2),
  order_status STRING,
  is_cancelled INT,
  cancel_date STRING,
  cancel_reason STRING,
  is_refunded INT,
  refund_date STRING,
  refund_amount DECIMAL(10,2),
  refund_reason STRING,
  net_amount DECIMAL(10,2)
)
USING parquet
PARTITIONED BY (dt STRING);
