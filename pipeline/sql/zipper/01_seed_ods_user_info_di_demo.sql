USE hive_demo;

INSERT OVERWRITE TABLE ods_user_info_di PARTITION (dt='2026-04-20')
SELECT
  user_id,
  user_name,
  user_level
FROM VALUES
  ('u1001', 'Alice', 'NORMAL'),
  ('u1002', 'Bob', 'VIP')
AS t(user_id, user_name, user_level);

INSERT OVERWRITE TABLE ods_user_info_di PARTITION (dt='2026-04-21')
SELECT
  user_id,
  user_name,
  user_level
FROM VALUES
  ('u1001', 'Alice', 'VIP'),
  ('u1002', 'Bob', 'VIP'),
  ('u1003', 'Carol', 'NORMAL')
AS t(user_id, user_name, user_level);

INSERT OVERWRITE TABLE ods_user_info_di PARTITION (dt='2026-04-22')
SELECT
  user_id,
  user_name,
  user_level
FROM VALUES
  ('u1001', 'Alice', 'VIP'),
  ('u1002', 'Bob', 'SVIP'),
  ('u1003', 'Carol', 'NORMAL'),
  ('u1004', 'David', 'NORMAL')
AS t(user_id, user_name, user_level);
