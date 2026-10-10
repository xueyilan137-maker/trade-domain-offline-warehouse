CREATE DATABASE IF NOT EXISTS hive_demo;

USE hive_demo;

-- Trade domain realistic item/channel demo data.
-- Date range: 2026-03-01 ~ 2026-03-07.
-- Scope: order items and order channels.

-- ---------------------------------------------------------------------------
-- Order items: ods_order_item_di
-- ---------------------------------------------------------------------------

INSERT OVERWRITE TABLE ods_order_item_di PARTITION (dt='2026-03-01')
SELECT order_id, user_id, product_id, item_cnt, item_amount
FROM VALUES
  ('o1001', 'u10', 'p01', 1, CAST(40.00 AS DECIMAL(10,2))),
  ('o1001', 'u10', 'p02', 1, CAST(60.00 AS DECIMAL(10,2))),
  ('o1002', 'u11', 'p03', 1, CAST(80.00 AS DECIMAL(10,2))),
  ('o1003', 'u12', 'p05', 1, CAST(60.00 AS DECIMAL(10,2)))
AS t(order_id, user_id, product_id, item_cnt, item_amount);

INSERT OVERWRITE TABLE ods_order_item_di PARTITION (dt='2026-03-02')
SELECT order_id, user_id, product_id, item_cnt, item_amount
FROM VALUES
  ('o1101', 'u10', 'p02', 1, CAST(120.00 AS DECIMAL(10,2))),
  ('o1102', 'u13', 'p03', 1, CAST(50.00 AS DECIMAL(10,2))),
  ('o1103', 'u14', 'p04', 1, CAST(70.00 AS DECIMAL(10,2))),
  ('o1104', 'u15', 'p05', 1, CAST(90.00 AS DECIMAL(10,2)))
AS t(order_id, user_id, product_id, item_cnt, item_amount);

INSERT OVERWRITE TABLE ods_order_item_di PARTITION (dt='2026-03-03')
SELECT order_id, user_id, product_id, item_cnt, item_amount
FROM VALUES
  ('o1201', 'u10', 'p01', 1, CAST(100.00 AS DECIMAL(10,2))),
  ('o1201', 'u10', 'p04', 2, CAST(100.00 AS DECIMAL(10,2))),
  ('o1202', 'u11', 'p03', 1, CAST(40.00 AS DECIMAL(10,2))),
  ('o1203', 'u16', 'p05', 3, CAST(150.00 AS DECIMAL(10,2)))
AS t(order_id, user_id, product_id, item_cnt, item_amount);

INSERT OVERWRITE TABLE ods_order_item_di PARTITION (dt='2026-03-04')
SELECT order_id, user_id, product_id, item_cnt, item_amount
FROM VALUES
  ('o1301', 'u17', 'p02', 1, CAST(180.00 AS DECIMAL(10,2))),
  ('o1301', 'u17', 'p05', 2, CAST(120.00 AS DECIMAL(10,2))),
  ('o1302', 'u12', 'p03', 1, CAST(88.00 AS DECIMAL(10,2))),
  ('o1303', 'u13', 'p01', 1, CAST(66.00 AS DECIMAL(10,2)))
AS t(order_id, user_id, product_id, item_cnt, item_amount);

INSERT OVERWRITE TABLE ods_order_item_di PARTITION (dt='2026-03-05')
SELECT order_id, user_id, product_id, item_cnt, item_amount
FROM VALUES
  ('o2001', 'u10', 'p01', 1, CAST(40.00 AS DECIMAL(10,2))),
  ('o2001', 'u10', 'p02', 1, CAST(60.00 AS DECIMAL(10,2))),
  ('o2002', 'u11', 'p03', 1, CAST(90.00 AS DECIMAL(10,2))),
  ('o2005', 'u14', 'p01', 1, CAST(30.00 AS DECIMAL(10,2)))
AS t(order_id, user_id, product_id, item_cnt, item_amount);

INSERT OVERWRITE TABLE ods_order_item_di PARTITION (dt='2026-03-06')
SELECT order_id, user_id, product_id, item_cnt, item_amount
FROM VALUES
  ('o1401', 'u18', 'p04', 1, CAST(75.00 AS DECIMAL(10,2))),
  ('o1402', 'u19', 'p02', 1, CAST(100.00 AS DECIMAL(10,2))),
  ('o1402', 'u19', 'p03', 1, CAST(80.00 AS DECIMAL(10,2))),
  ('o1403', 'u10', 'p05', 1, CAST(45.00 AS DECIMAL(10,2)))
AS t(order_id, user_id, product_id, item_cnt, item_amount);

INSERT OVERWRITE TABLE ods_order_item_di PARTITION (dt='2026-03-07')
SELECT order_id, user_id, product_id, item_cnt, item_amount
FROM VALUES
  ('o1501', 'u20', 'p01', 1, CAST(100.00 AS DECIMAL(10,2))),
  ('o1502', 'u21', 'p02', 1, CAST(90.00 AS DECIMAL(10,2))),
  ('o1503', 'u22', 'p03', 1, CAST(50.00 AS DECIMAL(10,2))),
  ('o1504', 'u23', 'p04', 1, CAST(70.00 AS DECIMAL(10,2))),
  ('o1504', 'u23', 'p04', 1, CAST(80.00 AS DECIMAL(10,2)))
AS t(order_id, user_id, product_id, item_cnt, item_amount);

-- ---------------------------------------------------------------------------
-- Order channels: ods_order_channel_di
-- ---------------------------------------------------------------------------

INSERT OVERWRITE TABLE ods_order_channel_di PARTITION (dt='2026-03-01')
SELECT order_id, user_id, channel_id
FROM VALUES
  ('o1001', 'u10', 'ch01'),
  ('o1002', 'u11', 'ch02'),
  ('o1003', 'u12', 'ch04')
AS t(order_id, user_id, channel_id);

INSERT OVERWRITE TABLE ods_order_channel_di PARTITION (dt='2026-03-02')
SELECT order_id, user_id, channel_id
FROM VALUES
  ('o1101', 'u10', 'ch01'),
  ('o1102', 'u13', 'ch03'),
  ('o1103', 'u14', 'ch03'),
  ('o1104', 'u15', 'ch02')
AS t(order_id, user_id, channel_id);

INSERT OVERWRITE TABLE ods_order_channel_di PARTITION (dt='2026-03-03')
SELECT order_id, user_id, channel_id
FROM VALUES
  ('o1201', 'u10', 'ch01'),
  ('o1202', 'u11', 'ch02'),
  ('o1203', 'u16', 'ch04')
AS t(order_id, user_id, channel_id);

INSERT OVERWRITE TABLE ods_order_channel_di PARTITION (dt='2026-03-04')
SELECT order_id, user_id, channel_id
FROM VALUES
  ('o1301', 'u17', 'ch03'),
  ('o1302', 'u12', 'ch02'),
  ('o1303', 'u13', 'ch01')
AS t(order_id, user_id, channel_id);

INSERT OVERWRITE TABLE ods_order_channel_di PARTITION (dt='2026-03-05')
SELECT order_id, user_id, channel_id
FROM VALUES
  ('o2001', 'u10', 'ch01'),
  ('o2002', 'u11', 'ch03'),
  ('o2005', 'u14', 'ch02')
AS t(order_id, user_id, channel_id);

INSERT OVERWRITE TABLE ods_order_channel_di PARTITION (dt='2026-03-06')
SELECT order_id, user_id, channel_id
FROM VALUES
  ('o1401', 'u18', 'ch04'),
  ('o1402', 'u19', 'ch02'),
  ('o1403', 'u10', 'ch01')
AS t(order_id, user_id, channel_id);

INSERT OVERWRITE TABLE ods_order_channel_di PARTITION (dt='2026-03-07')
SELECT order_id, user_id, channel_id
FROM VALUES
  ('o1501', 'u20', 'ch01'),
  ('o1502', 'u21', 'ch03'),
  ('o1503', 'u22', 'ch02'),
  ('o1504', 'u23', 'ch04')
AS t(order_id, user_id, channel_id);
