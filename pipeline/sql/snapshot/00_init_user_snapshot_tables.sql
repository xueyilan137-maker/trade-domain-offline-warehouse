CREATE DATABASE IF NOT EXISTS hive_demo;

USE hive_demo;

CREATE TABLE IF NOT EXISTS dim_user_snapshot_di (
  user_id STRING,
  user_name STRING,
  user_level STRING
)
USING parquet
PARTITIONED BY (dt STRING);
