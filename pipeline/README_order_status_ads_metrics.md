# 订单状态 ADS 指标升级

## 1. 学习目标

这一阶段把订单状态表的价值真正用到 ADS 指标上。

上一阶段已经有：

```text
fct_order_status_di
```

它能区分：

```text
VALID
CANCELLED
```

这一阶段新增状态指标 ADS：

```text
ads_order_status_day_overview
```

用来同时回答：

```text
原始订单有多少？
有效订单有多少？
取消订单有多少？
取消金额是多少？
取消率是多少？
有效订单占比是多少？
```

## 2. 为什么不直接改原 ADS 表

原来的表：

```text
ads_order_day_overview
```

当前语义已经偏向：

```text
有效订单总览
```

为了避免字段口径混乱，这次新增一张更明确的状态指标表：

```text
ads_order_status_day_overview
```

这样可以保留原来的有效订单 ADS，同时新增一张能表达多状态口径的 ADS。

## 3. 新增 ADS 表

表名：

```text
ads_order_status_day_overview
```

字段：

```text
raw_order_users
raw_order_cnt
raw_gmv
valid_order_users
valid_order_cnt
valid_gmv
cancel_order_users
cancel_order_cnt
cancel_amount
valid_order_rate
cancel_order_rate
dt
```

三组核心口径：

| 口径 | 含义 |
| --- | --- |
| `raw_*` | DWD clean / FCT 中的原始订单口径，包含取消订单 |
| `valid_*` | 有效订单口径，只包含 `order_status = 'VALID'` |
| `cancel_*` | 取消订单口径，只包含 `order_status = 'CANCELLED'` |

## 4. 核心计算逻辑

来源表：

```text
fct_order_status_di
```

核心思路：

```sql
COUNT(*) AS raw_order_cnt
SUM(CASE WHEN order_status = 'VALID' THEN 1 ELSE 0 END) AS valid_order_cnt
SUM(CASE WHEN order_status = 'CANCELLED' THEN 1 ELSE 0 END) AS cancel_order_cnt
```

取消率：

```sql
cancel_order_cnt / raw_order_cnt
```

有效订单占比：

```sql
valid_order_cnt / raw_order_cnt
```

这一步体现了状态表的价值：

```text
一张状态事实表可以同时支撑多种指标口径。
```

## 5. 涉及文件

新增：

- `pipeline/sql/ads/11_ads_order_status_day_overview.sql.tpl`
- `pipeline/sql/ads/21_ads_order_status_day_overview_quality.sql.tpl`
- `pipeline/sql/ads/31_ads_order_status_day_overview_reconcile.sql.tpl`
- `pipeline/README_order_status_ads_metrics.md`

修改：

- `pipeline/sql/ads/00_init_ads_order_day_overview_tables.sql`
- `pipeline/run_ads_order_day_overview_pipeline.ps1`
- `pipeline/run_ads_order_day_overview_pipeline.sh`
- `pipeline/sql/dq/10_order_subject_dq_report.sql.tpl`

## 6. 验证结果

验证日期：

```text
2026-03-05
```

状态明细：

```text
o2001 VALID      100.00
o2002 CANCELLED   90.00
o2005 VALID       30.00
```

新 ADS 结果：

| 指标 | 结果 |
| --- | --- |
| `raw_order_users` | `3` |
| `raw_order_cnt` | `3` |
| `raw_gmv` | `220.00` |
| `valid_order_users` | `2` |
| `valid_order_cnt` | `2` |
| `valid_gmv` | `130.00` |
| `cancel_order_users` | `1` |
| `cancel_order_cnt` | `1` |
| `cancel_amount` | `90.00` |
| `valid_order_rate` | `0.6667` |
| `cancel_order_rate` | `0.3333` |

## 7. DQ 校验

新增 ADS 质量校验：

```text
row_count_equals_one
metric_non_negative
rate_range_valid
raw_count_split_reconcile
raw_gmv_split_reconcile
fct_status_reconcile
```

关键对账关系：

```text
raw_order_cnt = valid_order_cnt + cancel_order_cnt
raw_gmv = valid_gmv + cancel_amount
ads_order_status_day_overview = fct_order_status_di 汇总结果
```

本次验证：

```text
ads_order_status_day_overview 的 6 个 DQ 检查全部 PASS。
```

## 8. 这一步应该理解什么

这一阶段的重点是指标口径命名。

不要只说：

```text
order_cnt
gmv
```

因为加入取消订单后，必须问清楚：

```text
是原始订单数？
还是有效订单数？
还是取消订单数？
```

所以更清晰的指标命名是：

```text
raw_order_cnt
valid_order_cnt
cancel_order_cnt
raw_gmv
valid_gmv
cancel_amount
cancel_order_rate
```

## 9. 面试表达

可以这样讲：

> 我在订单状态建模后，又把 ADS 指标做了口径升级。原来的 ADS 只看有效订单，后来我新增了 `ads_order_status_day_overview`，从 `fct_order_status_di` 同时计算 raw、valid、cancel 三类指标，包括原始订单数、有效订单数、取消订单数、取消金额、有效订单占比和取消率。这样可以清楚地区分下单口径、有效订单口径和取消订单口径，也避免一个 `order_cnt` 字段含义不清。

如果继续追问 DQ，可以补充：

> 我给状态 ADS 做了对账校验，例如 `raw_order_cnt = valid_order_cnt + cancel_order_cnt`，`raw_gmv = valid_gmv + cancel_amount`，并且用 FCT 状态表重新汇总后和 ADS 对账，保证最终指标没有算歪。

## 10. 下一步

下一步可以进入退款主题。

退款和取消的区别是：

```text
取消订单：通常影响订单是否计入有效订单
退款：通常影响实付金额、净 GMV、退款金额、退款率
```

所以退款会引出新的核心指标：

```text
pay_amount
refund_amount
net_gmv
refund_rate
```
