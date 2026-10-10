USE hive_demo;

INSERT OVERWRITE TABLE fct_order_refund_status_di PARTITION (dt='__RUN_DT__')
SELECT
  s.order_id,
  s.user_id,
  s.order_date,
  s.amount,
  s.order_status,
  s.is_cancelled,
  s.cancel_date,
  s.cancel_reason,
  CASE
    WHEN r.order_id IS NOT NULL THEN 1
    ELSE 0
  END AS is_refunded,
  r.refund_date,
  COALESCE(r.refund_amount, CAST(0.00 AS DECIMAL(10,2))) AS refund_amount,
  r.refund_reason,
  CAST(
    CASE
      WHEN s.order_status = 'CANCELLED' THEN 0.00
      ELSE s.amount - COALESCE(r.refund_amount, CAST(0.00 AS DECIMAL(10,2)))
    END
    AS DECIMAL(10,2)
  ) AS net_amount
FROM fct_order_status_di s
LEFT JOIN dwd_order_refund_clean_di r
  ON s.order_id = r.order_id
 AND s.dt <= r.dt
WHERE s.dt = '__RUN_DT__';
