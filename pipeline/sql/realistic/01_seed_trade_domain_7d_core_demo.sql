CREATE DATABASE IF NOT EXISTS hive_demo;

USE hive_demo;

-- Trade domain realistic demo data.
-- Date range: 2026-03-01 ~ 2026-03-07.
-- Scope: orders, cancels, refunds and payments.

-- ---------------------------------------------------------------------------
-- Orders: dwd_order_p
-- ---------------------------------------------------------------------------

INSERT OVERWRITE TABLE dwd_order_p PARTITION (dt='2026-03-01')
SELECT order_id, user_id, order_date, amount
FROM VALUES
  ('o1001', 'u10', '2026-03-01', CAST(100.00 AS DECIMAL(10,2))),
  ('o1002', 'u11', '2026-03-01', CAST(80.00 AS DECIMAL(10,2))),
  ('o1003', 'u12', '2026-03-01', CAST(60.00 AS DECIMAL(10,2)))
AS t(order_id, user_id, order_date, amount);

INSERT OVERWRITE TABLE dwd_order_p PARTITION (dt='2026-03-02')
SELECT order_id, user_id, order_date, amount
FROM VALUES
  ('o1101', 'u10', '2026-03-02', CAST(120.00 AS DECIMAL(10,2))),
  ('o1102', 'u13', '2026-03-02', CAST(50.00 AS DECIMAL(10,2))),
  ('o1103', 'u14', '2026-03-02', CAST(70.00 AS DECIMAL(10,2))),
  ('o1104', 'u15', '2026-03-02', CAST(90.00 AS DECIMAL(10,2)))
AS t(order_id, user_id, order_date, amount);

INSERT OVERWRITE TABLE dwd_order_p PARTITION (dt='2026-03-03')
SELECT order_id, user_id, order_date, amount
FROM VALUES
  ('o1201', 'u10', '2026-03-03', CAST(200.00 AS DECIMAL(10,2))),
  ('o1202', 'u11', '2026-03-03', CAST(40.00 AS DECIMAL(10,2))),
  ('o1203', 'u16', '2026-03-03', CAST(150.00 AS DECIMAL(10,2)))
AS t(order_id, user_id, order_date, amount);

INSERT OVERWRITE TABLE dwd_order_p PARTITION (dt='2026-03-04')
SELECT order_id, user_id, order_date, amount
FROM VALUES
  ('o1301', 'u17', '2026-03-04', CAST(300.00 AS DECIMAL(10,2))),
  ('o1302', 'u12', '2026-03-04', CAST(88.00 AS DECIMAL(10,2))),
  ('o1303', 'u13', '2026-03-04', CAST(66.00 AS DECIMAL(10,2)))
AS t(order_id, user_id, order_date, amount);

INSERT OVERWRITE TABLE dwd_order_p PARTITION (dt='2026-03-05')
SELECT order_id, user_id, order_date, amount
FROM VALUES
  ('o2001', 'u10', '2026-03-05', CAST(100.00 AS DECIMAL(10,2))),
  ('o2002', 'u11', '2026-03-05', CAST(90.00 AS DECIMAL(10,2))),
  ('o2005', 'u14', '2026-03-05', CAST(30.00 AS DECIMAL(10,2)))
AS t(order_id, user_id, order_date, amount);

INSERT OVERWRITE TABLE dwd_order_p PARTITION (dt='2026-03-06')
SELECT order_id, user_id, order_date, amount
FROM VALUES
  ('o1401', 'u18', '2026-03-05', CAST(75.00 AS DECIMAL(10,2))),
  ('o1402', 'u19', '2026-03-06', CAST(180.00 AS DECIMAL(10,2))),
  ('o1403', 'u10', '2026-03-06', CAST(45.00 AS DECIMAL(10,2)))
AS t(order_id, user_id, order_date, amount);

INSERT OVERWRITE TABLE dwd_order_p PARTITION (dt='2026-03-07')
SELECT order_id, user_id, order_date, amount
FROM VALUES
  ('o1501', 'u20', '2026-03-07', CAST(100.00 AS DECIMAL(10,2))),
  ('o1502', 'u21', '2026-03-07', CAST(90.00 AS DECIMAL(10,2))),
  ('o1503', 'u22', '2026-03-07', CAST(50.00 AS DECIMAL(10,2))),
  ('o1504', 'u23', '2026-03-07', CAST(70.00 AS DECIMAL(10,2))),
  ('o1504', 'u23', '2026-03-07', CAST(80.00 AS DECIMAL(10,2))),
  ('', 'u24', '2026-03-07', CAST(60.00 AS DECIMAL(10,2))),
  ('o1506', '', '2026-03-07', CAST(40.00 AS DECIMAL(10,2))),
  ('o1507', 'u25', '2026-03-07', CAST(-20.00 AS DECIMAL(10,2)))
AS t(order_id, user_id, order_date, amount);

-- ---------------------------------------------------------------------------
-- Cancels: dwd_order_cancel_p
-- ---------------------------------------------------------------------------

INSERT OVERWRITE TABLE dwd_order_cancel_p PARTITION (dt='2026-03-01')
SELECT
  CAST(NULL AS STRING) AS order_id,
  CAST(NULL AS STRING) AS user_id,
  CAST(NULL AS STRING) AS cancel_date,
  CAST(NULL AS STRING) AS cancel_reason
WHERE 1 = 0;

INSERT OVERWRITE TABLE dwd_order_cancel_p PARTITION (dt='2026-03-02')
SELECT order_id, user_id, cancel_date, cancel_reason
FROM VALUES
  ('o1102', 'u13', '2026-03-02', 'user_cancel'),
  ('o1103', 'u14', '2026-03-02', 'timeout_cancel')
AS t(order_id, user_id, cancel_date, cancel_reason);

INSERT OVERWRITE TABLE dwd_order_cancel_p PARTITION (dt='2026-03-03')
SELECT
  CAST(NULL AS STRING) AS order_id,
  CAST(NULL AS STRING) AS user_id,
  CAST(NULL AS STRING) AS cancel_date,
  CAST(NULL AS STRING) AS cancel_reason
WHERE 1 = 0;

INSERT OVERWRITE TABLE dwd_order_cancel_p PARTITION (dt='2026-03-04')
SELECT
  CAST(NULL AS STRING) AS order_id,
  CAST(NULL AS STRING) AS user_id,
  CAST(NULL AS STRING) AS cancel_date,
  CAST(NULL AS STRING) AS cancel_reason
WHERE 1 = 0;

INSERT OVERWRITE TABLE dwd_order_cancel_p PARTITION (dt='2026-03-05')
SELECT order_id, user_id, cancel_date, cancel_reason
FROM VALUES
  ('o2002', 'u11', '2026-03-05', 'user_cancel')
AS t(order_id, user_id, cancel_date, cancel_reason);

INSERT OVERWRITE TABLE dwd_order_cancel_p PARTITION (dt='2026-03-06')
SELECT
  CAST(NULL AS STRING) AS order_id,
  CAST(NULL AS STRING) AS user_id,
  CAST(NULL AS STRING) AS cancel_date,
  CAST(NULL AS STRING) AS cancel_reason
WHERE 1 = 0;

INSERT OVERWRITE TABLE dwd_order_cancel_p PARTITION (dt='2026-03-07')
SELECT
  CAST(NULL AS STRING) AS order_id,
  CAST(NULL AS STRING) AS user_id,
  CAST(NULL AS STRING) AS cancel_date,
  CAST(NULL AS STRING) AS cancel_reason
WHERE 1 = 0;

-- ---------------------------------------------------------------------------
-- Refunds: dwd_order_refund_p
-- ---------------------------------------------------------------------------

INSERT OVERWRITE TABLE dwd_order_refund_p PARTITION (dt='2026-03-01')
SELECT
  CAST(NULL AS STRING) AS order_id,
  CAST(NULL AS STRING) AS user_id,
  CAST(NULL AS STRING) AS refund_date,
  CAST(NULL AS DECIMAL(10,2)) AS refund_amount,
  CAST(NULL AS STRING) AS refund_reason
WHERE 1 = 0;

INSERT OVERWRITE TABLE dwd_order_refund_p PARTITION (dt='2026-03-02')
SELECT
  CAST(NULL AS STRING) AS order_id,
  CAST(NULL AS STRING) AS user_id,
  CAST(NULL AS STRING) AS refund_date,
  CAST(NULL AS DECIMAL(10,2)) AS refund_amount,
  CAST(NULL AS STRING) AS refund_reason
WHERE 1 = 0;

INSERT OVERWRITE TABLE dwd_order_refund_p PARTITION (dt='2026-03-03')
SELECT order_id, user_id, refund_date, refund_amount, refund_reason
FROM VALUES
  ('o1201', 'u10', '2026-03-03', CAST(50.00 AS DECIMAL(10,2)), 'partial_refund')
AS t(order_id, user_id, refund_date, refund_amount, refund_reason);

INSERT OVERWRITE TABLE dwd_order_refund_p PARTITION (dt='2026-03-04')
SELECT order_id, user_id, refund_date, refund_amount, refund_reason
FROM VALUES
  ('o1301', 'u17', '2026-03-04', CAST(300.00 AS DECIMAL(10,2)), 'full_refund')
AS t(order_id, user_id, refund_date, refund_amount, refund_reason);

INSERT OVERWRITE TABLE dwd_order_refund_p PARTITION (dt='2026-03-05')
SELECT order_id, user_id, refund_date, refund_amount, refund_reason
FROM VALUES
  ('o2001', 'u10', '2026-03-05', CAST(20.00 AS DECIMAL(10,2)), 'partial_refund')
AS t(order_id, user_id, refund_date, refund_amount, refund_reason);

INSERT OVERWRITE TABLE dwd_order_refund_p PARTITION (dt='2026-03-06')
SELECT order_id, user_id, refund_date, refund_amount, refund_reason
FROM VALUES
  ('o1303', 'u13', '2026-03-06', CAST(10.00 AS DECIMAL(10,2)), 'partial_refund_cross_day')
AS t(order_id, user_id, refund_date, refund_amount, refund_reason);

INSERT OVERWRITE TABLE dwd_order_refund_p PARTITION (dt='2026-03-07')
SELECT order_id, user_id, refund_date, refund_amount, refund_reason
FROM VALUES
  ('o1503', 'u22', '2026-03-07', CAST(80.00 AS DECIMAL(10,2)), 'refund_amount_over_order')
AS t(order_id, user_id, refund_date, refund_amount, refund_reason);

-- ---------------------------------------------------------------------------
-- Payments: dwd_payment_p
-- ---------------------------------------------------------------------------

INSERT OVERWRITE TABLE dwd_payment_p PARTITION (dt='2026-03-01')
SELECT payment_id, order_id, user_id, pay_date, pay_amount, pay_status
FROM VALUES
  ('p1001', 'o1001', 'u10', '2026-03-01', CAST(100.00 AS DECIMAL(10,2)), 'SUCCESS'),
  ('p1002', 'o1002', 'u11', '2026-03-01', CAST(80.00 AS DECIMAL(10,2)), 'SUCCESS')
AS t(payment_id, order_id, user_id, pay_date, pay_amount, pay_status);

INSERT OVERWRITE TABLE dwd_payment_p PARTITION (dt='2026-03-02')
SELECT payment_id, order_id, user_id, pay_date, pay_amount, pay_status
FROM VALUES
  ('p1101', 'o1101', 'u10', '2026-03-02', CAST(120.00 AS DECIMAL(10,2)), 'SUCCESS'),
  ('p1104', 'o1104', 'u15', '2026-03-02', CAST(90.00 AS DECIMAL(10,2)), 'SUCCESS')
AS t(payment_id, order_id, user_id, pay_date, pay_amount, pay_status);

INSERT OVERWRITE TABLE dwd_payment_p PARTITION (dt='2026-03-03')
SELECT payment_id, order_id, user_id, pay_date, pay_amount, pay_status
FROM VALUES
  ('p1201', 'o1201', 'u10', '2026-03-03', CAST(200.00 AS DECIMAL(10,2)), 'SUCCESS'),
  ('p1202', 'o1202', 'u11', '2026-03-03', CAST(40.00 AS DECIMAL(10,2)), 'SUCCESS'),
  ('p1203', 'o1203', 'u16', '2026-03-03', CAST(150.00 AS DECIMAL(10,2)), 'SUCCESS')
AS t(payment_id, order_id, user_id, pay_date, pay_amount, pay_status);

INSERT OVERWRITE TABLE dwd_payment_p PARTITION (dt='2026-03-04')
SELECT payment_id, order_id, user_id, pay_date, pay_amount, pay_status
FROM VALUES
  ('p1301', 'o1301', 'u17', '2026-03-04', CAST(300.00 AS DECIMAL(10,2)), 'SUCCESS'),
  ('p1302', 'o1302', 'u12', '2026-03-04', CAST(80.00 AS DECIMAL(10,2)), 'SUCCESS'),
  ('p1303', 'o1303', 'u13', '2026-03-04', CAST(66.00 AS DECIMAL(10,2)), 'SUCCESS')
AS t(payment_id, order_id, user_id, pay_date, pay_amount, pay_status);

INSERT OVERWRITE TABLE dwd_payment_p PARTITION (dt='2026-03-05')
SELECT payment_id, order_id, user_id, pay_date, pay_amount, pay_status
FROM VALUES
  ('p2001', 'o2001', 'u10', '2026-03-05', CAST(100.00 AS DECIMAL(10,2)), 'SUCCESS'),
  ('p2005', 'o2005', 'u14', '2026-03-05', CAST(30.00 AS DECIMAL(10,2)), 'SUCCESS')
AS t(payment_id, order_id, user_id, pay_date, pay_amount, pay_status);

INSERT OVERWRITE TABLE dwd_payment_p PARTITION (dt='2026-03-06')
SELECT payment_id, order_id, user_id, pay_date, pay_amount, pay_status
FROM VALUES
  ('p1401', 'o1401', 'u18', '2026-03-06', CAST(75.00 AS DECIMAL(10,2)), 'SUCCESS'),
  ('p1402', 'o1402', 'u19', '2026-03-06', CAST(180.00 AS DECIMAL(10,2)), 'SUCCESS'),
  ('p1403', 'o1403', 'u10', '2026-03-06', CAST(45.00 AS DECIMAL(10,2)), 'SUCCESS')
AS t(payment_id, order_id, user_id, pay_date, pay_amount, pay_status);

INSERT OVERWRITE TABLE dwd_payment_p PARTITION (dt='2026-03-07')
SELECT payment_id, order_id, user_id, pay_date, pay_amount, pay_status
FROM VALUES
  ('p1501', 'o1501', 'u20', '2026-03-07', CAST(100.00 AS DECIMAL(10,2)), 'SUCCESS'),
  ('p1502', 'o1502', 'u21', '2026-03-07', CAST(100.00 AS DECIMAL(10,2)), 'SUCCESS'),
  ('p1503', 'o1503', 'u22', '2026-03-07', CAST(50.00 AS DECIMAL(10,2)), 'SUCCESS'),
  ('p1504', 'o1504', 'u23', '2026-03-07', CAST(80.00 AS DECIMAL(10,2)), 'SUCCESS')
AS t(payment_id, order_id, user_id, pay_date, pay_amount, pay_status);
