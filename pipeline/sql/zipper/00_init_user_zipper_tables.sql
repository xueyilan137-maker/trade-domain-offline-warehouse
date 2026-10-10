CREATE DATABASE IF NOT EXISTS hive_demo;

USE hive_demo;

CREATE TABLE IF NOT EXISTS ods_user_info_di (
  user_id STRING,
  user_name STRING,
  user_level STRING
)
USING parquet
PARTITIONED BY (dt STRING);

CREATE TABLE IF NOT EXISTS dwd_user_info_clean_di (
  user_id STRING,
  user_name STRING,
  user_level STRING
)
USING parquet
PARTITIONED BY (dt STRING);

CREATE TABLE IF NOT EXISTS dim_user_zipper (
  user_id STRING,
  user_name STRING,
  user_level STRING,
  start_date STRING,
  end_date STRING,
  is_current INT
)
USING parquet;

CREATE TABLE IF NOT EXISTS dim_user_zipper_tmp (
  user_id STRING,
  user_name STRING,
  user_level STRING,
  start_date STRING,
  end_date STRING,
  is_current INT
)
USING parquet;
