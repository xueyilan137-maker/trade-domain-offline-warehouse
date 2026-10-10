USE hive_demo;

INSERT OVERWRITE TABLE dwd_order_cancel_p PARTITION (dt='2026-03-05')
SELECT
  'o2002' AS order_id,
  'u11' AS user_id,
  '2026-03-05' AS cancel_date,
  'user_cancel' AS cancel_reason;
