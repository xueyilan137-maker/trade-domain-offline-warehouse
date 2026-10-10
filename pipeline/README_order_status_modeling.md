# 订单状态建模：从取消过滤到状态沉淀

## 1. 学习目标

上一阶段的取消订单最小闭环是：

```text
DWS/ADS 统计时 join 取消表，排除取消订单
```

这一阶段升级为：

```text
先沉淀订单状态表
下游直接按 order_status 统计有效订单
```

核心变化：

```text
从“下游临时判断是否取消”
升级为“中间层统一沉淀订单状态”
```

## 2. 新增状态事实表

表名：

```text
fct_order_status_di
```

粒度：

```text
一行 = 一笔订单的当前业务状态
```

字段：

```text
order_id
user_id
order_date
amount
order_status
is_cancelled
cancel_date
cancel_reason
dt
```

当前状态：

```text
VALID
CANCELLED
```

## 3. 链路变化

原来：

```text
fct_order_di
  + dwd_order_cancel_clean_di
  -> dws_user_order_day_agg
  -> ads_order_day_overview
```

现在：

```text
fct_order_di
  + dwd_order_cancel_clean_di
  -> fct_order_status_di
  -> dws_user_order_day_agg
  -> ads_order_day_overview
```

## 4. 核心 SQL

订单状态生成：

```sql
INSERT OVERWRITE TABLE fct_order_status_di PARTITION (dt='__RUN_DT__')
SELECT
  o.order_id,
  o.user_id,
  o.order_date,
  o.amount,
  CASE
    WHEN c.order_id IS NOT NULL THEN 'CANCELLED'
    ELSE 'VALID'
  END AS order_status,
  CASE
    WHEN c.order_id IS NOT NULL THEN 1
    ELSE 0
  END AS is_cancelled,
  c.cancel_date,
  c.cancel_reason
FROM fct_order_di o
LEFT JOIN dwd_order_cancel_clean_di c
  ON o.order_id = c.order_id
 AND o.dt = c.dt
WHERE o.dt = '__RUN_DT__';
```

DWS 有效订单口径：

```sql
JOIN fct_order_status_di s
  ON o.order_id = s.order_id
 AND o.dt = s.dt
WHERE o.dt = '__RUN_DT__'
  AND s.order_status = 'VALID'
```

这比在多个下游表里各自 join 取消表更清楚。

## 5. 涉及文件

新增：

- `pipeline/sql/fact/11_fct_order_status_di.sql.tpl`
- `pipeline/sql/fact/21_fct_order_status_quality.sql.tpl`

修改：

- `pipeline/sql/fact/00_init_order_fact_tables.sql`
- `pipeline/run_order_fact_pipeline.ps1`
- `pipeline/run_order_fact_pipeline.sh`
- `pipeline/sql/dws/10_dws_user_order_day_agg.sql.tpl`
- `pipeline/sql/dws/20_dws_user_order_day_agg_quality.sql.tpl`
- `pipeline/sql/ads/30_ads_order_day_overview_reconcile.sql.tpl`
- `pipeline/sql/dq/10_order_subject_dq_report.sql.tpl`

## 6. 验证结果

验证日期：

```text
2026-03-05
```

状态表结果：

| order_id | user_id | amount | order_status | is_cancelled | cancel_date | cancel_reason |
| --- | --- | --- | --- | --- | --- | --- |
| `o2001` | `u10` | `100.00` | `VALID` | `0` | `NULL` | `NULL` |
| `o2002` | `u11` | `90.00` | `CANCELLED` | `1` | `2026-03-05` | `user_cancel` |
| `o2005` | `u14` | `30.00` | `VALID` | `0` | `NULL` | `NULL` |

按状态汇总：

| order_status | order_cnt | amount |
| --- | --- | --- |
| `CANCELLED` | `1` | `90.00` |
| `VALID` | `2` | `130.00` |

ADS 有效订单结果：

```text
order_users = 2
order_cnt = 2
gmv = 130.00
avg_order_amount = 65.00
```

DQ 汇总没有返回 `FAIL` 行。

## 7. 这一步应该理解什么

这一步的关键不是多建一张表，而是理解口径治理：

```text
订单是否有效，不应该散落在多个 ADS/DWS SQL 里各自判断。
更好的方式是先在中间层沉淀统一状态，再让下游按状态取数。
```

现在下游想算有效订单，只要写：

```sql
WHERE order_status = 'VALID'
```

想算取消订单，只要写：

```sql
WHERE order_status = 'CANCELLED'
```

## 8. 当前边界

当前仍然是学习版订单状态建模。

已经做到：

```text
VALID / CANCELLED 状态沉淀
is_cancelled 标记
取消日期和取消原因进入状态表
DWS/ADS 读取状态表统计有效订单
DQ 按状态口径对账
```

还没有做到：

```text
跨日取消影响历史订单分区
订单状态优先级
订单状态变更历史
取消 dirty 表
退款状态
完整订单生命周期状态机
```

## 9. 面试表达

可以这样讲：

> 我一开始用取消订单表在 DWS 层过滤有效订单，后来进一步把订单状态沉淀成 `fct_order_status_di`。这张表一行一笔订单，包含 `order_status`、`is_cancelled`、`cancel_date`、`cancel_reason`。下游 DWS 和 ADS 不再各自 join 取消表，而是统一按 `order_status='VALID'` 统计有效订单。这样能减少口径分散，也方便后续扩展退款、关闭、完成等更多订单状态。

如果继续追问，可以补充：

> 当前是同日取消的学习版。生产中还要处理跨日取消、状态优先级、状态变更历史，以及订单生命周期累积快照。
