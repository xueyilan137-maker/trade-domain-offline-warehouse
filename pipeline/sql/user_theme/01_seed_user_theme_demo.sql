CREATE DATABASE IF NOT EXISTS hive_demo;

USE hive_demo;

INSERT OVERWRITE TABLE ods_user_info_di PARTITION (dt='2026-03-05')
SELECT
  user_id,
  user_name,
  user_level
FROM VALUES
  ('u10', 'Alice', 'GOLD'),
  ('u11', 'Bob', 'SILVER'),
  ('u14', 'Cindy', 'NORMAL')
AS t(user_id, user_name, user_level);
