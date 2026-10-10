# 订单退款主题分层建模项目复盘

## 1. 项目背景

本项目是在已有订单主题链路基础上，继续补充退款业务场景。

原有订单主题已经支持：

- 订单 DWD 清洗
- 异常订单 dirty 落表
- 取消订单清洗
- 订单事实表
- 订单状态事实表
- DWS 用户订单日汇总
- ADS 订单日指标
- 统一 DQ 汇总

退款主题要解决的新问题是：

- 有效订单中哪些发生了退款
- 退款金额是多少
- 扣掉退款后的净 GMV 是多少
- 退款指标如何进入 DWS、ADS 和统一 DQ

最终链路：

```text
dwd_order_refund_p
  -> dwd_order_refund_clean_di
  -> fct_order_refund_status_di
  -> dws_user_order_refund_day_agg
  -> ads_order_refund_day_overview
  -> dq_check_result_di
```

## 2. 核心建模思路

退款不是简单把订单金额改小。

在数仓里，需要同时保留几个口径：

- `amount`：订单原始金额
- `order_status`：订单是否有效或取消
- `refund_amount`：退款金额
- `net_amount`：扣除退款后的净金额

这样下游既能看原始交易规模，也能看取消和退款对最终净 GMV 的影响。

本项目里的口径是：

```text
取消订单：net_amount = 0
有效未退款订单：net_amount = amount
有效已退款订单：net_amount = amount - refund_amount
```

## 3. 分层设计

### DWD 层

`dwd_order_refund_p`

退款源输入表，用来模拟业务系统里的退款记录。

`dwd_order_refund_clean_di`

退款清洗明细表，粒度是：

```text
一行一笔清洗后的退款订单
```

最小清洗规则：

- `order_id` 不为空
- `user_id` 不为空
- `refund_date` 不为空
- `refund_amount` 不为空
- `refund_amount > 0`
- 同一个 `order_id` 多条退款记录时保留一条
- 退款订单必须能匹配到 `dwd_order_clean_di`

### FCT 层

`fct_order_refund_status_di`

订单退款状态事实表，基于 `fct_order_status_di` 继续补充退款信息。

粒度是：

```text
一行一笔订单
```

核心字段：

- `order_id`
- `user_id`
- `amount`
- `order_status`
- `is_cancelled`
- `is_refunded`
- `refund_amount`
- `net_amount`

这层的作用是把订单状态、取消状态、退款状态、净金额都沉淀到订单事实粒度。

### DWS 层

`dws_user_order_refund_day_agg`

用户退款日汇总表，粒度是：

```text
一个用户 + 一天 一行
```

核心指标：

- `raw_order_cnt`
- `valid_order_cnt`
- `cancel_order_cnt`
- `gross_valid_gmv`
- `refund_order_cnt`
- `refund_amount`
- `net_gmv`

补 DWS 的原因：

- 让退款主题具备完整的 `DWD -> FCT -> DWS -> ADS` 分层表达
- 把用户天粒度的退款汇总沉淀下来，后续可以复用
- 让 ADS 不直接扫订单事实表，而是从 DWS 汇总
- 对账关系更清楚：DWS 对 FCT，ADS 对 DWS

### ADS 层

`ads_order_refund_day_overview`

退款日总览指标表，粒度是：

```text
一天一行
```

核心指标：

- `raw_order_cnt`：原始订单数
- `valid_order_cnt`：有效订单数
- `cancel_order_cnt`：取消订单数
- `gross_valid_gmv`：有效订单原始 GMV
- `refund_order_cnt`：退款订单数
- `refund_amount`：退款金额
- `net_gmv`：净 GMV
- `refund_order_rate`：退款订单率
- `refund_gmv_rate`：退款金额占有效 GMV 比例

当前 ADS 来源：

```text
dws_user_order_refund_day_agg
  -> ads_order_refund_day_overview
```

所以 ADS 跨层对账也对 DWS。

## 4. 2026-03-05 验证数据

订单清洗后有效明细：

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

## 5. 验证结果

`fct_order_refund_status_di`：

| order_id | order_status | amount | refund_amount | net_amount |
| --- | --- | ---: | ---: | ---: |
| o2001 | VALID | 100.00 | 20.00 | 80.00 |
| o2002 | CANCELLED | 90.00 | 0.00 | 0.00 |
| o2005 | VALID | 30.00 | 0.00 | 30.00 |

`dws_user_order_refund_day_agg`：

| user_id | raw_order_cnt | valid_order_cnt | cancel_order_cnt | gross_valid_gmv | refund_order_cnt | refund_amount | net_gmv |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| u10 | 1 | 1 | 0 | 100.00 | 1 | 20.00 | 80.00 |
| u11 | 1 | 0 | 1 | 0.00 | 0 | 0.00 | 0.00 |
| u14 | 1 | 1 | 0 | 30.00 | 0 | 0.00 | 30.00 |

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

## 6. 质量校验与对账

### 各层脚本内校验

DWD 退款校验：

- `order_id` 唯一
- 关键字段不为空
- 退款金额大于 0
- 退款订单能匹配订单 clean 表

FCT 退款校验：

- 订单行数和订单状态事实表一致
- `order_id` 唯一
- 退款标记合法
- `net_amount` 合法
- 退款订单数和 DWD refund 对得上

DWS 退款校验：

- 用户粒度不重复
- 指标非负
- `raw_order_cnt = valid_order_cnt + cancel_order_cnt`
- `net_gmv = gross_valid_gmv - refund_amount`
- DWS 用户粒度指标和 FCT 汇总结果对得上

ADS 退款校验：

- ADS 一天一行
- 指标非负
- 退款率在 0 到 1 之间
- `raw_order_cnt = valid_order_cnt + cancel_order_cnt`
- `net_gmv = gross_valid_gmv - refund_amount`
- ADS 汇总结果和 DWS 汇总结果对得上

### 统一 DQ 汇总

统一 DQ 表：

```text
dq_check_result_di
```

统一 DQ SQL：

```text
pipeline/sql/dq/10_order_subject_dq_report.sql.tpl
```

退款相关检查已经沉淀到统一 DQ：

| 层级 | 表 | 代表性检查 |
| --- | --- | --- |
| DWD | dwd_order_refund_clean_di | order_id_unique |
| DWD | dwd_order_refund_clean_di | refund_amount_positive |
| DWD | dwd_order_refund_clean_di | order_match_reconcile |
| FCT | fct_order_refund_status_di | refund_flag_valid |
| FCT | fct_order_refund_status_di | net_amount_valid |
| FCT | fct_order_refund_status_di | refund_count_reconcile |
| DWS | dws_user_order_refund_day_agg | fct_refund_reconcile |
| DWS | dws_user_order_refund_day_agg | net_gmv_reconcile |
| ADS | ads_order_refund_day_overview | dws_refund_reconcile |
| ADS | ads_order_refund_day_overview | rate_range_valid |

核心治理思路：

```text
各层 quality SQL：跑批时拦截问题
统一 DQ 汇总：沉淀检查结果，方便查询、复盘和展示
```

## 7. 脚本入口

DWD 清洗：

```powershell
powershell -ExecutionPolicy Bypass -File .\pipeline\run_dwd_order_clean_pipeline.ps1 -RunDt 2026-03-05 -InitTables
```

FCT 事实层：

```powershell
powershell -ExecutionPolicy Bypass -File .\pipeline\run_order_fact_pipeline.ps1 -RunDt 2026-03-05 -InitTables
```

DWS 用户日汇总：

```powershell
powershell -ExecutionPolicy Bypass -File .\pipeline\run_dws_user_order_day_agg_pipeline.ps1 -RunDt 2026-03-05 -InitTables
```

ADS 日总览：

```powershell
powershell -ExecutionPolicy Bypass -File .\pipeline\run_ads_order_day_overview_pipeline.ps1 -RunDt 2026-03-05 -InitTables
```

统一 DQ 汇总：

```bash
bash pipeline/run_order_subject_dq_report_pipeline.sh --run-dt 2026-03-05
```

## 8. 项目亮点

这不是只写了一个退款 SQL，而是完成了一条完整离线数仓小链路：

- DWD 负责清洗退款明细
- FCT 负责沉淀订单状态、退款状态和净金额
- DWS 负责用户天粒度汇总
- ADS 负责输出业务可读指标
- DQ 负责质量校验和跨层对账
- 脚本支持按 `RunDt` 幂等重跑

比较能体现数据开发意识的点：

- 没有直接改订单金额，而是保留原始金额、退款金额、净金额
- 区分取消订单和退款订单的业务含义
- 补了 DWS，让分层更完整
- ADS 对直接来源表 DWS 做跨层对账
- 统一 DQ 表能沉淀检查结果

## 9. 面试表达参考

可以这样介绍：

```text
我在订单主题数仓链路里扩展了退款场景。
首先在 DWD 层对退款明细做清洗，过滤关键字段为空、退款金额非法、无法匹配订单的记录。
然后在事实层基于订单状态事实表，沉淀订单是否退款、退款金额和净金额。
接着在 DWS 层按用户天粒度汇总原始订单数、有效订单数、取消订单数、退款金额和净 GMV。
最后在 ADS 层产出退款日总览，包括退款订单率、退款金额占比和净 GMV。
为了保证链路可信，我在 DWD、FCT、DWS、ADS 都做了质量校验，并把关键检查统一写入 dq_check_result_di。
```

如果被问为什么退款不直接改订单金额，可以回答：

```text
直接改订单金额会丢失原始交易规模，也不利于区分取消和退款。
我保留 amount、refund_amount、net_amount 三个口径，这样既能看原始 GMV，也能看退款后的净 GMV。
```

如果被问为什么要补 DWS，可以回答：

```text
最小闭环可以 FCT 直接到 ADS，但补 DWS 后分层更完整。
DWS 按用户天粒度沉淀退款汇总，后续可以复用，也能让 ADS 从汇总层读取，减少直接依赖明细事实表。
```

## 10. 后续扩展

后续可以继续增强：

- 区分部分退款和全额退款
- 增加退款原因分布
- 增加退款用户数
- 增加退款率按用户等级或渠道分析
- 将订单/取消/退款主线放到 Airflow DAG 中完整调度验收
