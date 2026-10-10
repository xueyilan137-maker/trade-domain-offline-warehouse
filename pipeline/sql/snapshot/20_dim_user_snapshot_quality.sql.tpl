USE hive_demo;

SELECT 'dim_user_snapshot_di row count check failed' AS err_msg
WHERE (
  SELECT COUNT(*)
  FROM dim_user_snapshot_di
  WHERE dt = '__RUN_DT__'
) = 0;

SELECT 'dim_user_snapshot_di duplicate user check failed' AS err_msg
WHERE EXISTS (
  SELECT user_id
  FROM dim_user_snapshot_di
  WHERE dt = '__RUN_DT__'
  GROUP BY user_id
  HAVING COUNT(*) > 1
);

SELECT 'dim_user_snapshot_di null key check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM dim_user_snapshot_di
  WHERE dt = '__RUN_DT__'
    AND (
      user_id IS NULL
      OR TRIM(user_id) = ''
      OR user_name IS NULL
      OR TRIM(user_name) = ''
      OR user_level IS NULL
      OR TRIM(user_level) = ''
    )
);
