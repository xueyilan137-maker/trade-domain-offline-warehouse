CREATE DATABASE IF NOT EXISTS rt_dw;

USE rt_dw;

CREATE TABLE IF NOT EXISTS ads_rt_visit_pv_10s (
    metric_code VARCHAR(32) NOT NULL COMMENT 'stable metric key, e.g. visit_pv_10s',
    window_start DATETIME(3) NOT NULL,
    window_end DATETIME(3) NOT NULL,
    pv BIGINT NOT NULL COMMENT 'latest corrected pv result for the window',
    revision INT NOT NULL COMMENT 'window firing number, 1 for first emit, 2 for late correction',
    update_time DATETIME(3) NOT NULL COMMENT 'when this result version was produced',
    version_ts BIGINT NOT NULL COMMENT 'monotonic version used for out-of-order overwrite protection',
    watermark_time DATETIME(3) NULL COMMENT 'watermark observed when the result was emitted',
    source_job VARCHAR(64) NULL COMMENT 'which realtime job produced the result'
)
UNIQUE KEY(metric_code, window_start, window_end)
DISTRIBUTED BY HASH(metric_code) BUCKETS 1
PROPERTIES (
    "replication_num" = "1",
    "enable_unique_key_merge_on_write" = "true",
    "function_column.sequence_col" = "version_ts"
);
