USE hive_demo;

WITH today AS (
  SELECT
    order_id,
    user_id,
    create_date,
    pay_date,
    ship_date,
    finish_date,
    order_status
  FROM ods_order_process_di
  WHERE dt = '__RUN_DT__'
)
INSERT OVERWRITE TABLE fct_order_process_acc
SELECT
  order_id,
  user_id,
  create_date,
  pay_date,
  ship_date,
  finish_date,
  order_status
FROM today;
