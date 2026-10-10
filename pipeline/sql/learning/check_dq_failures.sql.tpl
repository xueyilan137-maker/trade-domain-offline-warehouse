USE hive_demo;

SELECT
  layer_name,
  table_name,
  check_name,
  check_status,
  err_msg
FROM dq_check_result_di
WHERE dt = '__RUN_DT__'
  AND check_status <> 'PASS'
ORDER BY layer_name, table_name, check_name;
