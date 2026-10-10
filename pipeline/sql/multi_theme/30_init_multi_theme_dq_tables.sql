CREATE DATABASE IF NOT EXISTS hive_demo;

USE hive_demo;

CREATE TABLE IF NOT EXISTS dq_multi_theme_check_result_di (
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
