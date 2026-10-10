# 用户订单主题汇总表练习

这套练习的目标是把“从事实层走到主题汇总层”真正跑通。

## 一句话理解

`fct_order_di` 记录的是订单原子事件。

`dws_user_order_day_agg` 记录的是：

“某个用户在某一天的订单主题汇总结果。”

## 这张表为什么属于 DWS

因为它不再保留订单明细，而是围绕“用户订单主题”沉淀公共汇总指标：

- `order_cnt`
- `order_amount`
- `avg_order_amount`

所以它已经从事实明细层走到了主题汇总层。

## 这张表的粒度

`dws_user_order_day_agg` 的粒度是：

**一行代表一个用户在某一天的订单主题汇总。**

主键视角可以先理解成：

- `user_id + dt`

## 涉及文件

- `pipeline/sql/dws/00_init_dws_user_order_day_agg_tables.sql`
  创建 `dws_user_order_day_agg`
- `pipeline/sql/dws/10_dws_user_order_day_agg.sql.tpl`
  从 `fct_order_di` 聚合得到用户订单主题指标
- `pipeline/sql/dws/20_dws_user_order_day_agg_quality.sql.tpl`
  基础质量校验
- `pipeline/run_dws_user_order_day_agg_pipeline.ps1`
  单天执行入口

## 推荐练习顺序

先初始化：

```powershell
powershell -ExecutionPolicy Bypass -File .\pipeline\run_dws_user_order_day_agg_pipeline.ps1 -RunDt 2026-03-01 -InitTables -InitOnly
```

再跑当天：

```powershell
powershell -ExecutionPolicy Bypass -File .\pipeline\run_dws_user_order_day_agg_pipeline.ps1 -RunDt 2026-03-01
```

## 查询验证

```sql
SELECT user_id, order_cnt, order_amount, avg_order_amount
FROM hive_demo.dws_user_order_day_agg
WHERE dt = '2026-03-01'
ORDER BY user_id;
```

## 这次最应该会讲的点

1. 为什么它不是事务事实表：
   因为它已经不是一行一笔订单
2. 为什么它不是 ADS：
   因为它沉淀的是用户订单主题公共指标，还不是某一个具体报表结果
3. 为什么它属于 DWS：
   因为它围绕用户订单主题做了日汇总沉淀
