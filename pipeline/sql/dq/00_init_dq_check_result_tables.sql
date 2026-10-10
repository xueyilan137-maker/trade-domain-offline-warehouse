CREATE DATABASE IF NOT EXISTS hive_demo;

USE hive_demo;

CREATE TABLE IF NOT EXISTS dq_check_result_di (
  pipeline_name STRING,
  layer_name STRING,
  table_name STRING,
  check_name STRING,
  check_status STRING,
  err_msg STRING,
  checked_at STRING
)
USING parquet
PARTITIONED BY (dt STRING);

CREATE TABLE IF NOT EXISTS dq_order_refund_anomaly_di (
  order_id STRING,
  user_id STRING,
  order_date STRING,
  refund_date STRING,
  order_amount DECIMAL(10,2),
  refund_amount DECIMAL(10,2),
  net_amount DECIMAL(10,2),
  order_status STRING,
  is_cancelled INT,
  is_refunded INT,
  anomaly_type STRING,
  anomaly_level STRING,
  anomaly_desc STRING,
  source_table STRING,
  checked_at STRING
)
USING parquet
PARTITIONED BY (dt STRING);
