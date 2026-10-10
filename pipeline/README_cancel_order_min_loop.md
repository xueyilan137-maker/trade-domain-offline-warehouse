# 取消订单最小闭环

## 1. 学习目标

这个练习用于理解取消订单如何影响订单主题数仓口径。

最小闭环是：

```text
取消订单源数据
  -> DWD 取消订单 clean 表
  -> DWS 有效订单口径
  -> ADS 有效订单指标变化
```

重点不是一上来做复杂订单状态机，而是先吃透一个核心问题：

```text
订单明细里有一笔订单，不代表它最终一定应该计入有效订单 GMV。
```

## 2. 新增表

取消订单源表：

```text
dwd_order_cancel_p
```

取消订单 DWD 清洗表：

```text
dwd_order_cancel_clean_di
```

字段：

```text
order_id
user_id
cancel_date
cancel_reason
dt
```

## 3. 涉及文件

新增文件：

- `pipeline/sql/dwd/02_seed_order_cancel_demo.sql`
- `pipeline/sql/dwd/12_dwd_order_cancel_clean_di.sql.tpl`
- `pipeline/sql/dwd/40_dwd_order_cancel_quality.sql.tpl`

修改文件：

- `pipeline/sql/dwd/00_init_order_clean_tables.sql`
- `pipeline/run_dwd_order_clean_pipeline.ps1`
- `pipeline/run_dwd_order_clean_pipeline.sh`
- `pipeline/sql/dws/10_dws_user_order_day_agg.sql.tpl`
- `pipeline/sql/dws/20_dws_user_order_day_agg_quality.sql.tpl`
- `pipeline/sql/ads/30_ads_order_day_overview_reconcile.sql.tpl`
- `pipeline/sql/dq/10_order_subject_dq_report.sql.tpl`

## 4. DWD 取消订单清洗

清洗逻辑：

```text
TRIM(order_id / user_id / cancel_date / cancel_reason)
过滤 order_id 为空
过滤 user_id 为空
过滤 cancel_date 为空
cancel_reason 为空时填 unknown
按 order_id 去重，保留 cancel_date 最新的一条
```

核心结果表：

```text
dwd_order_cancel_clean_di
```

这张表的职责是告诉下游：

```text
哪些订单已经被取消。
```

## 5. 订单状态影响

当前最小闭环没有改造 `fct_order_di`，它仍然表示：

```text
一行 = 一笔 DWD clean 后的订单
```

取消订单对下游的影响发生在 DWS：

```sql
FROM fct_order_di o
LEFT JOIN dwd_order_cancel_clean_di c
  ON o.order_id = c.order_id
 AND o.dt = c.dt
WHERE o.dt = '__RUN_DT__'
  AND c.order_id IS NULL
```

也就是：

```text
FCT 保留订单事实
DWS/ADS 统计有效订单时排除取消订单
```

这是学习版最小做法。后续进入完整订单生命周期建模时，可以再把状态沉淀到订单过程表或订单宽表里。

## 6. ADS 口径变化

`ads_order_day_overview` 的字段没有新增，但口径变了：

| 字段 | 原口径 | 当前口径 |
| --- | --- | --- |
| `order_users` | 下单用户数 | 有效下单用户数，排除取消订单 |
| `order_cnt` | 订单数 | 有效订单数，排除取消订单 |
| `gmv` | 订单 GMV | 有效订单 GMV，排除取消订单 |
| `avg_order_amount` | 平均订单金额 | 有效订单平均金额 |

这个变化很重要：

```text
指标字段名不变，但业务口径已经从“下单”变成“有效下单”。
```

生产中通常需要在指标命名或指标说明中明确写出口径，例如：

```text
valid_order_cnt
valid_gmv
```

当前练习为了最小改动，先保留原 ADS 表结构。

## 7. 验证数据

订单源数据仍使用 `2026-03-05` 脏数据实验。

DWD clean 后有效订单有 3 笔：

| order_id | user_id | amount |
| --- | --- | --- |
| `o2001` | `u10` | `100.00` |
| `o2002` | `u11` | `90.00` |
| `o2005` | `u14` | `30.00` |

新增取消订单：

| order_id | user_id | cancel_date | cancel_reason |
| --- | --- | --- | --- |
| `o2002` | `u11` | `2026-03-05` | `user_cancel` |

所以有效订单变成：

| order_id | user_id | amount |
| --- | --- | --- |
| `o2001` | `u10` | `100.00` |
| `o2005` | `u14` | `30.00` |

## 8. 验证结果

本次已跑通 `2026-03-05`：

```text
dwd_order_cancel_clean_di:
o2002 / u11 / 2026-03-05 / user_cancel

dws_user_order_day_agg:
u10 / 1 / 100.00 / 100.00
u14 / 1 / 30.00 / 30.00

ads_order_day_overview:
order_users = 2
order_cnt = 2
gmv = 130.00
avg_order_amount = 65.00
```

对比取消前：

```text
取消前：3 单，GMV 220.00，客单价 73.33
取消后：2 单，GMV 130.00，客单价 65.00
```

## 9. DQ 变化

新增取消订单 DQ：

```text
dwd_order_cancel_clean_di order_id_unique
dwd_order_cancel_clean_di key_not_null
dwd_order_cancel_clean_di unmatched_order_check
```

同时 ADS 对账也改成有效订单口径：

```text
FCT 有效订单 = DWS 有效订单 = ADS 有效订单
FCT 有效 GMV = DWS 有效 GMV = ADS 有效 GMV
```

否则引入取消订单后，FCT 全量订单仍是 3 笔，而 ADS 有效订单是 2 笔，对账会误报失败。

## 10. 当前边界

当前是最小闭环，不是完整生产模型。

已经做到：

```text
取消订单进入 DWD
DWS 排除取消订单
ADS 指标变成有效订单口径
DQ 按有效订单口径对账
```

还没有做到：

```text
订单状态机
取消时间晚于下单日期的跨日影响
取消订单 dirty 表
取消原因维度化
订单生命周期累积快照 merge
退款金额和支付退款对账
```

## 11. 面试表达

可以这样讲：

> 我在订单主题里做过取消订单的最小闭环。原来 ADS 直接统计订单事实表，默认所有 clean 订单都算有效订单。后来我新增了取消订单 DWD clean 表，在 DWS 聚合时用订单号反关联取消表，排除已取消订单。这样 ADS 的订单数、GMV、客单价就从下单口径变成有效订单口径。同时我也把 ADS 对账改成有效订单口径，避免 FCT 全量订单和 ADS 有效订单之间误报对账失败。

如果继续追问，可以补充：

> 当前是学习版最小闭环，适合理解取消订单对指标口径的影响。生产中我会继续扩展订单状态机，处理跨日取消、退款、取消原因维度、以及订单生命周期累积快照表。
