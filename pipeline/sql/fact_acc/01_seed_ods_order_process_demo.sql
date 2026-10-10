USE hive_demo;

INSERT OVERWRITE TABLE ods_order_process_di PARTITION (dt='2026-04-24')
SELECT
  order_id,
  user_id,
  create_date,
  pay_date,
  ship_date,
  finish_date,
  order_status
FROM VALUES
  ('o2001', 'u1001', '2026-04-24', null, null, null, 'CREATED'),
  ('o2002', 'u1002', '2026-04-24', '2026-04-24', null, null, 'PAID'),
  ('o2003', 'u1003', '2026-04-24', '2026-04-24', '2026-04-24', null, 'SHIPPED')
AS t(order_id, user_id, create_date, pay_date, ship_date, finish_date, order_status);

INSERT OVERWRITE TABLE ods_order_process_di PARTITION (dt='2026-04-25')
SELECT
  order_id,
  user_id,
  create_date,
  pay_date,
  ship_date,
  finish_date,
  order_status
FROM VALUES
  ('o2001', 'u1001', '2026-04-24', '2026-04-25', null, null, 'PAID'),
  ('o2002', 'u1002', '2026-04-24', '2026-04-24', '2026-04-25', null, 'SHIPPED'),
  ('o2003', 'u1003', '2026-04-24', '2026-04-24', '2026-04-24', '2026-04-25', 'FINISHED'),
  ('o2004', 'u1004', '2026-04-25', null, null, null, 'CREATED')
AS t(order_id, user_id, create_date, pay_date, ship_date, finish_date, order_status);

INSERT OVERWRITE TABLE ods_order_process_di PARTITION (dt='2026-04-26')
SELECT
  order_id,
  user_id,
  create_date,
  pay_date,
  ship_date,
  finish_date,
  order_status
FROM VALUES
  ('o2001', 'u1001', '2026-04-24', '2026-04-25', '2026-04-26', null, 'SHIPPED'),
  ('o2002', 'u1002', '2026-04-24', '2026-04-24', '2026-04-25', '2026-04-26', 'FINISHED'),
  ('o2003', 'u1003', '2026-04-24', '2026-04-24', '2026-04-24', '2026-04-25', 'FINISHED'),
  ('o2004', 'u1004', '2026-04-25', '2026-04-26', null, null, 'PAID')
AS t(order_id, user_id, create_date, pay_date, ship_date, finish_date, order_status);
