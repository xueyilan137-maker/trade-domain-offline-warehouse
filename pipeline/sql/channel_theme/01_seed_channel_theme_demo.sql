CREATE DATABASE IF NOT EXISTS hive_demo;

USE hive_demo;

INSERT OVERWRITE TABLE ods_channel_info_di PARTITION (dt='2026-03-05')
SELECT
  channel_id,
  channel_name,
  channel_type
FROM VALUES
  ('ch01', 'App', 'Owned'),
  ('ch02', 'Mini Program', 'Owned'),
  ('ch03', 'Ad Campaign', 'Paid')
AS t(channel_id, channel_name, channel_type);

INSERT OVERWRITE TABLE ods_order_channel_di PARTITION (dt='2026-03-05')
SELECT
  order_id,
  user_id,
  channel_id
FROM VALUES
  ('o2001', 'u10', 'ch01'),
  ('o2002', 'u11', 'ch03'),
  ('o2005', 'u14', 'ch02')
AS t(order_id, user_id, channel_id);
