CREATE DATABASE IF NOT EXISTS hive_demo;

USE hive_demo;

CREATE TABLE IF NOT EXISTS ods_product_info_di (
  product_id STRING,
  product_name STRING,
  category_id STRING,
  category_name STRING,
  brand_name STRING
)
USING parquet
PARTITIONED BY (dt STRING);

CREATE TABLE IF NOT EXISTS dim_product_snapshot_di (
  product_id STRING,
  product_name STRING,
  category_id STRING,
  category_name STRING,
  brand_name STRING
)
USING parquet
PARTITIONED BY (dt STRING);

CREATE TABLE IF NOT EXISTS ods_order_item_di (
  order_id STRING,
  user_id STRING,
  product_id STRING,
  item_cnt BIGINT,
  item_amount DECIMAL(10,2)
)
USING parquet
PARTITIONED BY (dt STRING);

CREATE TABLE IF NOT EXISTS dwd_order_item_clean_di (
  order_id STRING,
  user_id STRING,
  product_id STRING,
  item_cnt BIGINT,
  item_amount DECIMAL(10,2)
)
USING parquet
PARTITIONED BY (dt STRING);

CREATE TABLE IF NOT EXISTS fct_order_item_di (
  order_id STRING,
  user_id STRING,
  product_id STRING,
  item_cnt BIGINT,
  item_amount DECIMAL(10,2)
)
USING parquet
PARTITIONED BY (dt STRING);

CREATE TABLE IF NOT EXISTS dws_category_trade_day_agg (
  category_name STRING,
  raw_order_cnt BIGINT,
  trade_user_cnt BIGINT,
  item_cnt BIGINT,
  raw_item_amount DECIMAL(10,2),
  valid_item_amount DECIMAL(10,2),
  cancel_item_amount DECIMAL(10,2),
  refund_amount DECIMAL(10,2),
  net_item_amount DECIMAL(10,2)
)
USING parquet
PARTITIONED BY (dt STRING);

CREATE TABLE IF NOT EXISTS ads_category_trade_day_overview (
  category_name STRING,
  raw_order_cnt BIGINT,
  trade_user_cnt BIGINT,
  item_cnt BIGINT,
  raw_item_amount DECIMAL(10,2),
  valid_item_amount DECIMAL(10,2),
  cancel_item_amount DECIMAL(10,2),
  refund_amount DECIMAL(10,2),
  net_item_amount DECIMAL(10,2),
  refund_amount_rate DECIMAL(10,4)
)
USING parquet
PARTITIONED BY (dt STRING);
