USE hive_demo;

INSERT OVERWRITE TABLE dim_product_snapshot_di PARTITION (dt='__RUN_DT__')
SELECT
  TRIM(product_id) AS product_id,
  TRIM(product_name) AS product_name,
  TRIM(category_id) AS category_id,
  TRIM(category_name) AS category_name,
  TRIM(brand_name) AS brand_name
FROM ods_product_info_di
WHERE dt = '__RUN_DT__'
  AND product_id IS NOT NULL
  AND TRIM(product_id) <> '';
