USE hive_demo;

-- 第八组：复杂 SQL 综合题（练习版）
--
-- 要求：
-- 1. 不要改动 base_orders / payments / refunds / user_level_snapshot 四个 CTE。
-- 2. 在 TODO 区域补全 SQL。
-- 3. 目标是输出两个结果：
--    A. trade_day_metrics：交易域日指标
--    B. user_level_repurchase_metrics：用户等级复购指标

WITH base_orders AS (
  SELECT '2026-03-01' AS dt, 'o1001' AS order_id, 'u01' AS user_id, CAST(100.00 AS DECIMAL(10,2)) AS amount, 'VALID' AS order_status
  UNION ALL
  SELECT '2026-03-01', 'o1002', 'u02', CAST(80.00 AS DECIMAL(10,2)), 'CANCELLED'
  UNION ALL
  SELECT '2026-03-01', 'o1003', 'u03', CAST(60.00 AS DECIMAL(10,2)), 'VALID'
  UNION ALL
  SELECT '2026-03-02', 'o2001', 'u01', CAST(120.00 AS DECIMAL(10,2)), 'VALID'
  UNION ALL
  SELECT '2026-03-02', 'o2002', 'u02', CAST(50.00 AS DECIMAL(10,2)), 'VALID'
  UNION ALL
  SELECT '2026-03-02', 'o2003', 'u04', CAST(90.00 AS DECIMAL(10,2)), 'VALID'
),
payments AS (
  SELECT '2026-03-01' AS dt, 'p01' AS payment_id, 'o1001' AS order_id, CAST(100.00 AS DECIMAL(10,2)) AS pay_amount
  UNION ALL
  SELECT '2026-03-01', 'p02', 'o1003', CAST(60.00 AS DECIMAL(10,2))
  UNION ALL
  SELECT '2026-03-02', 'p03', 'o2001', CAST(120.00 AS DECIMAL(10,2))
  UNION ALL
  SELECT '2026-03-02', 'p04', 'o2002', CAST(50.00 AS DECIMAL(10,2))
),
refunds AS (
  SELECT '2026-03-01' AS dt, 'o1001' AS order_id, CAST(20.00 AS DECIMAL(10,2)) AS refund_amount
  UNION ALL
  SELECT '2026-03-02', 'o2001', CAST(30.00 AS DECIMAL(10,2))
),
user_level_snapshot AS (
  SELECT '2026-03-01' AS dt, 'u01' AS user_id, 'gold' AS user_level
  UNION ALL
  SELECT '2026-03-01', 'u02', 'silver'
  UNION ALL
  SELECT '2026-03-01', 'u03', 'normal'
  UNION ALL
  SELECT '2026-03-02', 'u01', 'gold'
  UNION ALL
  SELECT '2026-03-02', 'u02', 'silver'
  UNION ALL
  SELECT '2026-03-02', 'u04', 'normal'
),

-- TODO A:
-- 计算 trade_day_metrics，输出字段：
-- dt
-- raw_order_cnt
-- valid_order_cnt
-- cancel_order_cnt
-- raw_gmv
-- gross_valid_gmv
-- pay_order_cnt
-- pay_amount
-- refund_order_cnt
-- refund_amount
-- net_gmv
-- pay_success_rate = pay_order_cnt / valid_order_cnt
-- refund_order_rate = refund_order_cnt / valid_order_cnt

trade_day_metrics AS (
  SELECT
    'TODO' AS dt
),

-- TODO B:
-- 计算 user_level_repurchase_metrics，输出字段：
-- user_level
-- first_order_users
-- repurchase_users
-- repurchase_rate
-- valid_gmv
--
-- 口径：
-- 1. 只看 VALID 订单。
-- 2. 用户首单 = 用户第一笔有效订单。
-- 3. 复购用户 = 有效订单数 >= 2 的用户。
-- 4. 用户等级取用户首单日期当天的等级。

user_level_repurchase_metrics AS (
  SELECT
    'TODO' AS user_level
)

SELECT
  'A_trade_day_metrics' AS result_name,
  CAST(dt AS STRING) AS col_1,
  CAST(raw_order_cnt AS STRING) AS col_2,
  CAST(valid_order_cnt AS STRING) AS col_3,
  CAST(cancel_order_cnt AS STRING) AS col_4,
  CAST(raw_gmv AS STRING) AS col_5,
  CAST(gross_valid_gmv AS STRING) AS col_6,
  CAST(pay_order_cnt AS STRING) AS col_7,
  CAST(pay_amount AS STRING) AS col_8,
  CAST(refund_order_cnt AS STRING) AS col_9,
  CAST(refund_amount AS STRING) AS col_10,
  CAST(net_gmv AS STRING) AS col_11,
  CAST(pay_success_rate AS STRING) AS col_12,
  CAST(refund_order_rate AS STRING) AS col_13
FROM trade_day_metrics
UNION ALL
SELECT
  'B_user_level_repurchase_metrics' AS result_name,
  CAST(user_level AS STRING) AS col_1,
  CAST(first_order_users AS STRING) AS col_2,
  CAST(repurchase_users AS STRING) AS col_3,
  CAST(repurchase_rate AS STRING) AS col_4,
  CAST(valid_gmv AS STRING) AS col_5,
  NULL AS col_6,
  NULL AS col_7,
  NULL AS col_8,
  NULL AS col_9,
  NULL AS col_10,
  NULL AS col_11,
  NULL AS col_12,
  NULL AS col_13
FROM user_level_repurchase_metrics;
