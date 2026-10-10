USE hive_demo;

WITH source_rows AS (
  SELECT
    TRIM(user_id) AS user_id,
    TRIM(user_name) AS user_name,
    UPPER(TRIM(user_level)) AS user_level
  FROM ods_user_info_di
  WHERE dt = '__RUN_DT__'
),
valid_rows AS (
  SELECT
    user_id,
    user_name,
    user_level
  FROM source_rows
  WHERE user_id IS NOT NULL
    AND user_id <> ''
    AND user_name IS NOT NULL
    AND user_name <> ''
    AND user_level IS NOT NULL
    AND user_level <> ''
),
deduped AS (
  SELECT
    user_id,
    user_name,
    user_level,
    ROW_NUMBER() OVER (
      PARTITION BY user_id
      ORDER BY user_name DESC, user_level DESC
    ) AS rn
  FROM valid_rows
)
INSERT OVERWRITE TABLE dwd_user_info_clean_di PARTITION (dt='__RUN_DT__')
SELECT
  user_id,
  user_name,
  user_level
FROM deduped
WHERE rn = 1;
