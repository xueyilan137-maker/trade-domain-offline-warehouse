-- Kafka source table for realtime practice.
-- Expected JSON fields:
--   event_id   STRING
--   user_id    STRING
--   event_type STRING
--   ts_ms      BIGINT (event timestamp in milliseconds)

CREATE TABLE rt_user_events_src (
    event_id STRING,
    user_id STRING,
    event_type STRING,
    ts_ms BIGINT,
    event_time AS TO_TIMESTAMP_LTZ(ts_ms, 3),
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'rt_user_events',
    'properties.bootstrap.servers' = 'rt-kafka:29092',
    'properties.group.id' = 'flink-sql-rt-user-events',
    'scan.startup.mode' = 'earliest-offset',
    'format' = 'json',
    'json.ignore-parse-errors' = 'true'
);
