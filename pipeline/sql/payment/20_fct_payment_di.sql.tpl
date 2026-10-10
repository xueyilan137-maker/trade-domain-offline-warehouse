USE hive_demo;

INSERT OVERWRITE TABLE fct_payment_di PARTITION (dt='__RUN_DT__')
SELECT
  payment_id,
  order_id,
  user_id,
  pay_date,
  pay_amount,
  pay_status
FROM dwd_payment_clean_di
WHERE dt = '__RUN_DT__';
