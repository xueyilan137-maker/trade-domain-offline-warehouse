CREATE DATABASE IF NOT EXISTS hive_demo;

USE hive_demo;

INSERT OVERWRITE TABLE ods_product_info_di PARTITION (dt='2026-03-05')
SELECT
  product_id,
  product_name,
  category_id,
  category_name,
  brand_name
FROM VALUES
  ('p01', 'Mouse', 'c01', 'Digital Accessories', 'Logitech'),
  ('p02', 'Keyboard', 'c01', 'Digital Accessories', 'Keychron'),
  ('p03', 'Bottle', 'c02', 'Daily Goods', 'Migo')
AS t(product_id, product_name, category_id, category_name, brand_name);

INSERT OVERWRITE TABLE ods_order_item_di PARTITION (dt='2026-03-05')
SELECT
  order_id,
  user_id,
  product_id,
  item_cnt,
  item_amount
FROM VALUES
  ('o2001', 'u10', 'p01', 1, CAST(40.00 AS DECIMAL(10,2))),
  ('o2001', 'u10', 'p02', 1, CAST(60.00 AS DECIMAL(10,2))),
  ('o2002', 'u11', 'p03', 1, CAST(90.00 AS DECIMAL(10,2))),
  ('o2005', 'u14', 'p01', 1, CAST(30.00 AS DECIMAL(10,2)))
AS t(order_id, user_id, product_id, item_cnt, item_amount);
