USE hive_demo;

-- 第六组：同比 / 环比 / 累计 / 滚动窗口
--
-- 学习目标：
-- 1. 日环比：今天 GMV vs 昨天 GMV
-- 2. 累计 GMV：从周期开始累计到当前日期
-- 3. 近 3 日滚动 GMV：当前日期及往前 2 天的 GMV
-- 4. 同比思想：当前日期 vs 去年同日

WITH trade_day AS (
  SELECT '2026-03-01' AS dt, CAST(100.00 AS DECIMAL(10,2)) AS gmv, 2 AS order_cnt, 2 AS user_cnt
  UNION ALL
  SELECT '2026-03-02', CAST(150.00 AS DECIMAL(10,2)), 3, 2
  UNION ALL
  SELECT '2026-03-03', CAST(120.00 AS DECIMAL(10,2)), 2, 2
  UNION ALL
  SELECT '2026-03-04', CAST(180.00 AS DECIMAL(10,2)), 4, 3
  UNION ALL
  SELECT '2026-03-05', CAST(200.00 AS DECIMAL(10,2)), 5, 4
  UNION ALL
  SELECT '2025-03-01', CAST(80.00 AS DECIMAL(10,2)), 1, 1
  UNION ALL
  SELECT '2025-03-02', CAST(120.00 AS DECIMAL(10,2)), 2, 2
  UNION ALL
  SELECT '2025-03-03', CAST(100.00 AS DECIMAL(10,2)), 2, 1
  UNION ALL
  SELECT '2025-03-04', CAST(160.00 AS DECIMAL(10,2)), 3, 2
  UNION ALL
  SELECT '2025-03-05', CAST(150.00 AS DECIMAL(10,2)), 3, 2
),
current_year AS (
  SELECT
    dt,
    gmv,
    order_cnt,
    user_cnt,

    -- 昨日 GMV：按日期排序，取上一行。
    LAG(gmv) OVER (
      ORDER BY dt
    ) AS prev_day_gmv,

    -- 从当前数据周期开始累计到当前行。
    SUM(gmv) OVER (
      ORDER BY dt
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_gmv,

    -- 近 3 日滚动 GMV：当前行 + 前 2 行。
    SUM(gmv) OVER (
      ORDER BY dt
      ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS rolling_3d_gmv,

    -- 近 3 日滚动平均 GMV。
    ROUND(
      AVG(gmv) OVER (
        ORDER BY dt
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
      ),
      2
    ) AS rolling_3d_avg_gmv
  FROM trade_day
  WHERE dt BETWEEN '2026-03-01' AND '2026-03-05'
),
yoy_base AS (
  SELECT
    cur.dt,
    cur.gmv,
    prev.gmv AS last_year_same_day_gmv
  FROM trade_day cur
  LEFT JOIN trade_day prev
    ON prev.dt = ADD_MONTHS(cur.dt, -12)
  WHERE cur.dt BETWEEN '2026-03-01' AND '2026-03-05'
),
final_metrics AS (
  SELECT
    c.dt,
    c.gmv,
    c.order_cnt,
    c.user_cnt,
    c.prev_day_gmv,
    c.gmv - COALESCE(c.prev_day_gmv, 0) AS gmv_day_diff,
    CASE
      WHEN c.prev_day_gmv IS NULL OR c.prev_day_gmv = 0 THEN CAST(0.0000 AS DECIMAL(10,4))
      ELSE ROUND((c.gmv - c.prev_day_gmv) / c.prev_day_gmv, 4)
    END AS gmv_day_rate,
    c.cumulative_gmv,
    c.rolling_3d_gmv,
    c.rolling_3d_avg_gmv,
    y.last_year_same_day_gmv,
    c.gmv - COALESCE(y.last_year_same_day_gmv, 0) AS gmv_yoy_diff,
    CASE
      WHEN y.last_year_same_day_gmv IS NULL OR y.last_year_same_day_gmv = 0 THEN CAST(0.0000 AS DECIMAL(10,4))
      ELSE ROUND((c.gmv - y.last_year_same_day_gmv) / y.last_year_same_day_gmv, 4)
    END AS gmv_yoy_rate
  FROM current_year c
  LEFT JOIN yoy_base y
    ON c.dt = y.dt
)
SELECT *
FROM final_metrics
ORDER BY dt;
