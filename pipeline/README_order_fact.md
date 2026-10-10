# 订单事务事实表练习

这套练习的目标是把“事务事实表”做成一个你能看懂、能跑通、能讲清楚的最小版本。

## 先记住一句话

事务事实表最重要的不是字段多不多，而是：

“一行到底代表什么业务事件。”

这就是粒度。

## 这次练习的粒度

`fct_order_di` 这张表的粒度是：

**一行代表一笔订单。**

所以：

- `order_id` 是这张表最核心的业务键
- 一笔订单对应一行
- `amount` 是订单级金额

如果以后你做订单明细事实表，那粒度会变成：

**一行代表一条订单明细。**

那时主键和字段设计就会不一样。

## 这次练习为什么用订单做事务事实表

因为订单是最典型的业务事务：

- 什么时候发生：`order_date`
- 谁发生的：`user_id`
- 发生了什么：下了一笔单
- 数值是多少：`amount`

所以它天然适合作为事务事实表练习对象。

## 文件说明

- `pipeline/sql/fact/00_init_order_fact_tables.sql`
  创建 `fct_order_di`
- `pipeline/sql/fact/10_fct_order_di.sql.tpl`
  按 `run_dt` 从 `dwd_order_p` 装载当天订单事实
- `pipeline/sql/fact/20_fct_order_quality.sql.tpl`
  检查非空、订单重复、负金额
- `pipeline/run_order_fact_pipeline.ps1`
  单天事实表任务入口

## 练习顺序

先初始化：

```powershell
powershell -ExecutionPolicy Bypass -File .\pipeline\run_order_fact_pipeline.ps1 -RunDt 2026-03-24 -InitTables -InitOnly
```

再跑某一天：

```powershell
powershell -ExecutionPolicy Bypass -File .\pipeline\run_order_fact_pipeline.ps1 -RunDt 2026-03-24
```

## 查询验证

```sql
SELECT order_id, user_id, order_date, amount
FROM hive_demo.fct_order_di
WHERE dt = '2026-03-24'
ORDER BY order_id;
```

## 你现在要学会讲的点

1. 为什么这张表是事实表：
   因为它记录的是“下单事件”
2. 为什么它是事务事实表：
   因为一行表示一个原子业务事务
3. 为什么 `GMV` 不直接是这张表：
   因为 `GMV` 是对订单金额再聚合得到的指标
4. 为什么粒度重要：
   因为粒度一变，主键、字段、统计口径都会变
