USE hive_demo;

WITH hist_closed AS (
  SELECT
    user_id,
    user_name,
    user_level,
    start_date,
    end_date,
    is_current
  FROM dim_user_zipper
  WHERE is_current = 0
),
hist_curr AS (
  SELECT
    user_id,
    user_name,
    user_level,
    start_date,
    end_date,
    is_current
  FROM dim_user_zipper
  WHERE is_current = 1
),
today AS (
  SELECT
    user_id,
    user_name,
    user_level
  FROM dwd_user_info_clean_di
  WHERE dt = '__RUN_DT__'
),
changed AS (
  SELECT
    t.user_id,
    t.user_name,
    t.user_level
  FROM today t
  JOIN hist_curr h
    ON t.user_id = h.user_id
  WHERE COALESCE(t.user_name, '') <> COALESCE(h.user_name, '')
     OR COALESCE(t.user_level, '') <> COALESCE(h.user_level, '')
),
carry_forward AS (
  SELECT
    h.user_id,
    h.user_name,
    h.user_level,
    h.start_date,
    h.end_date,
    h.is_current
  FROM hist_curr h
  LEFT JOIN changed c
    ON h.user_id = c.user_id
  WHERE c.user_id IS NULL
),
closed AS (
  SELECT
    h.user_id,
    h.user_name,
    h.user_level,
    h.start_date,
    DATE_FORMAT(DATE_SUB(TO_DATE('__RUN_DT__'), 1), 'yyyy-MM-dd') AS end_date,
    0 AS is_current
  FROM hist_curr h
  JOIN changed c
    ON h.user_id = c.user_id
),
new_user AS (
  SELECT
    t.user_id,
    t.user_name,
    t.user_level
  FROM today t
  LEFT ANTI JOIN hist_curr h
    ON t.user_id = h.user_id
),
opened AS (
  SELECT
    user_id,
    user_name,
    user_level,
    '__RUN_DT__' AS start_date,
    '9999-12-31' AS end_date,
    1 AS is_current
  FROM changed

  UNION ALL

  SELECT
    user_id,
    user_name,
    user_level,
    '__RUN_DT__' AS start_date,
    '9999-12-31' AS end_date,
    1 AS is_current
  FROM new_user
)
INSERT OVERWRITE TABLE dim_user_zipper_tmp
SELECT
  user_id,
  user_name,
  user_level,
  start_date,
  end_date,
  is_current
FROM hist_closed

UNION ALL

SELECT
  user_id,
  user_name,
  user_level,
  start_date,
  end_date,
  is_current
FROM carry_forward

UNION ALL

SELECT
  user_id,
  user_name,
  user_level,
  start_date,
  end_date,
  is_current
FROM closed

UNION ALL

SELECT
  user_id,
  user_name,
  user_level,
  start_date,
  end_date,
  is_current
FROM opened;

INSERT OVERWRITE TABLE dim_user_zipper
SELECT
  user_id,
  user_name,
  user_level,
  start_date,
  end_date,
  is_current
FROM dim_user_zipper_tmp;
