USE hive_demo;

WITH fct AS (
  SELECT
    COUNT(DISTINCT user_id) AS raw_order_users,
    COUNT(*) AS raw_order_cnt,
    CAST(SUM(amount) AS DECIMAL(10,2)) AS raw_gmv,

    COUNT(DISTINCT CASE WHEN order_status = 'VALID' THEN user_id END) AS valid_order_users,
    SUM(CASE WHEN order_status = 'VALID' THEN 1 ELSE 0 END) AS valid_order_cnt,
    CAST(SUM(CASE WHEN order_status = 'VALID' THEN amount ELSE 0 END) AS DECIMAL(10,2)) AS valid_gmv,

    COUNT(DISTINCT CASE WHEN order_status = 'CANCELLED' THEN user_id END) AS cancel_order_users,
    SUM(CASE WHEN order_status = 'CANCELLED' THEN 1 ELSE 0 END) AS cancel_order_cnt,
    CAST(SUM(CASE WHEN order_status = 'CANCELLED' THEN amount ELSE 0 END) AS DECIMAL(10,2)) AS cancel_amount
  FROM fct_order_status_di
  WHERE dt = '__RUN_DT__'
),
ads AS (
  SELECT
    raw_order_users,
    raw_order_cnt,
    raw_gmv,
    valid_order_users,
    valid_order_cnt,
    valid_gmv,
    cancel_order_users,
    cancel_order_cnt,
    cancel_amount
  FROM ads_order_status_day_overview
  WHERE dt = '__RUN_DT__'
)
SELECT 'ads_order_status_day_overview fct reconcile check failed' AS err_msg
FROM fct
CROSS JOIN ads
WHERE COALESCE(fct.raw_order_users, 0) <> COALESCE(ads.raw_order_users, 0)
   OR COALESCE(fct.raw_order_cnt, 0) <> COALESCE(ads.raw_order_cnt, 0)
   OR COALESCE(fct.raw_gmv, 0) <> COALESCE(ads.raw_gmv, 0)
   OR COALESCE(fct.valid_order_users, 0) <> COALESCE(ads.valid_order_users, 0)
   OR COALESCE(fct.valid_order_cnt, 0) <> COALESCE(ads.valid_order_cnt, 0)
   OR COALESCE(fct.valid_gmv, 0) <> COALESCE(ads.valid_gmv, 0)
   OR COALESCE(fct.cancel_order_users, 0) <> COALESCE(ads.cancel_order_users, 0)
   OR COALESCE(fct.cancel_order_cnt, 0) <> COALESCE(ads.cancel_order_cnt, 0)
   OR COALESCE(fct.cancel_amount, 0) <> COALESCE(ads.cancel_amount, 0);
