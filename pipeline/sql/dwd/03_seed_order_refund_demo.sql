USE hive_demo;

INSERT OVERWRITE TABLE dwd_order_refund_p PARTITION (dt='2026-03-05')
SELECT
  'o2001' AS order_id,
  'u10' AS user_id,
  '2026-03-05' AS refund_date,
  CAST(20.00 AS DECIMAL(10,2)) AS refund_amount,
  'partial_refund' AS refund_reason;
