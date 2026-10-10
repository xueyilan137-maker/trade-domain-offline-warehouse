USE hive_demo;

SELECT 'dwd_order_clean_di' AS table_name, COUNT(*) AS row_cnt
FROM dwd_order_clean_di
WHERE dt = '2026-03-05'
UNION ALL
SELECT 'dwd_order_dirty_di' AS table_name, COUNT(*) AS row_cnt
FROM dwd_order_dirty_di
WHERE dt = '2026-03-05'
UNION ALL
SELECT 'dwd_order_cancel_clean_di' AS table_name, COUNT(*) AS row_cnt
FROM dwd_order_cancel_clean_di
WHERE dt = '2026-03-05'
UNION ALL
SELECT 'dwd_order_refund_clean_di' AS table_name, COUNT(*) AS row_cnt
FROM dwd_order_refund_clean_di
WHERE dt = '2026-03-05';
