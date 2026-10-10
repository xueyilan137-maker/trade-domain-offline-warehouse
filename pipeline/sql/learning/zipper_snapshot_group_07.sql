USE hive_demo;

-- 第七组：拉链表 / 快照表 SQL 强化
--
-- 场景：
-- hist_current 表示昨天拉链表中 is_current=1 的当前记录。
-- today_source 表示今天从业务系统同步来的用户最新状态。
--
-- 目标：
-- 1. 找出 unchanged：今天没变化的老用户
-- 2. 找出 changed：今天属性发生变化的老用户
-- 3. 找出 new_user：今天新增用户
-- 4. 生成 closed：被关闭的旧记录
-- 5. 生成 opened：新打开的当前记录

WITH hist_current AS (
  SELECT 'u01' AS user_id, 'Alice' AS user_name, 'silver' AS user_level, '2026-03-01' AS start_date, '9999-12-31' AS end_date, 1 AS is_current
  UNION ALL
  SELECT 'u02', 'Bob', 'gold', '2026-03-01', '9999-12-31', 1
  UNION ALL
  SELECT 'u03', 'Cindy', 'normal', '2026-03-02', '9999-12-31', 1
),
today_source AS (
  SELECT 'u01' AS user_id, 'Alice' AS user_name, 'gold' AS user_level, '2026-03-05' AS dt
  UNION ALL
  SELECT 'u02', 'Bob', 'gold', '2026-03-05'
  UNION ALL
  SELECT 'u04', 'David', 'normal', '2026-03-05'
),
joined AS (
  SELECT
    COALESCE(h.user_id, t.user_id) AS user_id,
    h.user_name AS hist_user_name,
    h.user_level AS hist_user_level,
    h.start_date AS hist_start_date,
    h.end_date AS hist_end_date,
    h.is_current AS hist_is_current,
    t.user_name AS today_user_name,
    t.user_level AS today_user_level,
    t.dt AS today_dt,
    CASE
      WHEN h.user_id IS NOT NULL
       AND t.user_id IS NOT NULL
       AND h.user_name = t.user_name
       AND h.user_level = t.user_level
        THEN 'unchanged'
      WHEN h.user_id IS NOT NULL
       AND t.user_id IS NOT NULL
       AND (
            h.user_name <> t.user_name
         OR h.user_level <> t.user_level
       )
        THEN 'changed'
      WHEN h.user_id IS NULL
       AND t.user_id IS NOT NULL
        THEN 'new_user'
      WHEN h.user_id IS NOT NULL
       AND t.user_id IS NULL
        THEN 'missing_today'
      ELSE 'unknown'
    END AS change_type
  FROM hist_current h
  FULL OUTER JOIN today_source t
    ON h.user_id = t.user_id
),
unchanged AS (
  SELECT
    'unchanged_keep_current' AS action_type,
    user_id,
    hist_user_name AS user_name,
    hist_user_level AS user_level,
    hist_start_date AS start_date,
    hist_end_date AS end_date,
    hist_is_current AS is_current
  FROM joined
  WHERE change_type = 'unchanged'
),
closed AS (
  SELECT
    'changed_close_old' AS action_type,
    user_id,
    hist_user_name AS user_name,
    hist_user_level AS user_level,
    hist_start_date AS start_date,
    DATE_SUB(today_dt, 1) AS end_date,
    0 AS is_current
  FROM joined
  WHERE change_type = 'changed'
),
opened AS (
  SELECT
    CASE
      WHEN change_type = 'changed' THEN 'changed_open_new'
      WHEN change_type = 'new_user' THEN 'new_user_open'
    END AS action_type,
    user_id,
    today_user_name AS user_name,
    today_user_level AS user_level,
    today_dt AS start_date,
    '9999-12-31' AS end_date,
    1 AS is_current
  FROM joined
  WHERE change_type IN ('changed', 'new_user')
),
missing_today AS (
  SELECT
    'missing_today_keep_current' AS action_type,
    user_id,
    hist_user_name AS user_name,
    hist_user_level AS user_level,
    hist_start_date AS start_date,
    hist_end_date AS end_date,
    hist_is_current AS is_current
  FROM joined
  WHERE change_type = 'missing_today'
),
zipper_new_current AS (
  SELECT * FROM unchanged
  UNION ALL
  SELECT * FROM closed
  UNION ALL
  SELECT * FROM opened
  UNION ALL
  SELECT * FROM missing_today
)
SELECT
  action_type,
  user_id,
  user_name,
  user_level,
  start_date,
  end_date,
  is_current
FROM zipper_new_current
ORDER BY user_id, action_type;
