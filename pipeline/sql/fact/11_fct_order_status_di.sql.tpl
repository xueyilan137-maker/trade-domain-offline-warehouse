USE hive_demo;

INSERT OVERWRITE TABLE fct_order_status_di PARTITION (dt='__RUN_DT__')
SELECT
  o.order_id,
  o.user_id,
  o.order_date,
  o.amount,
  CASE
    WHEN c.order_id IS NOT NULL THEN 'CANCELLED'
    ELSE 'VALID'
  END AS order_status,
  CASE
    WHEN c.order_id IS NOT NULL THEN 1
    ELSE 0
  END AS is_cancelled,
  c.cancel_date,
  c.cancel_reason
FROM fct_order_di o
LEFT JOIN dwd_order_cancel_clean_di c
  ON o.order_id = c.order_id
 AND o.dt = c.dt
WHERE o.dt = '__RUN_DT__';
