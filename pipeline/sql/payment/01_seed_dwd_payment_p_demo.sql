USE hive_demo;

INSERT OVERWRITE TABLE dwd_payment_p PARTITION (dt='2026-03-05')
SELECT 'p3001' AS payment_id, 'o2001' AS order_id, 'u10' AS user_id, '2026-03-05' AS pay_date, CAST(100.00 AS DECIMAL(10,2)) AS pay_amount, 'SUCCESS' AS pay_status
UNION ALL
SELECT 'p3002' AS payment_id, 'o2002' AS order_id, 'u11' AS user_id, '2026-03-05' AS pay_date, CAST(80.00 AS DECIMAL(10,2)) AS pay_amount, 'SUCCESS' AS pay_status
UNION ALL
SELECT 'p3003' AS payment_id, 'o9999' AS order_id, 'u99' AS user_id, '2026-03-05' AS pay_date, CAST(40.00 AS DECIMAL(10,2)) AS pay_amount, 'SUCCESS' AS pay_status
UNION ALL
SELECT 'p3004' AS payment_id, 'o2005' AS order_id, 'u14' AS user_id, '2026-03-05' AS pay_date, CAST(30.00 AS DECIMAL(10,2)) AS pay_amount, 'SUCCESS' AS pay_status
UNION ALL
SELECT 'p3005' AS payment_id, '' AS order_id, 'u15' AS user_id, '2026-03-05' AS pay_date, CAST(20.00 AS DECIMAL(10,2)) AS pay_amount, 'SUCCESS' AS pay_status;
