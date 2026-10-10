USE hive_demo;

INSERT OVERWRITE TABLE dwd_order_p PARTITION (dt='2026-03-05')
SELECT 'o2001' AS order_id, 'u10' AS user_id, '2026-03-05' AS order_date, CAST(100.00 AS DECIMAL(10,2)) AS amount
UNION ALL
SELECT 'o2002' AS order_id, 'u11' AS user_id, '2026-03-05' AS order_date, CAST(80.00 AS DECIMAL(10,2)) AS amount
UNION ALL
SELECT 'o2002' AS order_id, 'u11' AS user_id, '2026-03-05' AS order_date, CAST(90.00 AS DECIMAL(10,2)) AS amount
UNION ALL
SELECT '' AS order_id, 'u12' AS user_id, '2026-03-05' AS order_date, CAST(50.00 AS DECIMAL(10,2)) AS amount
UNION ALL
SELECT 'o2003' AS order_id, '' AS user_id, '2026-03-05' AS order_date, CAST(60.00 AS DECIMAL(10,2)) AS amount
UNION ALL
SELECT 'o2004' AS order_id, 'u13' AS user_id, '2026-03-05' AS order_date, CAST(-20.00 AS DECIMAL(10,2)) AS amount
UNION ALL
SELECT '  o2005  ' AS order_id, '  u14  ' AS user_id, '2026-03-05' AS order_date, CAST(30.00 AS DECIMAL(10,2)) AS amount;
