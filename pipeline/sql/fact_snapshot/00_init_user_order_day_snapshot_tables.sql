CREATE DATABASE IF NOT EXISTS hive_demo;

USE hive_demo;

CREATE TABLE IF NOT EXISTS fct_user_order_day_snapshot (
  user_id STRING,
  order_cnt BIGINT,
  order_amount DECIMAL(10,2)
)
USING parquet
PARTITIONED BY (dt STRING);
