USE hive_demo;

INSERT OVERWRITE TABLE dim_channel_snapshot_di PARTITION (dt='__RUN_DT__')
SELECT
  TRIM(channel_id) AS channel_id,
  TRIM(channel_name) AS channel_name,
  TRIM(channel_type) AS channel_type
FROM ods_channel_info_di
WHERE dt = '__RUN_DT__'
  AND channel_id IS NOT NULL
  AND TRIM(channel_id) <> '';
