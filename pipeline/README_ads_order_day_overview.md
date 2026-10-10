# 订单日总览 ADS 练习

这套练习把 DWS 用户订单主题汇总表继续加工成面向看板/应用的 ADS 结果表。

## 一句话理解

`dws_user_order_day_agg` 是用户订单主题公共汇总。

`ads_order_day_overview` 是订单日经营总览，面向具体报表问题：

“某一天整体有多少下单用户、多少订单、多少 GMV、平均每单多少钱？”

## 这张表为什么属于 ADS

因为它已经不再保留用户粒度，而是直接面向一个日总览场景。

它适合被看板直接查询：

- `order_users`
- `order_cnt`
- `gmv`
- `avg_order_amount`

## 这张表的粒度

`ads_order_day_overview` 的粒度是：

**一行代表某一天的订单经营总览。**

主键视角可以先理解成：

- `dt`

## 涉及文件

- `pipeline/sql/ads/00_init_ads_order_day_overview_tables.sql`
  创建 `ads_order_day_overview`
- `pipeline/sql/ads/10_ads_order_day_overview.sql.tpl`
  从 `dws_user_order_day_agg` 汇总到日总览
- `pipeline/sql/ads/20_ads_order_day_overview_quality.sql.tpl`
  基础质量校验
- `pipeline/run_ads_order_day_overview_pipeline.ps1`
  单天执行入口

## 推荐练习顺序

先初始化：

```powershell
powershell -ExecutionPolicy Bypass -File .\pipeline\run_ads_order_day_overview_pipeline.ps1 -RunDt 2026-03-01 -InitTables -InitOnly
```

再跑当天：

```powershell
powershell -ExecutionPolicy Bypass -File .\pipeline\run_ads_order_day_overview_pipeline.ps1 -RunDt 2026-03-01
```

## 查询验证

```sql
SELECT order_users, order_cnt, gmv, avg_order_amount
FROM hive_demo.ads_order_day_overview
WHERE dt = '2026-03-01';
```

## 这次最应该会讲的点

1. 为什么它不是 DWS：
   因为它已经面向具体日总览应用场景
2. 为什么它从 DWS 来：
   因为 DWS 沉淀公共主题指标，ADS 再按应用需求汇总
3. 为什么一行只有一天：
   因为这张表的粒度是 `dt`
