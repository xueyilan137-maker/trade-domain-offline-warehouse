USE hive_demo;

DROP TABLE IF EXISTS ads_daily_overview;
CREATE TABLE ads_daily_overview AS
SELECT
  d.dt,
  COALESCE(r.register_users, 0) AS register_users,
  COALESCE(v.visit_users, 0) AS visit_users,
  COALESCE(o.order_users, 0) AS order_users,
  COALESCE(o.gmv, 0) AS gmv,
  COALESCE(c.conversion_rate, 0) AS conversion_rate
FROM (
  SELECT dt FROM dws_register_daily
  UNION
  SELECT dt FROM dws_visit_daily
  UNION
  SELECT dt FROM dws_order_daily
) d
LEFT JOIN dws_register_daily r ON d.dt = r.dt
LEFT JOIN dws_visit_daily v ON d.dt = v.dt
LEFT JOIN dws_order_daily o ON d.dt = o.dt
LEFT JOIN dws_conversion_daily c ON d.dt = c.dt;
