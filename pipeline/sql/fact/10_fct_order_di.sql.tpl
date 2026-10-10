USE hive_demo;

INSERT OVERWRITE TABLE fct_order_di PARTITION (dt='__RUN_DT__')
SELECT
  order_id,
  user_id,
  order_date,
  amount
FROM dwd_order_clean_di
WHERE dt = '__RUN_DT__';
