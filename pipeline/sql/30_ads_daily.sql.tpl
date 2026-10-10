USE hive_demo;

INSERT OVERWRITE TABLE ads_daily_overview_dp PARTITION (dt='__RUN_DT__')
SELECT
  COALESCE(r.register_users, 0) AS register_users,
  COALESCE(v.visit_users, 0) AS visit_users,
  COALESCE(o.order_users, 0) AS order_users,
  COALESCE(o.gmv, 0) AS gmv,
  COALESCE(c.conversion_rate, 0) AS conversion_rate,
  ROUND(
    COALESCE(o.order_users, 0) / NULLIF(COALESCE(r.register_users, 0), 0),
    4
  ) AS order_rate,
  COALESCE(
    ROUND(
      COALESCE(o.gmv, 0) / NULLIF(COALESCE(o.order_users, 0), 0),
      2
    ),
    0
  ) AS avg_order_amount,
  COALESCE(re.repurchase_users, 0) AS repurchase_users,
  ROUND(
    COALESCE(re.repurchase_users, 0) / NULLIF(COALESCE(o.order_users, 0), 0),
    4
  ) AS repurchase_rate
FROM (SELECT 1 AS k) tmp
LEFT JOIN (
  SELECT dt, register_users
  FROM dws_register_daily
  WHERE dt = '__RUN_DT__'
) r ON 1 = 1
LEFT JOIN (
  SELECT dt, visit_users
  FROM dws_visit_daily_dp
  WHERE dt = '__RUN_DT__'
) v ON 1 = 1
LEFT JOIN (
  SELECT dt, order_users, gmv
  FROM dws_order_daily_dp
  WHERE dt = '__RUN_DT__'
) o ON 1 = 1
LEFT JOIN (
  SELECT dt, visit_users, order_users, conversion_rate
  FROM dws_conversion_daily_dp
  WHERE dt = '__RUN_DT__'
) c ON 1 = 1
LEFT JOIN (
  SELECT dt, repurchase_users
  FROM dws_repurchase_daily
  WHERE dt = '__RUN_DT__'
) re ON 1 = 1;
