USE hive_demo;

-- DWD partitioned tables
CREATE TABLE IF NOT EXISTS dwd_order_p (
  order_id STRING,
  user_id STRING,
  order_date STRING,
  amount DECIMAL(10,2)
)
USING parquet
PARTITIONED BY (dt STRING);

CREATE TABLE IF NOT EXISTS dwd_event_p (
  user_id STRING,
  event_time STRING,
  event_type STRING,
  event_date STRING
)
USING parquet
PARTITIONED BY (dt STRING);

-- DWS partitioned tables
CREATE TABLE IF NOT EXISTS dws_order_daily_dp (
  order_users BIGINT,
  gmv DECIMAL(10,2)
)
USING parquet
PARTITIONED BY (dt STRING);

CREATE TABLE IF NOT EXISTS dws_visit_daily_dp (
  visit_users BIGINT
)
USING parquet
PARTITIONED BY (dt STRING);

CREATE TABLE IF NOT EXISTS dws_conversion_daily_dp (
  visit_users BIGINT,
  order_users BIGINT,
  conversion_rate DECIMAL(10,4)
)
USING parquet
PARTITIONED BY (dt STRING);

CREATE TABLE IF NOT EXISTS ads_daily_overview_dp (
  register_users BIGINT,
  visit_users BIGINT,
  order_users BIGINT,
  gmv DECIMAL(10,2),
  conversion_rate DECIMAL(10,4),
  order_rate DECIMAL(10,4),
  avg_order_amount DECIMAL(10,2),
  repurchase_users BIGINT,
  repurchase_rate DECIMAL(10,4)
)
USING parquet
PARTITIONED BY (dt STRING);
