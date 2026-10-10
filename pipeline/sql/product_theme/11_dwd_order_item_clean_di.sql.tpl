USE hive_demo;

WITH source_rows AS (
  SELECT
    TRIM(order_id) AS order_id,
    TRIM(user_id) AS user_id,
    TRIM(product_id) AS product_id,
    item_cnt,
    item_amount
  FROM ods_order_item_di
  WHERE dt = '__RUN_DT__'
),
valid_rows AS (
  SELECT
    order_id,
    user_id,
    product_id,
    item_cnt,
    item_amount
  FROM source_rows
  WHERE order_id IS NOT NULL
    AND order_id <> ''
    AND user_id IS NOT NULL
    AND user_id <> ''
    AND product_id IS NOT NULL
    AND product_id <> ''
    AND item_cnt IS NOT NULL
    AND item_cnt > 0
    AND item_amount IS NOT NULL
    AND item_amount >= 0
),
deduped AS (
  SELECT
    order_id,
    user_id,
    product_id,
    item_cnt,
    item_amount,
    ROW_NUMBER() OVER (
      PARTITION BY order_id, product_id
      ORDER BY item_amount DESC, item_cnt DESC, user_id ASC
    ) AS rn
  FROM valid_rows
)
INSERT OVERWRITE TABLE dwd_order_item_clean_di PARTITION (dt='__RUN_DT__')
SELECT
  order_id,
  user_id,
  product_id,
  item_cnt,
  item_amount
FROM deduped
WHERE rn = 1;
