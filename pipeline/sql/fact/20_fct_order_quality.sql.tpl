USE hive_demo;

SELECT 'fct_order_di row count check failed' AS err_msg
WHERE (
  SELECT COUNT(*)
  FROM fct_order_di
  WHERE dt = '__RUN_DT__'
) = 0;

SELECT 'fct_order_di duplicate order check failed' AS err_msg
WHERE EXISTS (
  SELECT order_id
  FROM fct_order_di
  WHERE dt = '__RUN_DT__'
  GROUP BY order_id
  HAVING COUNT(*) > 1
);

SELECT 'fct_order_di null key check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM fct_order_di
  WHERE dt = '__RUN_DT__'
    AND (
      order_id IS NULL
      OR TRIM(order_id) = ''
      OR user_id IS NULL
      OR TRIM(user_id) = ''
    )
);

SELECT 'fct_order_di negative amount check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM fct_order_di
  WHERE dt = '__RUN_DT__'
    AND amount < 0
);

WITH src AS (
  SELECT COUNT(*) AS row_cnt
  FROM dwd_order_clean_di
  WHERE dt = '__RUN_DT__'
),
fct AS (
  SELECT COUNT(*) AS row_cnt
  FROM fct_order_di
  WHERE dt = '__RUN_DT__'
)
SELECT 'fct_order_di dwd clean row count reconcile check failed' AS err_msg
FROM src
CROSS JOIN fct
WHERE src.row_cnt <> fct.row_cnt;

WITH src AS (
  SELECT CAST(SUM(amount) AS DECIMAL(10,2)) AS gmv
  FROM dwd_order_clean_di
  WHERE dt = '__RUN_DT__'
),
fct AS (
  SELECT CAST(SUM(amount) AS DECIMAL(10,2)) AS gmv
  FROM fct_order_di
  WHERE dt = '__RUN_DT__'
)
SELECT 'fct_order_di dwd clean gmv reconcile check failed' AS err_msg
FROM src
CROSS JOIN fct
WHERE COALESCE(src.gmv, 0) <> COALESCE(fct.gmv, 0);
