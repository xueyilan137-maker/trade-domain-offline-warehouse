USE hive_demo;

SELECT 'dws_user_order_day_agg row count check failed' AS err_msg
WHERE (
  SELECT COUNT(*)
  FROM dws_user_order_day_agg
  WHERE dt = '__RUN_DT__'
) = 0;

SELECT 'dws_user_order_day_agg duplicate user check failed' AS err_msg
WHERE EXISTS (
  SELECT user_id
  FROM dws_user_order_day_agg
  WHERE dt = '__RUN_DT__'
  GROUP BY user_id
  HAVING COUNT(*) > 1
);

SELECT 'dws_user_order_day_agg negative metric check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM dws_user_order_day_agg
  WHERE dt = '__RUN_DT__'
    AND (
      order_cnt < 0
      OR order_amount < 0
      OR avg_order_amount < 0
    )
);

WITH fct AS (
  SELECT
    o.user_id,
    COUNT(*) AS order_cnt,
    CAST(SUM(o.amount) AS DECIMAL(10,2)) AS order_amount,
    CAST(ROUND(SUM(o.amount) / COUNT(*), 2) AS DECIMAL(10,2)) AS avg_order_amount
  FROM fct_order_di o
  JOIN fct_order_status_di s
    ON o.order_id = s.order_id
   AND o.dt = s.dt
  WHERE o.dt = '__RUN_DT__'
    AND s.order_status = 'VALID'
  GROUP BY o.user_id
),
dws AS (
  SELECT
    user_id,
    order_cnt,
    order_amount,
    avg_order_amount
  FROM dws_user_order_day_agg
  WHERE dt = '__RUN_DT__'
)
SELECT 'dws_user_order_day_agg user metric reconcile check failed' AS err_msg
FROM fct
FULL OUTER JOIN dws
  ON fct.user_id = dws.user_id
WHERE fct.user_id IS NULL
   OR dws.user_id IS NULL
   OR COALESCE(fct.order_cnt, 0) <> COALESCE(dws.order_cnt, 0)
   OR COALESCE(fct.order_amount, 0) <> COALESCE(dws.order_amount, 0)
   OR COALESCE(fct.avg_order_amount, 0) <> COALESCE(dws.avg_order_amount, 0);
