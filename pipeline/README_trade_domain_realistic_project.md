# 交易域真实化离线数仓项目

## 1. 项目目标

本项目是在离线数仓学习版订单主题基础上，升级出的 7 天真实化交易域离线数仓项目。

数据范围：

```text
2026-03-01 ~ 2026-03-07
```

项目目标不是堆大量数据，而是用一组小而完整的交易域样例，覆盖真实数据开发中常见的问题：

```text
订单清洗
脏数据落表
取消订单
退款订单
跨天退款
支付对账
用户 / 商品 / 渠道多主题分析
DWS / ADS 指标沉淀
DQ 质量校验
异常明细沉淀
Python 范围跑批
Airflow 调度
```

一句话总结：

```text
这是一个从源数据、数仓分层、指标口径、异常治理到工程化调度都闭环的交易域离线数仓项目。
```

## 2. 项目主链路

整体链路：

```text
真实化源数据
-> DWD 清洗
-> FCT 事实建模
-> DWS 可复用汇总
-> ADS 应用指标
-> DQ 校验 / 异常沉淀
-> Python runner
-> Airflow DAG
```

核心分层职责：

| 层级 | 职责 |
| --- | --- |
| ODS / source | 保存业务源数据或 demo 源数据 |
| DWD | 做字段规范化、脏数据识别、clean / dirty 分流 |
| FCT | 沉淀订单粒度事实，统一订单状态、退款状态、净额口径 |
| DWS | 面向复用的中间汇总，例如用户日汇总、用户等级汇总、品类汇总、渠道汇总 |
| ADS | 面向报表和分析的最终指标 |
| DQ | 做单表质量校验、跨层对账、异常明细沉淀 |

## 3. 真实化数据设计

7 天数据覆盖场景：

| 日期 | 场景 | 验证目标 |
| --- | --- | --- |
| 2026-03-01 | 正常交易日 | 验证基础订单、GMV、支付匹配 |
| 2026-03-02 | 取消订单日 | 验证取消订单不进入有效 GMV |
| 2026-03-03 | 部分退款日 | 验证退款金额和净 GMV |
| 2026-03-04 | 全额退款 + 支付金额不一致 | 验证退款和支付对账异常 |
| 2026-03-05 | 原学习样例保留日 | 保持已有订单、取消、退款、多主题样例可复现 |
| 2026-03-06 | 跨天支付 / 跨天退款 | 理解业务日期和事件日期差异 |
| 2026-03-07 | 脏数据 + 业务异常日 | 验证 dirty 表、DQ、异常传导 |

核心异常样例：

```text
重复订单：o1504 保留 80.00，70.00 进入 dirty
空 order_id：进入 dirty，dirty_reason = order_id_empty
空 user_id：进入 dirty，dirty_reason = user_id_empty
负金额：进入 dirty，dirty_reason = amount_negative
超额退款：o1503，订单 50.00，退款 80.00，净额 -30.00
支付少付：o1302，订单 88.00，支付 80.00
支付多付：o1502，订单 90.00，支付 100.00
```

## 4. DWD 清洗设计

订单 DWD 链路：

```text
dwd_order_p
-> dwd_order_clean_di
-> dwd_order_dirty_di
```

清洗规则：

```text
TRIM(order_id/user_id/order_date)
过滤 order_id 空
过滤 user_id 空
过滤 order_date 空
过滤 amount 为空
过滤 amount < 0
order_id 去重
重复订单保留 order_date DESC, user_id ASC, amount DESC 后 rn = 1
```

dirty_reason：

```text
order_id_empty
user_id_empty
order_date_empty
amount_null
amount_negative
duplicate_order_id
unknown_dirty
```

取消 / 退款 DWD：

```text
dwd_order_cancel_p -> dwd_order_cancel_clean_di
dwd_order_refund_p -> dwd_order_refund_clean_di
```

关键理解：

```text
DWD 主要处理结构性问题，例如字段为空、金额非法、重复数据。
退款金额大于订单金额属于业务口径异常，不在 DWD 直接改掉，而是保留到 FCT / DQ 暴露。
```

## 5. FCT 事实建模

核心事实表：

```text
fct_order_di
fct_order_status_di
fct_order_refund_status_di
```

粒度：

```text
fct_order_di：一行一笔 clean 订单
fct_order_status_di：一行一笔订单，带取消状态
fct_order_refund_status_di：一行一笔订单，带取消、退款、净额状态
```

核心口径：

```text
取消订单：net_amount = 0
有效未退款订单：net_amount = amount
有效已退款订单：net_amount = amount - refund_amount
```

跨天退款规则：

```text
退款事件按原订单分区归因。
例如 o1303 是 2026-03-04 的订单，2026-03-06 发生退款 10.00，
最终退款影响回填到 2026-03-04 的订单事实和指标中。
```

## 6. 异常沉淀

异常明细表：

```text
dq_order_refund_anomaly_di
```

典型异常：

```text
order_id = o1503
order_amount = 50.00
refund_amount = 80.00
net_amount = -30.00
anomaly_type = refund_amount_over_order
anomaly_level = BLOCKER
```

设计原则：

```text
不要静默修正业务异常。
DWD 保留结构合法的退款事件。
FCT 暴露业务异常。
DQ 明细表沉淀异常原因和等级。
下游可信 ADS 可以根据 BLOCKER 决定是否阻断。
```

## 7. DWS / ADS 指标口径

核心指标：

| 指标 | 含义 |
| --- | --- |
| raw_order_cnt | clean 后全部订单数 |
| valid_order_cnt | 非取消订单数 |
| cancel_order_cnt | 取消订单数 |
| raw_gmv | clean 后全部订单金额 |
| gross_valid_gmv | 有效订单退款前 GMV |
| cancel_amount | 取消订单金额 |
| refund_order_cnt | 有效订单中发生退款的订单数 |
| refund_amount | 有效订单退款金额 |
| net_gmv | 退款后的净 GMV |
| cancel_order_rate | 取消率 |
| refund_order_rate | 退款订单率 |
| refund_gmv_rate | 退款金额率 |

核心对账关系：

```text
raw_order_cnt = valid_order_cnt + cancel_order_cnt
raw_gmv = gross_valid_gmv + cancel_amount
net_gmv = gross_valid_gmv - refund_amount
```

DWS / ADS 链路：

```text
fct_order_refund_status_di
-> dws_user_order_refund_day_agg
-> ads_order_refund_day_overview
```

跨层对账原则：

```text
DWS 由 FCT 喂数，所以 DWS 对 FCT。
ADS 由 DWS 喂数，所以 ADS 对 DWS。
统一 ADS 由主题 ADS 喂数，所以统一 ADS 对主题 ADS。
```

## 8. 支付对账

支付对账链路：

```text
dwd_payment_p
-> dwd_payment_clean_di / dwd_payment_dirty_di
-> fct_payment_di
+ fct_order_di
-> dq_order_payment_reconcile_di
-> ads_order_payment_reconcile_overview
```

对账状态：

```text
matched：订单金额 = 支付金额
amount_mismatch：订单金额和支付金额不一致
order_without_payment：有订单，没有支付
payment_without_order：有支付，没有订单
```

差异金额：

```text
diff_amount = order_amount - pay_amount
```

7 天异常：

| 日期 | 异常 |
| --- | --- |
| 2026-03-01 | o1003 有订单无支付，差异 60.00 |
| 2026-03-02 | o1102 / o1103 有订单无支付，差异合计 120.00 |
| 2026-03-04 | o1302 少支付 8.00 |
| 2026-03-05 | o2002 有订单无支付，差异 90.00 |
| 2026-03-07 | o1502 多支付 10.00 |

关键理解：

```text
退款主题关注售后后的净 GMV。
支付对账关注订单应付金额和实际支付金额是否一致。
支付异常不直接改交易指标，而是作为财务一致性异常单独沉淀。
```

## 9. 用户 / 商品 / 渠道多主题

用户主题：

```text
dim_user_snapshot_di
+ fct_order_refund_status_di
-> dws_user_level_trade_day_agg
-> ads_user_level_trade_day_overview
```

商品主题：

```text
ods_order_item_di
-> dwd_order_item_clean_di
-> fct_order_item_di
+ dim_product_snapshot_di
+ fct_order_refund_status_di
-> dws_category_trade_day_agg
-> ads_category_trade_day_overview
```

渠道主题：

```text
ods_order_channel_di
-> dwd_order_channel_clean_di
-> fct_order_channel_di
+ dim_channel_snapshot_di
+ fct_order_refund_status_di
-> dws_channel_trade_day_agg
-> ads_channel_trade_day_overview
```

统一多主题：

```text
ads_user_level_trade_day_overview
+ ads_category_trade_day_overview
+ ads_channel_trade_day_overview
-> ads_trade_multi_theme_day_overview
-> dq_multi_theme_check_result_di
```

03-07 异常传导：

| theme_name | dimension_value | valid_amount | refund_amount | net_amount | refund_rate |
| --- | --- | ---: | ---: | ---: | ---: |
| product_theme | Daily Goods | 50.00 | 80.00 | -30.00 | 1.6000 |
| channel_theme | Mini Program | 50.00 | 80.00 | -30.00 | 1.6000 |

关键理解：

```text
多主题 ADS 不是重新计算交易事实。
它是把同一套交易事实接到用户等级、商品品类、渠道来源三个分析视角上。
```

## 10. DQ 质量体系

项目包含三类 DQ：

| 类型 | 例子 | 目的 |
| --- | --- | --- |
| 单表质量校验 | 主键为空、金额为负、重复订单 | 保证当前表自身可信 |
| 跨层对账 | DWS 对 FCT、ADS 对 DWS | 保证指标从上游到下游没有丢失或放大 |
| 异常明细沉淀 | 超额退款、支付不一致 | 保留可追溯的问题数据 |

统一 DQ 表：

```text
dq_check_result_di
dq_multi_theme_check_result_di
```

异常明细表：

```text
dq_order_refund_anomaly_di
dq_order_payment_reconcile_di
```

质量失败处理：

```text
生产思路：质量失败应阻断下游。
学习项目：允许部分预期异常继续传导，用来观察异常如何被后续 DQ 捕获。
```

## 11. Python Runner 工程化

封装脚本：

```text
pipeline/trade_domain_realistic_runner.py
```

支持参数：

```text
--start-dt
--end-dt
--subject
--init-tables
--init-only
--dry-run
--allow-quality-fail
--skip-process-check
```

支持 subject：

```text
dwd_order
fct_order
refund_anomaly
dws_ads
payment
multi_theme
all
```

示例：

```powershell
python pipeline/trade_domain_realistic_runner.py `
  --start-dt 2026-03-01 `
  --end-dt 2026-03-07 `
  --subject payment
```

异常观察模式：

```powershell
python pipeline/trade_domain_realistic_runner.py `
  --start-dt 2026-03-01 `
  --end-dt 2026-03-07 `
  --subject multi_theme `
  --allow-quality-fail
```

工程化能力：

```text
日期范围补数
按主题编排 SQL
SQL 模板渲染
generated SQL 留痕
Docker / Spark SQL 执行
日志记录
失败阻断
预期异常放行观察
```

## 12. Airflow 调度

DAG：

```text
airflow/dags/trade_domain_realistic_daily_dag.py
```

任务链路：

```text
validate_params
-> run_dwd_order
-> run_fct_order
-> run_refund_anomaly
-> run_dws_ads
-> run_payment
-> run_multi_theme
```

Airflow UI 手动触发参数：

```json
{
  "start_dt": "2026-03-01",
  "end_dt": "2026-03-07"
}
```

Airflow 接入价值：

```text
任务依赖可视化
按 task 查看日志
失败任务可 Clear and Retry
每个主题可独立定位问题
从脚本执行升级为调度系统执行
```

## 13. 核心文件地图

数据设计：

```text
pipeline/README_trade_domain_realistic_data_design.md
pipeline/sql/realistic/01_seed_trade_domain_7d_core_demo.sql
pipeline/sql/realistic/02_seed_trade_domain_7d_dimension_demo.sql
pipeline/sql/realistic/03_seed_trade_domain_7d_item_channel_demo.sql
```

DWD / FCT / DWS / ADS：

```text
pipeline/sql/dwd/
pipeline/sql/fact/
pipeline/sql/dws/
pipeline/sql/ads/
```

支付对账：

```text
pipeline/sql/payment/
pipeline/README_trade_domain_payment_reconcile_7d.md
```

多主题：

```text
pipeline/sql/product_theme/
pipeline/sql/channel_theme/
pipeline/sql/multi_theme/
pipeline/README_trade_domain_multi_theme_7d.md
```

异常与 DQ：

```text
pipeline/sql/dq/
pipeline/README_trade_domain_fct_refund_anomaly.md
```

工程化：

```text
pipeline/trade_domain_realistic_runner.py
pipeline/README_trade_domain_realistic_runner.md
airflow/dags/trade_domain_realistic_daily_dag.py
airflow/README_trade_domain_realistic_daily_dag.md
```

## 14. 项目复盘

这一步解决了什么问题：

```text
把单日学习样例升级成 7 天真实化交易域项目。
把单链路订单主题扩展到支付对账和多主题分析。
把 SQL 手动执行升级成 Python runner 和 Airflow DAG。
把指标计算升级成带 DQ、对账、异常沉淀的完整闭环。
```

上下游依赖：

```text
DWD 依赖源数据。
FCT 依赖 DWD clean。
DWS 依赖 FCT。
ADS 依赖 DWS 或主题 ADS。
DQ 贯穿 DWD / FCT / DWS / ADS。
Airflow 调用 Python runner 编排所有主题。
```

项目亮点：

```text
分层清晰：DWD / FCT / DWS / ADS 职责明确。
口径清晰：取消、退款、净 GMV、支付对账分开建模。
异常可追溯：dirty 表、退款异常表、支付对账表都能定位问题数据。
工程化完整：支持范围补数、日志、失败阻断、Airflow 调度。
面试可讲：能从业务场景讲到建模、指标、DQ、调度。
```

## 15. 面试表达

可以这样介绍项目：

```text
我做了一个交易域离线数仓项目，数据范围是 2026-03-01 到 2026-03-07。
项目从真实化源数据开始，覆盖正常订单、取消订单、部分退款、全额退款、跨天退款、支付金额不一致、重复订单、空主键、负金额和超额退款等场景。

数仓分层上，我按 ODS/DWD/FCT/DWS/ADS 建模。DWD 做 clean/dirty 分流，FCT 沉淀订单事实、订单状态事实、退款状态事实，DWS 做可复用汇总，ADS 输出报表指标。

指标口径上，我区分 raw_order_cnt、valid_order_cnt、cancel_order_cnt、gross_valid_gmv、refund_amount 和 net_gmv。取消订单不进入有效 GMV，退款不直接改订单金额，而是保留 amount、refund_amount、net_amount。

质量校验上，我做了单表校验、跨层对账和异常明细沉淀。比如 2026-03-07 有一笔订单金额 50、退款 80 的异常，DWD 保留结构合法事件，FCT 暴露 net_amount=-30，DQ 记录为 refund_amount_over_order，并能继续观察它传导到商品和渠道主题。

工程化上，我封装了 Python runner，支持 start_dt/end_dt 范围补数和 subject 参数按主题执行，也接入了 Airflow DAG，把 DWD、FCT、异常沉淀、DWS/ADS、支付对账、多主题分析拆成多个 task，支持日志查看和失败重跑。
```

如果面试官追问“你这个项目最核心的能力是什么”，可以回答：

```text
核心不是写了几张 SQL 表，而是我把交易域的指标口径、异常治理、跨层对账和工程化调度串成了一个可重跑、可验证、可讲清楚的离线数仓闭环。
```

