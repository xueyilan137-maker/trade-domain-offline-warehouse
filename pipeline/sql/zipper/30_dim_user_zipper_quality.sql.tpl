USE hive_demo;

SELECT 'dwd_user_info_clean_di count check failed' AS err_msg
WHERE (
  SELECT COUNT(*)
  FROM dwd_user_info_clean_di
  WHERE dt = '__RUN_DT__'
) = 0;

SELECT 'dim_user_zipper current duplicate check failed' AS err_msg
WHERE EXISTS (
  SELECT user_id
  FROM dim_user_zipper
  WHERE is_current = 1
  GROUP BY user_id
  HAVING COUNT(*) > 1
);

SELECT 'dim_user_zipper current end_date check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM dim_user_zipper
  WHERE is_current = 1
    AND end_date <> '9999-12-31'
);

SELECT 'dim_user_zipper history date range check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM dim_user_zipper
  WHERE is_current = 0
    AND TO_DATE(start_date) > TO_DATE(end_date)
);
