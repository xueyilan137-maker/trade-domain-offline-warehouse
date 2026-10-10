CREATE DATABASE IF NOT EXISTS hive_demo;

USE hive_demo;

CREATE TABLE IF NOT EXISTS ods_channel_info_di (
  channel_id STRING,
  channel_name STRING,
  channel_type STRING
)
USING parquet
PARTITIONED BY (dt STRING);

CREATE TABLE IF NOT EXISTS dim_channel_snapshot_di (
  channel_id STRING,
  channel_name STRING,
  channel_type STRING
)
USING parquet
PARTITIONED BY (dt STRING);

CREATE TABLE IF NOT EXISTS ods_order_channel_di (
  order_id STRING,
  user_id STRING,
  channel_id STRING
)
USING parquet
PARTITIONED BY (dt STRING);

CREATE TABLE IF NOT EXISTS dwd_order_channel_clean_di (
  order_id STRING,
  user_id STRING,
  channel_id STRING
)
USING parquet
PARTITIONED BY (dt STRING);

CREATE TABLE IF NOT EXISTS fct_order_channel_di (
  order_id STRING,
  user_id STRING,
  channel_id STRING
)
USING parquet
PARTITIONED BY (dt STRING);

CREATE TABLE IF NOT EXISTS dws_channel_trade_day_agg (
  channel_name STRING,
  channel_type STRING,
  trade_user_cnt BIGINT,
  raw_order_cnt BIGINT,
  valid_order_cnt BIGINT,
  cancel_order_cnt BIGINT,
  raw_gmv DECIMAL(10,2),
  gross_valid_gmv DECIMAL(10,2),
  cancel_amount DECIMAL(10,2),
  refund_amount DECIMAL(10,2),
  net_gmv DECIMAL(10,2)
)
USING parquet
PARTITIONED BY (dt STRING);

CREATE TABLE IF NOT EXISTS ads_channel_trade_day_overview (
  channel_name STRING,
  channel_type STRING,
  trade_user_cnt BIGINT,
  raw_order_cnt BIGINT,
  valid_order_cnt BIGINT,
  cancel_order_cnt BIGINT,
  raw_gmv DECIMAL(10,2),
  gross_valid_gmv DECIMAL(10,2),
  cancel_amount DECIMAL(10,2),
  refund_amount DECIMAL(10,2),
  net_gmv DECIMAL(10,2),
  cancel_order_rate DECIMAL(10,4),
  refund_gmv_rate DECIMAL(10,4)
)
USING parquet
PARTITIONED BY (dt STRING);
