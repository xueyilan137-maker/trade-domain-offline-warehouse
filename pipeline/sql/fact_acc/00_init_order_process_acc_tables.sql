CREATE DATABASE IF NOT EXISTS hive_demo;

USE hive_demo;

CREATE TABLE IF NOT EXISTS ods_order_process_di (
  order_id STRING,
  user_id STRING,
  create_date STRING,
  pay_date STRING,
  ship_date STRING,
  finish_date STRING,
  order_status STRING
)
USING parquet
PARTITIONED BY (dt STRING);

CREATE TABLE IF NOT EXISTS fct_order_process_acc (
  order_id STRING,
  user_id STRING,
  create_date STRING,
  pay_date STRING,
  ship_date STRING,
  finish_date STRING,
  order_status STRING
)
USING parquet;
