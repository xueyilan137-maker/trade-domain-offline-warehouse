USE hive_demo;

INSERT OVERWRITE TABLE dwd_order_p PARTITION (dt='__RUN_DT__')
SELECT
  order_id,
  user_id,
  order_date,
  CAST(amount AS DECIMAL(10,2)) AS amount
FROM dwd_order
WHERE dt = '__RUN_DT__';

INSERT OVERWRITE TABLE dwd_event_p PARTITION (dt='__RUN_DT__')
SELECT
  user_id,
  event_time,
  event_type,
  event_date
FROM dwd_event
WHERE dt = '__RUN_DT__';
