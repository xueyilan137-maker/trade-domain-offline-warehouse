# 订单事实表建模项目

## 1. 项目定位

这个项目用于沉淀订单主题中的事实表建模能力，重点不是单表 SQL，而是理解不同事实表在数仓中的粒度、用途和适用场景。

当前仓库里已经落地了三类典型事实表：

| 类型 | 表名 | 粒度 | 主要用途 |
| --- | --- | --- | --- |
| 事务事实表 | `fct_order_di` | 一行一笔有效订单 | 承接 DWD 干净订单明细，作为 GMV、订单数、下单用户数等指标来源 |
| 周期快照事实表 | `fct_user_order_day_snapshot` | 一个用户一天一行 | 沉淀用户在某天的下单汇总状态 |
| 累积快照事实表 | `fct_order_process_acc` | 一个订单流程对象一行 | 观察订单创建、支付、发货、完成等生命周期节点 |

这三个表可以作为一个完整的事实表建模小项目来复盘：同样是订单业务，不同分析问题会选择不同事实表粒度。

## 2. 项目链路

```text
dwd_order_clean_di
  -> fct_order_di
  -> fct_user_order_day_snapshot

ods_order_process_di
  -> fct_order_process_acc
```

其中：

- `fct_order_di` 来自 DWD 清洗后的可信订单明细。
- `fct_user_order_day_snapshot` 基于订单事务事实表按用户和日期聚合。
- `fct_order_process_acc` 基于订单流程快照数据，沉淀订单生命周期状态。

## 3. 涉及文件

事务事实表：

- `pipeline/sql/fact/00_init_order_fact_tables.sql`
- `pipeline/sql/fact/10_fct_order_di.sql.tpl`
- `pipeline/sql/fact/20_fct_order_quality.sql.tpl`
- `pipeline/run_order_fact_pipeline.ps1`
- `pipeline/run_order_fact_pipeline.sh`

周期快照事实表：

- `pipeline/sql/fact_snapshot/00_init_user_order_day_snapshot_tables.sql`
- `pipeline/sql/fact_snapshot/10_fct_user_order_day_snapshot.sql.tpl`
- `pipeline/sql/fact_snapshot/20_fct_user_order_day_snapshot_quality.sql.tpl`
- `pipeline/run_user_order_day_snapshot_pipeline.ps1`

累积快照事实表：

- `pipeline/sql/fact_acc/00_init_order_process_acc_tables.sql`
- `pipeline/sql/fact_acc/01_seed_ods_order_process_demo.sql`
- `pipeline/sql/fact_acc/10_fct_order_process_acc.sql.tpl`
- `pipeline/sql/fact_acc/20_fct_order_process_acc_quality.sql.tpl`
- `pipeline/run_order_process_acc_pipeline.ps1`

## 4. 事务事实表：`fct_order_di`

`fct_order_di` 的粒度是：

```text
一行 = 一笔有效订单
```

核心 SQL：

```sql
INSERT OVERWRITE TABLE fct_order_di PARTITION (dt='__RUN_DT__')
SELECT
  order_id,
  user_id,
  order_date,
  amount
FROM dwd_order_clean_di
WHERE dt = '__RUN_DT__';
```

它不直接读取原始订单源表，而是读取 `dwd_order_clean_di`。这点很关键：事实表应该尽量承接 DWD 层已经清洗、去重、标准化后的可信明细，避免脏数据继续污染 DWS 和 ADS 指标。

当前质量校验包括：

- 分区行数非空
- `order_id` 不重复
- `order_id` / `user_id` 不为空
- `amount` 不为负
- 与 `dwd_order_clean_di` 做行数对账
- 与 `dwd_order_clean_di` 做 GMV 对账

这张表回答的问题是：

- 某天有多少笔有效订单
- 某天 GMV 是多少
- 某天有多少下单用户
- 某个订单的原子明细是什么

## 5. 周期快照事实表：`fct_user_order_day_snapshot`

`fct_user_order_day_snapshot` 的粒度是：

```text
一行 = 一个用户在某一天的下单汇总状态
```

核心 SQL：

```sql
INSERT OVERWRITE TABLE fct_user_order_day_snapshot PARTITION (dt='__RUN_DT__')
SELECT
  user_id,
  COUNT(*) AS order_cnt,
  CAST(SUM(amount) AS DECIMAL(10,2)) AS order_amount
FROM fct_order_di
WHERE dt = '__RUN_DT__'
GROUP BY user_id;
```

它不是订单明细表，而是按固定统计周期沉淀出来的用户状态快照。它适合支撑用户粒度分析，例如：

- 用户当天是否下单
- 用户当天订单数
- 用户当天消费金额
- 后续做用户活跃、复购、分层分析时作为中间事实

当前质量校验包括：

- 分区行数非空
- 同一分区内 `user_id` 不重复
- `user_id` 不为空
- `order_cnt` / `order_amount` 不为负

它和事务事实表的区别是：

| 对比项 | `fct_order_di` | `fct_user_order_day_snapshot` |
| --- | --- | --- |
| 粒度 | 一笔订单一行 | 一个用户一天一行 |
| 数据形态 | 明细事件 | 周期汇总状态 |
| 常见用途 | 明细追溯、订单指标 | 用户日汇总、用户行为分析 |
| 来源 | DWD clean | 事务事实表聚合 |

## 6. 累积快照事实表：`fct_order_process_acc`

`fct_order_process_acc` 的粒度是：

```text
一行 = 一个订单流程对象
```

当前字段包括：

- `order_id`
- `user_id`
- `create_date`
- `pay_date`
- `ship_date`
- `finish_date`
- `order_status`

它关注的不是某一次事件，而是一个订单流程走到了哪一步。示例流程：

```text
CREATED -> PAID -> SHIPPED -> FINISHED
```

演示数据覆盖 `2026-04-24` 到 `2026-04-26`：

- `o2001`：创建后逐步支付、发货
- `o2002`：创建、支付、发货、完成
- `o2003`：较快完成
- `o2004`：新创建后支付

当前实现是学习版：

```sql
WITH today AS (
  SELECT
    order_id,
    user_id,
    create_date,
    pay_date,
    ship_date,
    finish_date,
    order_status
  FROM ods_order_process_di
  WHERE dt = '__RUN_DT__'
)
INSERT OVERWRITE TABLE fct_order_process_acc
SELECT
  order_id,
  user_id,
  create_date,
  pay_date,
  ship_date,
  finish_date,
  order_status
FROM today;
```

也就是说，当前练习重点是理解累积快照事实表的形态：一行保留一个订单流程对象，并在同一行上体现多个流程节点。它还不是生产级逐日 merge 历史状态的写法。

生产增强版可以继续扩展为：

- 读取昨日 `fct_order_process_acc`
- 读取今日流程增量或快照
- 对同一订单补齐新的节点日期
- 保留未变化订单
- 对取消、退款、关闭等新状态做状态机治理

## 7. 推荐执行顺序

事务事实表：

```powershell
powershell -ExecutionPolicy Bypass -File .\pipeline\run_order_fact_pipeline.ps1 -RunDt 2026-03-05 -InitTables
```

周期快照事实表：

```powershell
powershell -ExecutionPolicy Bypass -File .\pipeline\run_user_order_day_snapshot_pipeline.ps1 -RunDt 2026-03-05 -InitTables
```

累积快照事实表：

```powershell
powershell -ExecutionPolicy Bypass -File .\pipeline\run_order_process_acc_pipeline.ps1 -RunDt 2026-04-24 -InitTables -InitOnly

docker cp .\pipeline\sql\fact_acc\01_seed_ods_order_process_demo.sql hadoop-spark:/tmp/01_seed_ods_order_process_demo.sql
docker exec hadoop-spark bash -lc "/spark/bin/spark-sql --master local[*] -f /tmp/01_seed_ods_order_process_demo.sql"

powershell -ExecutionPolicy Bypass -File .\pipeline\run_order_process_acc_pipeline.ps1 -RunDt 2026-04-24
powershell -ExecutionPolicy Bypass -File .\pipeline\run_order_process_acc_pipeline.ps1 -RunDt 2026-04-25
powershell -ExecutionPolicy Bypass -File .\pipeline\run_order_process_acc_pipeline.ps1 -RunDt 2026-04-26
```

## 8. 验证 SQL

事务事实表：

```sql
SELECT *
FROM hive_demo.fct_order_di
WHERE dt = '2026-03-05'
ORDER BY order_id;
```

周期快照事实表：

```sql
SELECT *
FROM hive_demo.fct_user_order_day_snapshot
WHERE dt = '2026-03-05'
ORDER BY user_id;
```

累积快照事实表：

```sql
SELECT
  order_id,
  user_id,
  create_date,
  pay_date,
  ship_date,
  finish_date,
  order_status
FROM hive_demo.fct_order_process_acc
ORDER BY order_id;
```

## 9. 这个项目证明了什么

这个项目可以证明你具备以下能力：

- 能区分事实表和维度表
- 能根据业务问题选择事实表粒度
- 能解释事务事实表、周期快照事实表、累积快照事实表的区别
- 能从 DWD 可信明细沉淀 FCT 层
- 能用质量校验保护事实表结果
- 能把订单生命周期建模成可分析的流程状态表

## 10. 面试表达

可以这样讲：

> 我在订单主题里练过三类事实表。事务事实表 `fct_order_di` 是一行一笔有效订单，承接 DWD 清洗后的订单明细，用来支撑 GMV、订单数、下单用户数等指标。周期快照事实表 `fct_user_order_day_snapshot` 是一个用户一天一行，用来沉淀用户当天的下单状态。累积快照事实表 `fct_order_process_acc` 是一个订单流程对象一行，把创建、支付、发货、完成这些节点放在同一行，适合分析订单生命周期和流程推进状态。

如果面试官继续追问，可以补充：

> 当前练习版累积快照表是从当天流程快照覆盖生成，主要用于理解表形态。生产中我会扩展成读取历史状态和当天增量，通过 merge 补齐新的流程节点，并增加取消、退款、关闭等状态处理。

## 11. 后续扩展

下一步可以基于这个项目继续做：

- 增加取消订单状态
- 增加退款节点和退款事实表
- 将 `fct_order_process_acc` 改造成历史状态 merge 写法
- 增加流程时效指标，例如支付耗时、发货耗时、完成耗时
- 将事实表 DQ 结果统一写入 `dq_check_result_di`
- 把事实表建模和订单 + 支付对账主题项目合并成更完整的订单域数仓
