USE hive_demo;

INSERT OVERWRITE TABLE dim_user_snapshot_di PARTITION (dt='__RUN_DT__')
SELECT
  user_id,
  user_name,
  user_level
FROM dwd_user_info_clean_di
WHERE dt = '__RUN_DT__';
