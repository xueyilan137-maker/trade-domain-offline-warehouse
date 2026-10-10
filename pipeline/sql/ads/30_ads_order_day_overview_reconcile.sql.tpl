USE hive_demo;

WITH fct AS (
  SELECT
    COUNT(*) AS order_cnt,
    COUNT(DISTINCT user_id) AS order_users,
    CAST(SUM(amount) AS DECIMAL(10,2)) AS gmv
  FROM fct_order_status_di
  WHERE dt = '__RUN_DT__'
    AND order_status = 'VALID'
),
dws AS (
  SELECT
    SUM(order_cnt) AS order_cnt,
    COUNT(DISTINCT user_id) AS order_users,
    CAST(SUM(order_amount) AS DECIMAL(10,2)) AS gmv
  FROM dws_user_order_day_agg
  WHERE dt = '__RUN_DT__'
),
ads AS (
  SELECT
    order_cnt,
    order_users,
    gmv
  FROM ads_order_day_overview
  WHERE dt = '__RUN_DT__'
)
SELECT 'ads_order_day_overview gmv reconcile check failed' AS err_msg
FROM fct
CROSS JOIN dws
CROSS JOIN ads
WHERE COALESCE(fct.gmv, 0) <> COALESCE(dws.gmv, 0)
   OR COALESCE(fct.gmv, 0) <> COALESCE(ads.gmv, 0);

WITH fct AS (
  SELECT COUNT(*) AS order_cnt
  FROM fct_order_status_di
  WHERE dt = '__RUN_DT__'
    AND order_status = 'VALID'
),
dws AS (
  SELECT SUM(order_cnt) AS order_cnt
  FROM dws_user_order_day_agg
  WHERE dt = '__RUN_DT__'
),
ads AS (
  SELECT order_cnt
  FROM ads_order_day_overview
  WHERE dt = '__RUN_DT__'
)
SELECT 'ads_order_day_overview order count reconcile check failed' AS err_msg
FROM fct
CROSS JOIN dws
CROSS JOIN ads
WHERE COALESCE(fct.order_cnt, 0) <> COALESCE(dws.order_cnt, 0)
   OR COALESCE(fct.order_cnt, 0) <> COALESCE(ads.order_cnt, 0);

WITH fct AS (
  SELECT COUNT(DISTINCT user_id) AS order_users
  FROM fct_order_status_di
  WHERE dt = '__RUN_DT__'
    AND order_status = 'VALID'
),
dws AS (
  SELECT COUNT(DISTINCT user_id) AS order_users
  FROM dws_user_order_day_agg
  WHERE dt = '__RUN_DT__'
),
ads AS (
  SELECT order_users
  FROM ads_order_day_overview
  WHERE dt = '__RUN_DT__'
)
SELECT 'ads_order_day_overview order users reconcile check failed' AS err_msg
FROM fct
CROSS JOIN dws
CROSS JOIN ads
WHERE COALESCE(fct.order_users, 0) <> COALESCE(dws.order_users, 0)
   OR COALESCE(fct.order_users, 0) <> COALESCE(ads.order_users, 0);

WITH dws AS (
  SELECT CAST(ROUND(SUM(order_amount) / NULLIF(SUM(order_cnt), 0), 2) AS DECIMAL(10,2)) AS avg_order_amount
  FROM dws_user_order_day_agg
  WHERE dt = '__RUN_DT__'
),
ads AS (
  SELECT avg_order_amount
  FROM ads_order_day_overview
  WHERE dt = '__RUN_DT__'
)
SELECT 'ads_order_day_overview avg order amount reconcile check failed' AS err_msg
FROM dws
CROSS JOIN ads
WHERE COALESCE(dws.avg_order_amount, 0) <> COALESCE(ads.avg_order_amount, 0);
