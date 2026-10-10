USE hive_demo;

WITH source_rows AS (
  SELECT
    TRIM(order_id) AS order_id,
    TRIM(user_id) AS user_id,
    TRIM(channel_id) AS channel_id
  FROM ods_order_channel_di
  WHERE dt = '__RUN_DT__'
),
valid_rows AS (
  SELECT
    order_id,
    user_id,
    channel_id
  FROM source_rows
  WHERE order_id IS NOT NULL
    AND order_id <> ''
    AND user_id IS NOT NULL
    AND user_id <> ''
    AND channel_id IS NOT NULL
    AND channel_id <> ''
),
deduped AS (
  SELECT
    order_id,
    user_id,
    channel_id,
    ROW_NUMBER() OVER (
      PARTITION BY order_id
      ORDER BY channel_id ASC, user_id ASC
    ) AS rn
  FROM valid_rows
)
INSERT OVERWRITE TABLE dwd_order_channel_clean_di PARTITION (dt='__RUN_DT__')
SELECT
  order_id,
  user_id,
  channel_id
FROM deduped
WHERE rn = 1;
