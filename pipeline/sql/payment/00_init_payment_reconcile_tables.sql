CREATE DATABASE IF NOT EXISTS hive_demo;

USE hive_demo;

CREATE TABLE IF NOT EXISTS dwd_payment_p (
  payment_id STRING,
  order_id STRING,
  user_id STRING,
  pay_date STRING,
  pay_amount DECIMAL(10,2),
  pay_status STRING
)
USING parquet
PARTITIONED BY (dt STRING);

CREATE TABLE IF NOT EXISTS dwd_payment_clean_di (
  payment_id STRING,
  order_id STRING,
  user_id STRING,
  pay_date STRING,
  pay_amount DECIMAL(10,2),
  pay_status STRING
)
USING parquet
PARTITIONED BY (dt STRING);

CREATE TABLE IF NOT EXISTS dwd_payment_dirty_di (
  payment_id STRING,
  order_id STRING,
  user_id STRING,
  pay_date STRING,
  pay_amount DECIMAL(10,2),
  pay_status STRING,
  dirty_reason STRING
)
USING parquet
PARTITIONED BY (dt STRING);

CREATE TABLE IF NOT EXISTS fct_payment_di (
  payment_id STRING,
  order_id STRING,
  user_id STRING,
  pay_date STRING,
  pay_amount DECIMAL(10,2),
  pay_status STRING
)
USING parquet
PARTITIONED BY (dt STRING);

CREATE TABLE IF NOT EXISTS dq_order_payment_reconcile_di (
  order_id STRING,
  order_user_id STRING,
  order_amount DECIMAL(10,2),
  payment_id STRING,
  payment_user_id STRING,
  pay_amount DECIMAL(10,2),
  reconcile_status STRING,
  diff_amount DECIMAL(10,2)
)
USING parquet
PARTITIONED BY (dt STRING);

CREATE TABLE IF NOT EXISTS ads_order_payment_reconcile_overview (
  reconcile_cnt BIGINT,
  matched_cnt BIGINT,
  amount_mismatch_cnt BIGINT,
  order_without_payment_cnt BIGINT,
  payment_without_order_cnt BIGINT,
  abnormal_cnt BIGINT,
  matched_rate DECIMAL(10,4),
  abnormal_rate DECIMAL(10,4),
  total_diff_amount DECIMAL(10,2)
)
USING parquet
PARTITIONED BY (dt STRING);
