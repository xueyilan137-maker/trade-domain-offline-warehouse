USE rt_dw;

CREATE ROUTINE LOAD rt_dw.rl_ads_rt_visit_pv_10s
ON ads_rt_visit_pv_10s
PROPERTIES (
    "desired_concurrent_number" = "1",
    "max_batch_interval" = "5",
    "max_batch_rows" = "200000",
    "max_batch_size" = "104857600",
    "format" = "json",
    "strict_mode" = "false"
)
FROM KAFKA (
    "kafka_broker_list" = "rt-kafka:29092",
    "kafka_topic" = "dws_rt_visit_pv_10s",
    "property.group.id" = "doris_ads_rt_visit_pv_10s",
    "property.kafka_default_offsets" = "OFFSET_BEGINNING"
);

-- Expected result-topic JSON contract:
-- {
--   "metric_code": "visit_pv_10s",
--   "window_start": "2026-04-14 09:20:00.000",
--   "window_end": "2026-04-14 09:20:10.000",
--   "pv": 5,
--   "revision": 2,
--   "update_time": "2026-04-14 09:20:11.000",
--   "version_ts": 1776158411000,
--   "watermark_time": "2026-04-14 09:20:10.000",
--   "source_job": "allowed_lateness_visit_pv_demo"
-- }

-- If you need to recreate the job during learning:
-- STOP ROUTINE LOAD FOR rt_dw.rl_ads_rt_visit_pv_10s;
-- DROP ROUTINE LOAD FOR rt_dw.rl_ads_rt_visit_pv_10s;
