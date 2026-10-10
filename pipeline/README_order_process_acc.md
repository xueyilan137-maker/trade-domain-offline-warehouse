# 订单流程累积快照事实表练习

这套练习用于建立你对“累积快照事实表”的第一感觉。

## 一句话理解

事务事实表是一行一笔事件。

累积快照事实表是一行一个流程对象，并在同一行上不断补齐流程节点。

## 这次练习的对象

我们用订单流程做最小版练习。

流程节点是：

- `create_date`
- `pay_date`
- `ship_date`
- `finish_date`

状态字段是：

- `order_status`

## 这张表的粒度

`fct_order_process_acc` 的粒度是：

**一行代表一个订单流程对象。**

不是一行一笔支付，也不是一行一个日汇总，而是一行看完整个订单流程推进到了哪一步。

## 涉及文件

- `pipeline/sql/fact_acc/00_init_order_process_acc_tables.sql`
  创建 demo 流程输入表和累积快照事实表
- `pipeline/sql/fact_acc/01_seed_ods_order_process_demo.sql`
  准备 2026-04-24 ~ 2026-04-26 的订单流程演示数据
- `pipeline/sql/fact_acc/10_fct_order_process_acc.sql.tpl`
  按 `run_dt` 将当天流程快照写入累积快照事实表
- `pipeline/sql/fact_acc/20_fct_order_process_acc_quality.sql.tpl`
  基础质量校验
- `pipeline/run_order_process_acc_pipeline.ps1`
  单天执行入口

## 推荐练习顺序

先初始化：

```powershell
powershell -ExecutionPolicy Bypass -File .\pipeline\run_order_process_acc_pipeline.ps1 -RunDt 2026-04-24 -InitTables -InitOnly
```

再导入演示数据：

```powershell
docker cp .\pipeline\sql\fact_acc\01_seed_ods_order_process_demo.sql hadoop-spark:/tmp/01_seed_ods_order_process_demo.sql
docker exec hadoop-spark bash -lc "/spark/bin/spark-sql --master local[*] -f /tmp/01_seed_ods_order_process_demo.sql"
```

然后按天跑：

```powershell
powershell -ExecutionPolicy Bypass -File .\pipeline\run_order_process_acc_pipeline.ps1 -RunDt 2026-04-24
powershell -ExecutionPolicy Bypass -File .\pipeline\run_order_process_acc_pipeline.ps1 -RunDt 2026-04-25
powershell -ExecutionPolicy Bypass -File .\pipeline\run_order_process_acc_pipeline.ps1 -RunDt 2026-04-26
```

## 查询验证

```sql
SELECT order_id, user_id, create_date, pay_date, ship_date, finish_date, order_status
FROM hive_demo.fct_order_process_acc
ORDER BY order_id;
```

## 你现在最该观察的点

1. 为什么一张表里会同时有多个流程节点日期
2. 为什么它不是每天按用户汇总，而是按订单流程对象保留一行
3. 为什么它特别适合回答“订单现在推进到哪一步了”

## 一句面试表达

“我用订单流程练过累积快照事实表。表里一行代表一个订单流程对象，随着流程推进逐步补齐支付、发货、完成等节点时间，适合做流程阶段分析和时效分析。” 
