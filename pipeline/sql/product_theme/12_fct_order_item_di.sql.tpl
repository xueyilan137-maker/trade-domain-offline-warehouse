USE hive_demo;

INSERT OVERWRITE TABLE fct_order_item_di PARTITION (dt='__RUN_DT__')
SELECT
  order_id,
  user_id,
  product_id,
  item_cnt,
  item_amount
FROM dwd_order_item_clean_di
WHERE dt = '__RUN_DT__';
