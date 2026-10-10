# 用户日下单汇总事实表练习

这套练习对应的是最小版周期快照事实表。

## 先记住一句话

`fct_order_di` 记录的是“单笔订单事件”。

`fct_user_order_day_snapshot` 记录的是：

“某个用户在某一天的下单汇总结果”。

## 这张表为什么叫周期快照事实表

因为它不是原子事件明细，而是按统计周期沉淀出来的结果。

这里：

- 业务对象是 `user_id`
- 统计周期是 `dt`
- 快照内容是 `order_cnt`、`order_amount`

所以这张表的一行粒度是：

**一个用户在某一天的下单汇总。**

## 涉及文件

- `pipeline/sql/fact_snapshot/00_init_user_order_day_snapshot_tables.sql`
  创建 `fct_user_order_day_snapshot`
- `pipeline/sql/fact_snapshot/10_fct_user_order_day_snapshot.sql.tpl`
  从 `fct_order_di` 按用户聚合出当天订单数和订单金额
- `pipeline/sql/fact_snapshot/20_fct_user_order_day_snapshot_quality.sql.tpl`
  检查非空、重复主键、负指标
- `pipeline/run_user_order_day_snapshot_pipeline.ps1`
  单天执行入口

## 练习顺序

先初始化：

```powershell
powershell -ExecutionPolicy Bypass -File .\pipeline\run_user_order_day_snapshot_pipeline.ps1 -RunDt 2026-03-01 -InitTables -InitOnly
```

再跑当天：

```powershell
powershell -ExecutionPolicy Bypass -File .\pipeline\run_user_order_day_snapshot_pipeline.ps1 -RunDt 2026-03-01
```

## 查询验证

```sql
SELECT user_id, order_cnt, order_amount
FROM hive_demo.fct_user_order_day_snapshot
WHERE dt = '2026-03-01'
ORDER BY user_id;
```

## 这次最应该会讲的点

1. 为什么它不是事务事实表：
   因为它不是一行一笔订单，而是一行一个用户当天的汇总
2. 为什么它是周期快照事实表：
   因为它按天沉淀用户在一个统计周期内的状态/结果
3. 它和事务事实表的关系：
   周期快照事实表通常由事务事实表聚合而来
