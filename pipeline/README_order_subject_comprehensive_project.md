# 订单主题综合项目复盘 / 面试表达

## 1. 项目定位

这个项目是一个离线数仓订单主题的小型综合项目，重点不是单独写某一个 SQL，而是把订单域里常见的数据开发能力串成一条可运行、可重跑、可校验、可调度的链路。

当前已经覆盖：

- DWD 清洗治理
- dirty 异常落表
- 有效订单事实表
- 取消订单状态建模
- 退款订单分层建模
- DWS 用户天粒度汇总
- ADS 日指标汇总
- 跨层对账
- 统一 DQ 汇总
- Airflow 多 Task 调度

最终目标是形成一条订单主题主线：

```text
ODS / DWD 原始订单、取消、退款数据
  -> DWD clean / dirty
  -> FCT 订单事实、状态事实、退款状态事实
  -> DWS 用户天粒度订单退款汇总
  -> ADS 订单日概览、状态日概览、退款日概览
  -> dq_check_result_di 统一质量结果
  -> Airflow 多 Task 调度验收
```

## 2. 业务问题

这个项目围绕订单域回答三个核心问题：

- 下了多少订单，产生了多少 GMV？
- 哪些订单被取消，取消后有效订单和有效 GMV 还剩多少？
- 哪些订单发生退款，扣除退款后的净 GMV 是多少？

所以它不是只看订单金额，而是同时保留几类口径：

```text
raw_order_cnt：原始清洗后订单数
valid_order_cnt：有效订单数
cancel_order_cnt：取消订单数
gross_valid_gmv：有效订单原始 GMV
refund_amount：退款金额
net_gmv：扣除取消和退款后的净 GMV
```

## 3. 分层链路

当前订单主题主线如下：

```text
dwd_order_p
  -> dwd_order_dirty_di
  -> dwd_order_clean_di
  -> fct_order_di
  -> fct_order_status_di
  -> fct_order_refund_status_di
  -> dws_user_order_day_agg
  -> dws_user_order_refund_day_agg
  -> ads_order_day_overview
  -> ads_order_status_day_overview
  -> ads_order_refund_day_overview
  -> dq_check_result_di
```

取消订单支线：

```text
dwd_order_cancel_p
  -> dwd_order_cancel_clean_di
  -> fct_order_status_di
  -> ads_order_status_day_overview
```

退款订单支线：

```text
dwd_order_refund_p
  -> dwd_order_refund_clean_di
  -> fct_order_refund_status_di
  -> dws_user_order_refund_day_agg
  -> ads_order_refund_day_overview
```

这里的重点是：取消和退款不是独立散落的 SQL，而是接进订单主题主链路里，最终共同影响有效订单、有效 GMV 和净 GMV。

## 4. DWD 层：清洗和异常治理

### dwd_order_clean_di

`dwd_order_clean_di` 是下游可信明细表，来源是 `dwd_order_p`。

清洗规则包括：

- `TRIM(order_id/user_id/order_date)`
- 过滤 `order_id` 为空
- 过滤 `user_id` 为空
- 过滤 `order_date` 为空
- 过滤 `amount` 为空
- 过滤 `amount < 0`
- 对 `order_id` 去重
- 重复订单保留最新、最可信的一条

它解决的问题是：下游事实表、汇总表和 ADS 指标不能直接依赖脏的源数据，否则 GMV、订单数、用户数都会被污染。

### dwd_order_dirty_di

`dwd_order_dirty_di` 用来保留异常明细和异常原因。

当前 dirty reason 包括：

```text
order_id_empty
user_id_empty
order_date_empty
amount_null
amount_negative
duplicate_order_id
unknown_dirty
```

面试表达时可以这样说：

```text
我没有简单把脏数据过滤掉，而是把异常数据落到 dirty 表里，并记录 dirty_reason。这样下游可以使用 clean 表保证指标可信，同时 dirty 表还能用于问题追溯和数据治理复盘。
```

## 5. FCT 层：沉淀业务事实

### fct_order_di

`fct_order_di` 是事务事实表，粒度是：

```text
一行一笔清洗后的有效订单
```

它从 `dwd_order_clean_di` 生成，用于沉淀订单明细事实，支持 GMV、订单数、下单用户数等基础指标。

### fct_order_status_di

`fct_order_status_di` 在订单事实基础上补充取消状态。

核心字段包括：

```text
order_id
user_id
amount
order_status
is_cancelled
```

当前口径：

```text
取消订单：order_status = CANCELLED，is_cancelled = 1
未取消订单：order_status = VALID，is_cancelled = 0
```

它解决的问题是：订单是否有效不应该只靠原始订单表判断，而要结合取消订单明细统一沉淀状态。

### fct_order_refund_status_di

`fct_order_refund_status_di` 在订单状态事实基础上继续补充退款状态。

核心字段包括：

```text
order_id
user_id
amount
order_status
is_cancelled
is_refunded
refund_amount
net_amount
```

退款口径：

```text
取消订单：net_amount = 0
有效未退款订单：net_amount = amount
有效已退款订单：net_amount = amount - refund_amount
```

这里最重要的建模意识是：退款不是直接改小订单金额，而是保留 `amount`、`refund_amount`、`net_amount` 三个口径。这样既能看原始交易规模，也能看退款后的净收入效果。

## 6. DWS 层：沉淀可复用汇总

### dws_user_order_day_agg

`dws_user_order_day_agg` 是旧的用户订单日汇总表，粒度是：

```text
一个用户 + 一天 一行
```

主要看有效订单：

```text
order_cnt
order_amount
avg_order_amount
```

### dws_user_order_refund_day_agg

`dws_user_order_refund_day_agg` 是退款主题补充后的用户订单退款日汇总表，粒度同样是：

```text
一个用户 + 一天 一行
```

核心指标包括：

```text
raw_order_cnt
valid_order_cnt
cancel_order_cnt
gross_valid_gmv
refund_order_cnt
refund_amount
net_gmv
```

补 DWS 的意义：

- 最小闭环可以 FCT 直接到 ADS，但完整分层更推荐补 DWS
- DWS 沉淀用户天粒度的可复用汇总
- ADS 不直接扫明细事实表，而是从 DWS 汇总
- 对账关系更清楚：DWS 对 FCT，ADS 对 DWS

## 7. ADS 层：面向报表的最终指标

### ads_order_day_overview

用于输出订单日概览，关注：

```text
订单数
下单用户数
GMV
客单价
```

### ads_order_status_day_overview

用于输出取消订单影响后的日概览，关注：

```text
raw_order_cnt
valid_order_cnt
cancel_order_cnt
raw_gmv
valid_gmv
cancel_amount
valid_order_rate
cancel_order_rate
```

### ads_order_refund_day_overview

用于输出退款影响后的日概览，关注：

```text
raw_order_cnt
valid_order_cnt
cancel_order_cnt
gross_valid_gmv
refund_order_cnt
refund_amount
net_gmv
refund_order_rate
refund_gmv_rate
```

当前 ADS 退款表的直接来源是：

```text
dws_user_order_refund_day_agg
  -> ads_order_refund_day_overview
```

所以 ADS 对账优先对 DWS，而不是绕回去直接对 FCT。

## 8. 2026-03-05 验收数据

订单 clean 后保留 3 行：

| order_id | user_id | amount |
| --- | --- | ---: |
| o2001 | u10 | 100.00 |
| o2002 | u11 | 90.00 |
| o2005 | u14 | 30.00 |

取消订单：

| order_id | user_id | cancel_reason |
| --- | --- | --- |
| o2002 | u11 | user_cancel |

退款订单：

| order_id | user_id | refund_amount | refund_reason |
| --- | --- | ---: | --- |
| o2001 | u10 | 20.00 | partial_refund |

因此最终结果应该是：

```text
o2001：有效订单，退款 20，net_amount = 80
o2002：取消订单，net_amount = 0
o2005：有效订单，未退款，net_amount = 30
```

## 9. Airflow DAG 验收

本次使用的 DAG：

```text
order_subject_daily_multi_task
```

业务日期：

```text
run_dt = 2026-03-05
```

本次 DAG run：

```text
manual__order_refund_main_20260305_codex
```

任务链路：

```text
validate_run_dt
  -> run_dwd_order_clean
  -> run_fct_order
  -> run_dws_user_order_day_agg
  -> run_ads_order_day_overview
  -> run_order_subject_dq_report
```

本次验收结果：

```text
validate_run_dt                 success
run_dwd_order_clean             success
run_fct_order                   success
run_dws_user_order_day_agg      success
run_ads_order_day_overview      success
run_order_subject_dq_report     success
```

这次没有跑支付对账支线，因为本次目标是验收订单 + 取消 + 退款主线。

## 10. 核心验数结果

### DWS 退款用户天汇总

`dws_user_order_refund_day_agg`：

| user_id | raw_order_cnt | valid_order_cnt | cancel_order_cnt | gross_valid_gmv | refund_order_cnt | refund_amount | net_gmv |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| u10 | 1 | 1 | 0 | 100.00 | 1 | 20.00 | 80.00 |
| u11 | 1 | 0 | 1 | 0.00 | 0 | 0.00 | 0.00 |
| u14 | 1 | 1 | 0 | 30.00 | 0 | 0.00 | 30.00 |

### ADS 退款日概览

`ads_order_refund_day_overview`：

| 指标 | 值 |
| --- | ---: |
| raw_order_cnt | 3 |
| valid_order_cnt | 2 |
| cancel_order_cnt | 1 |
| gross_valid_gmv | 130.00 |
| refund_order_cnt | 1 |
| refund_amount | 20.00 |
| net_gmv | 110.00 |
| refund_order_rate | 0.5000 |
| refund_gmv_rate | 0.1538 |

### 统一 DQ 汇总

`dq_check_result_di` 中 `check_status <> 'PASS'` 无结果。

按层级统计：

| layer_name | check_status | check_cnt |
| --- | --- | ---: |
| DWD | PASS | 13 |
| FCT | PASS | 15 |
| DWS | PASS | 8 |
| ADS | PASS | 18 |

## 11. DQ 和对账设计

当前质量治理分为两类：

```text
脚本内 quality SQL：跑批时拦截问题
统一 DQ 汇总：把检查结果沉淀到 dq_check_result_di
```

DWD 重点检查：

- clean 表关键字段不为空
- 金额非负
- order_id 去重后唯一
- dirty 表异常原因合法
- 取消、退款明细能匹配订单

FCT 重点检查：

- 订单事实行数和 DWD clean 对得上
- order_id 唯一
- 取消状态合法
- 退款状态合法
- `net_amount` 合法
- 退款订单数能和 DWD refund 对得上

DWS 重点检查：

- 用户天粒度不重复
- 指标非负
- `raw_order_cnt = valid_order_cnt + cancel_order_cnt`
- `net_gmv = gross_valid_gmv - refund_amount`
- DWS 汇总结果和 FCT 对得上

ADS 重点检查：

- 一天一行
- 指标非负
- 比率在 0 到 1 之间
- `raw_order_cnt = valid_order_cnt + cancel_order_cnt`
- `net_gmv = gross_valid_gmv - refund_amount`
- ADS 汇总结果和 DWS 对得上

对账原则：

```text
谁直接喂给 ADS，ADS 就先跟谁对账。
DWS 来源是 FCT，所以 DWS 对 FCT。
ADS 来源是 DWS，所以 ADS 对 DWS。
```

## 12. 工程化能力

这个项目体现的工程化点包括：

- 使用 `run_dt` 控制业务日期
- 使用 `.sql.tpl` 模板复用 SQL
- 使用 `__RUN_DT__` 渲染日期参数
- 使用 `INSERT OVERWRITE PARTITION` 保证单日重跑幂等
- PowerShell 支持 Windows 手动学习验证
- Shell 支持 Airflow 容器环境执行
- Airflow BashOperator 调用 `.sh`
- Spark SQL 在 `hadoop-spark` 容器中执行
- DQ 检查可以拦截任务，也可以沉淀到统一 DQ 表
- 多 Task DAG 可以清楚看到每一层成功或失败

执行边界：

```text
Windows 项目目录
  -> Airflow 容器 /opt/project
  -> hadoop-spark 容器执行 spark-sql
```

这个边界很重要，因为它说明当前项目不只是本机跑 SQL，而是模拟了调度容器和计算容器分离的实际工程环境。

## 13. 面试表达：项目总述

可以这样介绍：

```text
我做过一个订单主题的离线数仓综合项目，核心是把订单、取消、退款这几类业务数据按 DWD、FCT、DWS、ADS 分层建模，并接入 DQ 和 Airflow 调度。

在 DWD 层，我对原始订单做清洗，过滤关键字段为空、金额异常、重复订单等问题，同时把异常数据落到 dirty 表并记录 dirty_reason，方便追溯。

在 FCT 层，我先沉淀订单事务事实表，再结合取消订单生成订单状态事实表，最后结合退款明细生成订单退款状态事实表，保留 amount、refund_amount、net_amount 三个金额口径。

在 DWS 层，我按用户天粒度沉淀订单退款汇总，包括原始订单数、有效订单数、取消订单数、有效 GMV、退款金额和净 GMV。

在 ADS 层，我输出订单日概览、取消订单日概览和退款订单日概览，最终能看到有效订单、取消率、退款率和净 GMV 等指标。

为了保证结果可信，我在 DWD、FCT、DWS、ADS 都做了质量校验和跨层对账，并把关键检查结果统一写入 dq_check_result_di。最后我把整条订单主线接入 Airflow 多 Task DAG，用 run_dt=2026-03-05 完整跑通并验收通过。
```

## 14. 面试追问：为什么不直接改订单金额？

可以这样回答：

```text
我不会直接把订单金额改小，因为这样会丢失原始交易规模，也不利于区分取消和退款。

我的做法是保留 amount、refund_amount、net_amount 三个口径。amount 表示原始订单金额，refund_amount 表示退款金额，net_amount 表示退款后的净金额。

这样既能分析原始 GMV，也能分析退款后的净 GMV，还能单独统计退款金额和退款率。
```

## 15. 面试追问：clean 表和 dirty 表怎么理解？

可以这样回答：

```text
clean 表是下游可信数据源，主要给事实表、DWS、ADS 使用；dirty 表是异常数据明细，主要用于追溯和治理。

如果只过滤不落表，后面很难解释为什么源表 7 行到了下游只剩 3 行。dirty 表保留了异常记录和 dirty_reason，可以说明每条数据为什么不能进入下游。
```

## 16. 面试追问：FCT、DWS、ADS 的区别？

可以这样回答：

```text
FCT 是事实层，保留业务过程的明细事实，比如一行一笔订单，以及订单是否取消、是否退款、净金额是多少。

DWS 是可复用汇总层，比如一个用户一天一行，沉淀用户天粒度的订单、取消、退款指标。

ADS 是应用指标层，面向报表或分析结果，比如一天一行的订单退款概览，直接给业务看 raw_order_cnt、valid_order_cnt、refund_amount、net_gmv、refund_rate 等指标。
```

## 17. 面试追问：单表质量校验和跨层对账有什么区别？

可以这样回答：

```text
单表质量校验主要看表自己是否合理，比如主键是否重复、关键字段是否为空、金额是否非负、比率是否在 0 到 1 之间。

跨层对账主要看上下游是否一致，比如 DWS 汇总结果是否和 FCT 明细汇总一致，ADS 汇总结果是否和 DWS 一致。

单表校验解决的是表内质量问题，跨层对账解决的是链路传递过程中有没有漏数、重复或口径不一致。
```

## 18. 面试追问：Airflow 在项目里解决了什么问题？

可以这样回答：

```text
Airflow 主要解决任务编排和可观测性问题。

我把订单主题链路拆成 validate_run_dt、run_dwd_order_clean、run_fct_order、run_dws_user_order_day_agg、run_ads_order_day_overview、run_order_subject_dq_report 这些 Task。

这样每一层的依赖关系清楚，失败时可以在 Graph 和 Task Logs 里看到是哪一层失败，也可以对失败 Task 单独 Clear and Retry。
```

## 19. 当前项目亮点

这个项目可以重点讲这些亮点：

- 不是单点 SQL，而是完整订单主题链路
- clean 和 dirty 分开，兼顾下游可信和异常追溯
- 取消订单和退款订单都接入订单主线
- 退款金额没有直接覆盖订单金额，而是保留多金额口径
- FCT、DWS、ADS 分层清楚
- DWS 对 FCT、ADS 对 DWS，跨层对账关系明确
- 脚本支持 `run_dt`、模板渲染、分区覆盖和幂等重跑
- Airflow 多 Task DAG 已经跑通
- 统一 DQ 表可以沉淀质量检查结果

## 20. 后续可以扩展

短期不建议马上换新主题，可以继续围绕订单主题增强：

- 把这份复盘压缩成 1 分钟、3 分钟、5 分钟三个面试版本
- 补一张项目架构图或链路图
- 把支付对账作为独立支线复盘
- 后续用 Python 改造脚本 runner
- 增加更完整的订单生命周期建模
- 增加退款原因、全额退款、部分退款等分析，但这不是当前最优先

