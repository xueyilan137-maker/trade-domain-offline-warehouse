USE hive_demo;

-- 指标聚合专题练习
-- 目标：基于订单 + 取消 + 退款样例数据，自己写 SQL 计算常见订单主题指标。
--
-- 练习方式：
-- 1. 不要改动 orders / cancels / refunds 三个 CTE。
-- 2. 在 final_metrics 这个 CTE 里补全 SQL。
-- 3. 最终 SELECT * FROM final_metrics。
--
-- 业务口径：
-- raw_order_cnt       = 清洗后订单总数
-- raw_order_users     = 清洗后下单用户数
-- raw_gmv             = 清洗后订单总金额
-- valid_order_cnt     = 未取消订单数
-- valid_order_users   = 未取消下单用户数
-- gross_valid_gmv     = 未取消订单原始 GMV
-- cancel_order_cnt    = 取消订单数
-- cancel_amount       = 取消订单金额
-- refund_order_cnt    = 有效订单中发生退款的订单数
-- refund_amount       = 有效订单退款金额
-- net_gmv             = 有效 GMV - 退款金额
-- avg_valid_order_amt = 有效订单客单价：gross_valid_gmv / valid_order_cnt
-- cancel_order_rate   = cancel_order_cnt / raw_order_cnt
-- refund_order_rate   = refund_order_cnt / valid_order_cnt
-- refund_gmv_rate     = refund_amount / gross_valid_gmv
--
-- 分母为 0 时，指标返回 0。

WITH orders AS (
  SELECT 'o1001' AS order_id, 'u01' AS user_id, CAST(100.00 AS DECIMAL(10,2)) AS amount
  UNION ALL
  SELECT 'o1002', 'u01', CAST(80.00 AS DECIMAL(10,2))
  UNION ALL
  SELECT 'o1003', 'u02', CAST(60.00 AS DECIMAL(10,2))
  UNION ALL
  SELECT 'o1004', 'u03', CAST(120.00 AS DECIMAL(10,2))
  UNION ALL
  SELECT 'o1005', 'u03', CAST(40.00 AS DECIMAL(10,2))
),
cancels AS (
  SELECT 'o1002' AS order_id, 'user_cancel' AS cancel_reason
  UNION ALL
  SELECT 'o1005', 'timeout_cancel'
),
refunds AS (
  SELECT 'o1001' AS order_id, CAST(20.00 AS DECIMAL(10,2)) AS refund_amount
  UNION ALL
  SELECT 'o1004', CAST(50.00 AS DECIMAL(10,2))
),
order_status AS (
  SELECT
    o.order_id,
    o.user_id,
    o.amount,
    CASE WHEN c.order_id IS NOT NULL THEN 1 ELSE 0 END AS is_cancelled,
    COALESCE(r.refund_amount, CAST(0.00 AS DECIMAL(10,2))) AS refund_amount
  FROM orders o
  LEFT JOIN cancels c
    ON o.order_id = c.order_id
  LEFT JOIN refunds r
    ON o.order_id = r.order_id
),
metric_base AS (
  SELECT
    COUNT(*) AS raw_order_cnt,
    COUNT(DISTINCT user_id) AS raw_order_users,
    SUM(amount) AS raw_gmv,
    SUM(CASE WHEN is_cancelled = 0 THEN 1 ELSE 0 END) AS valid_order_cnt,
    COUNT(DISTINCT CASE WHEN is_cancelled = 0 THEN user_id END) AS valid_order_users,
    SUM(CASE WHEN is_cancelled = 0 THEN amount ELSE 0 END) AS gross_valid_gmv,
    SUM(CASE WHEN is_cancelled = 1 THEN 1 ELSE 0 END) AS cancel_order_cnt,
    SUM(CASE WHEN is_cancelled = 1 THEN amount ELSE 0 END) AS cancel_amount,
    SUM(
      CASE
        WHEN is_cancelled = 0 AND refund_amount > 0 THEN 1
        ELSE 0
      END
    ) AS refund_order_cnt,
    SUM(
      CASE
        WHEN is_cancelled = 0 THEN refund_amount
        ELSE 0
      END
    ) AS refund_amount
  FROM order_status
),
final_metrics AS (
  SELECT
    raw_order_cnt,
    raw_order_users,
    raw_gmv,
    valid_order_cnt,
    valid_order_users,
    gross_valid_gmv,
    cancel_order_cnt,
    cancel_amount,
    refund_order_cnt,
    refund_amount,
    gross_valid_gmv - refund_amount AS net_gmv,
    CASE
      WHEN valid_order_cnt = 0 THEN CAST(0.0000 AS DECIMAL(10,4))
      ELSE ROUND(gross_valid_gmv / valid_order_cnt, 4)
    END AS avg_valid_order_amt,
    CASE
      WHEN raw_order_cnt = 0 THEN CAST(0.0000 AS DECIMAL(10,4))
      ELSE ROUND(cancel_order_cnt / raw_order_cnt, 4)
    END AS cancel_order_rate,
    CASE
      WHEN valid_order_cnt = 0 THEN CAST(0.0000 AS DECIMAL(10,4))
      ELSE ROUND(refund_order_cnt / valid_order_cnt, 4)
    END AS refund_order_rate,
    CASE
      WHEN gross_valid_gmv = 0 THEN CAST(0.0000 AS DECIMAL(10,4))
      ELSE ROUND(refund_amount / gross_valid_gmv, 4)
    END AS refund_gmv_rate
  FROM metric_base
)
SELECT *
FROM final_metrics;
