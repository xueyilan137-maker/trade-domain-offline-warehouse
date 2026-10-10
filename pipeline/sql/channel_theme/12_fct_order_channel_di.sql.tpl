USE hive_demo;

INSERT OVERWRITE TABLE fct_order_channel_di PARTITION (dt='__RUN_DT__')
SELECT
  order_id,
  user_id,
  channel_id
FROM dwd_order_channel_clean_di
WHERE dt = '__RUN_DT__';
