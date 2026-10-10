CREATE DATABASE IF NOT EXISTS hive_demo;

USE hive_demo;

-- Trade domain realistic dimension demo data.
-- Date range: 2026-03-01 ~ 2026-03-07.
-- Scope: users, products and channels.

-- ---------------------------------------------------------------------------
-- Users: ods_user_info_di
-- ---------------------------------------------------------------------------

INSERT OVERWRITE TABLE ods_user_info_di PARTITION (dt='2026-03-01')
SELECT user_id, user_name, user_level
FROM VALUES
  ('u10', 'Alice', 'GOLD'),
  ('u11', 'Bob', 'SILVER'),
  ('u12', 'Cathy', 'NORMAL')
AS t(user_id, user_name, user_level);

INSERT OVERWRITE TABLE ods_user_info_di PARTITION (dt='2026-03-02')
SELECT user_id, user_name, user_level
FROM VALUES
  ('u10', 'Alice', 'GOLD'),
  ('u13', 'David', 'NORMAL'),
  ('u14', 'Emma', 'NORMAL'),
  ('u15', 'Frank', 'SILVER')
AS t(user_id, user_name, user_level);

INSERT OVERWRITE TABLE ods_user_info_di PARTITION (dt='2026-03-03')
SELECT user_id, user_name, user_level
FROM VALUES
  ('u10', 'Alice', 'VIP'),
  ('u11', 'Bob', 'SILVER'),
  ('u16', 'Grace', 'NORMAL')
AS t(user_id, user_name, user_level);

INSERT OVERWRITE TABLE ods_user_info_di PARTITION (dt='2026-03-04')
SELECT user_id, user_name, user_level
FROM VALUES
  ('u17', 'Helen', 'VIP'),
  ('u12', 'Cathy', 'NORMAL'),
  ('u13', 'David', 'NORMAL')
AS t(user_id, user_name, user_level);

INSERT OVERWRITE TABLE ods_user_info_di PARTITION (dt='2026-03-05')
SELECT user_id, user_name, user_level
FROM VALUES
  ('u10', 'Alice', 'GOLD'),
  ('u11', 'Bob', 'SILVER'),
  ('u14', 'Emma', 'NORMAL')
AS t(user_id, user_name, user_level);

INSERT OVERWRITE TABLE ods_user_info_di PARTITION (dt='2026-03-06')
SELECT user_id, user_name, user_level
FROM VALUES
  ('u18', 'Ivy', 'NORMAL'),
  ('u19', 'Jack', 'SILVER'),
  ('u10', 'Alice', 'GOLD')
AS t(user_id, user_name, user_level);

INSERT OVERWRITE TABLE ods_user_info_di PARTITION (dt='2026-03-07')
SELECT user_id, user_name, user_level
FROM VALUES
  ('u20', 'Kelly', 'NORMAL'),
  ('u21', 'Leo', 'SILVER'),
  ('u22', 'Mia', 'NORMAL'),
  ('u23', 'Nick', 'NORMAL'),
  ('u24', 'Olivia', 'NORMAL'),
  ('u25', 'Peter', 'NORMAL')
AS t(user_id, user_name, user_level);

-- ---------------------------------------------------------------------------
-- Products: ods_product_info_di
-- ---------------------------------------------------------------------------

INSERT OVERWRITE TABLE ods_product_info_di PARTITION (dt='2026-03-01')
SELECT product_id, product_name, category_id, category_name, brand_name
FROM VALUES
  ('p01', 'Mouse', 'c01', 'Digital Accessories', 'Logitech'),
  ('p02', 'Keyboard', 'c01', 'Digital Accessories', 'Keychron'),
  ('p03', 'Bottle', 'c02', 'Daily Goods', 'Migo'),
  ('p04', 'T-Shirt', 'c03', 'Clothing', 'Uniqlo'),
  ('p05', 'Book', 'c04', 'Books', 'OReilly')
AS t(product_id, product_name, category_id, category_name, brand_name);

INSERT OVERWRITE TABLE ods_product_info_di PARTITION (dt='2026-03-02')
SELECT product_id, product_name, category_id, category_name, brand_name
FROM VALUES
  ('p01', 'Mouse', 'c01', 'Digital Accessories', 'Logitech'),
  ('p02', 'Keyboard', 'c01', 'Digital Accessories', 'Keychron'),
  ('p03', 'Bottle', 'c02', 'Daily Goods', 'Migo'),
  ('p04', 'T-Shirt', 'c03', 'Clothing', 'Uniqlo'),
  ('p05', 'Book', 'c04', 'Books', 'OReilly')
AS t(product_id, product_name, category_id, category_name, brand_name);

INSERT OVERWRITE TABLE ods_product_info_di PARTITION (dt='2026-03-03')
SELECT product_id, product_name, category_id, category_name, brand_name
FROM VALUES
  ('p01', 'Mouse', 'c01', 'Digital Accessories', 'Logitech'),
  ('p02', 'Keyboard', 'c01', 'Digital Accessories', 'Keychron'),
  ('p03', 'Bottle', 'c02', 'Daily Goods', 'Migo'),
  ('p04', 'T-Shirt', 'c03', 'Clothing', 'Uniqlo'),
  ('p05', 'Book', 'c04', 'Books', 'OReilly')
AS t(product_id, product_name, category_id, category_name, brand_name);

INSERT OVERWRITE TABLE ods_product_info_di PARTITION (dt='2026-03-04')
SELECT product_id, product_name, category_id, category_name, brand_name
FROM VALUES
  ('p01', 'Mouse', 'c01', 'Digital Accessories', 'Logitech'),
  ('p02', 'Keyboard', 'c01', 'Digital Accessories', 'Keychron'),
  ('p03', 'Bottle', 'c02', 'Daily Goods', 'Migo'),
  ('p04', 'T-Shirt', 'c03', 'Clothing', 'Uniqlo'),
  ('p05', 'Book', 'c04', 'Books', 'OReilly')
AS t(product_id, product_name, category_id, category_name, brand_name);

INSERT OVERWRITE TABLE ods_product_info_di PARTITION (dt='2026-03-05')
SELECT product_id, product_name, category_id, category_name, brand_name
FROM VALUES
  ('p01', 'Mouse', 'c01', 'Digital Accessories', 'Logitech'),
  ('p02', 'Keyboard', 'c01', 'Digital Accessories', 'Keychron'),
  ('p03', 'Bottle', 'c02', 'Daily Goods', 'Migo'),
  ('p04', 'T-Shirt', 'c03', 'Clothing', 'Uniqlo'),
  ('p05', 'Book', 'c04', 'Books', 'OReilly')
AS t(product_id, product_name, category_id, category_name, brand_name);

INSERT OVERWRITE TABLE ods_product_info_di PARTITION (dt='2026-03-06')
SELECT product_id, product_name, category_id, category_name, brand_name
FROM VALUES
  ('p01', 'Mouse', 'c01', 'Digital Accessories', 'Logitech'),
  ('p02', 'Keyboard', 'c01', 'Digital Accessories', 'Keychron'),
  ('p03', 'Bottle', 'c02', 'Daily Goods', 'Migo'),
  ('p04', 'T-Shirt', 'c03', 'Clothing', 'Uniqlo'),
  ('p05', 'Book', 'c04', 'Books', 'OReilly')
AS t(product_id, product_name, category_id, category_name, brand_name);

INSERT OVERWRITE TABLE ods_product_info_di PARTITION (dt='2026-03-07')
SELECT product_id, product_name, category_id, category_name, brand_name
FROM VALUES
  ('p01', 'Mouse', 'c01', 'Digital Accessories', 'Logitech'),
  ('p02', 'Keyboard', 'c01', 'Digital Accessories', 'Keychron'),
  ('p03', 'Bottle', 'c02', 'Daily Goods', 'Migo'),
  ('p04', 'T-Shirt', 'c03', 'Clothing', 'Uniqlo'),
  ('p05', 'Book', 'c04', 'Books', 'OReilly')
AS t(product_id, product_name, category_id, category_name, brand_name);

-- ---------------------------------------------------------------------------
-- Channels: ods_channel_info_di
-- ---------------------------------------------------------------------------

INSERT OVERWRITE TABLE ods_channel_info_di PARTITION (dt='2026-03-01')
SELECT channel_id, channel_name, channel_type
FROM VALUES
  ('ch01', 'App', 'Owned'),
  ('ch02', 'Mini Program', 'Owned'),
  ('ch03', 'Ad Campaign', 'Paid'),
  ('ch04', 'Organic Search', 'Free')
AS t(channel_id, channel_name, channel_type);

INSERT OVERWRITE TABLE ods_channel_info_di PARTITION (dt='2026-03-02')
SELECT channel_id, channel_name, channel_type
FROM VALUES
  ('ch01', 'App', 'Owned'),
  ('ch02', 'Mini Program', 'Owned'),
  ('ch03', 'Ad Campaign', 'Paid'),
  ('ch04', 'Organic Search', 'Free')
AS t(channel_id, channel_name, channel_type);

INSERT OVERWRITE TABLE ods_channel_info_di PARTITION (dt='2026-03-03')
SELECT channel_id, channel_name, channel_type
FROM VALUES
  ('ch01', 'App', 'Owned'),
  ('ch02', 'Mini Program', 'Owned'),
  ('ch03', 'Ad Campaign', 'Paid'),
  ('ch04', 'Organic Search', 'Free')
AS t(channel_id, channel_name, channel_type);

INSERT OVERWRITE TABLE ods_channel_info_di PARTITION (dt='2026-03-04')
SELECT channel_id, channel_name, channel_type
FROM VALUES
  ('ch01', 'App', 'Owned'),
  ('ch02', 'Mini Program', 'Owned'),
  ('ch03', 'Ad Campaign', 'Paid'),
  ('ch04', 'Organic Search', 'Free')
AS t(channel_id, channel_name, channel_type);

INSERT OVERWRITE TABLE ods_channel_info_di PARTITION (dt='2026-03-05')
SELECT channel_id, channel_name, channel_type
FROM VALUES
  ('ch01', 'App', 'Owned'),
  ('ch02', 'Mini Program', 'Owned'),
  ('ch03', 'Ad Campaign', 'Paid'),
  ('ch04', 'Organic Search', 'Free')
AS t(channel_id, channel_name, channel_type);

INSERT OVERWRITE TABLE ods_channel_info_di PARTITION (dt='2026-03-06')
SELECT channel_id, channel_name, channel_type
FROM VALUES
  ('ch01', 'App', 'Owned'),
  ('ch02', 'Mini Program', 'Owned'),
  ('ch03', 'Ad Campaign', 'Paid'),
  ('ch04', 'Organic Search', 'Free')
AS t(channel_id, channel_name, channel_type);

INSERT OVERWRITE TABLE ods_channel_info_di PARTITION (dt='2026-03-07')
SELECT channel_id, channel_name, channel_type
FROM VALUES
  ('ch01', 'App', 'Owned'),
  ('ch02', 'Mini Program', 'Owned'),
  ('ch03', 'Ad Campaign', 'Paid'),
  ('ch04', 'Organic Search', 'Free')
AS t(channel_id, channel_name, channel_type);
