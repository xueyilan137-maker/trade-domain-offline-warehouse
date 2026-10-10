# 交易域离线数仓与数据质量治理项目

这是一个面向数据开发实习学习与展示的离线数仓项目，基于 Hive / Spark SQL / Python / Airflow / Docker 构建交易域 7 天真实化数据链路，覆盖订单、取消、退款、支付对账、用户 / 商品 / 渠道多主题分析、DQ 校验、异常沉淀、范围补数和 Airflow 调度。

## 项目目标

本项目用小规模 demo 数据模拟真实交易域数据开发场景，重点训练：

- 离线数仓分层建模：ODS / DWD / FCT / DWS / ADS
- SQL 指标开发：订单数、有效订单数、取消率、退款金额、净 GMV、支付对账异常等
- 数据质量治理：clean / dirty 分流、跨层对账、异常明细沉淀
- 工程化跑批：Python runner、日期范围补数、失败阻断、日志记录
- 调度编排：Airflow DAG、Task 依赖、日志查看、失败重跑

## 技术栈

```text
Hive
Spark SQL
Python
Airflow
Docker
Hadoop
SQL Template
```

## 核心链路

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

## 数据范围

```text
2026-03-01 ~ 2026-03-07
```

覆盖场景：

- 正常订单
- 取消订单
- 部分退款 / 全额退款
- 跨天退款
- 支付金额不一致
- 有订单无支付
- 重复订单
- 空主键
- 负金额
- 退款金额大于订单金额
- 用户 / 商品 / 渠道多主题分析

## 数仓分层

| 层级 | 作用 |
| --- | --- |
| ODS / source | 保存源数据和 demo seed 数据 |
| DWD | 字段规范化、clean / dirty 分流、基础质量处理 |
| FCT | 沉淀订单事实、订单状态事实、退款状态事实 |
| DWS | 复用型汇总层，例如用户日汇总、品类汇总、渠道汇总 |
| ADS | 面向分析和报表的最终指标层 |
| DQ | 单表校验、跨层对账、异常明细沉淀 |

## 核心主题

### 订单 / 取消 / 退款

```text
dwd_order_p
-> dwd_order_clean_di / dwd_order_dirty_di
-> fct_order_di
-> fct_order_status_di
-> fct_order_refund_status_di
-> dws_user_order_refund_day_agg
-> ads_order_refund_day_overview
```

核心口径：

```text
取消订单：net_amount = 0
有效未退款订单：net_amount = amount
有效已退款订单：net_amount = amount - refund_amount
```

### 支付对账

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
matched
amount_mismatch
order_without_payment
payment_without_order
```

### 用户 / 商品 / 渠道多主题

```text
用户主题：dim_user_snapshot_di + fct_order_refund_status_di
商品主题：fct_order_item_di + dim_product_snapshot_di + fct_order_refund_status_di
渠道主题：fct_order_channel_di + dim_channel_snapshot_di + fct_order_refund_status_di
```

最终汇总：

```text
ads_trade_multi_theme_day_overview
dq_multi_theme_check_result_di
```

## 数据质量治理

项目包含三类 DQ：

| 类型 | 示例 |
| --- | --- |
| 单表质量校验 | 主键非空、金额非负、重复订单识别 |
| 跨层指标对账 | DWS 对 FCT、ADS 对 DWS、统一 ADS 对来源 ADS |
| 异常明细沉淀 | 超额退款、支付金额不一致、有订单无支付 |

典型异常：

```text
order_id = o1503
order_amount = 50.00
refund_amount = 80.00
net_amount = -30.00
anomaly_type = refund_amount_over_order
anomaly_level = BLOCKER
```

## Python Runner

核心脚本：

```text
pipeline/trade_domain_realistic_runner.py
```

支持：

```text
--start-dt
--end-dt
--subject
--init-tables
--init-only
--dry-run
--allow-quality-fail
```

示例：

```powershell
python pipeline/trade_domain_realistic_runner.py `
  --start-dt 2026-03-01 `
  --end-dt 2026-03-07 `
  --subject payment
```

## Airflow DAG

DAG 文件：

```text
airflow/dags/trade_domain_realistic_daily_dag.py
```

Task 链路：

```text
validate_params
-> run_dwd_order
-> run_fct_order
-> run_refund_anomaly
-> run_dws_ads
-> run_payment
-> run_multi_theme
```

## 项目结构

```text
airflow/
  dags/
    trade_domain_realistic_daily_dag.py
pipeline/
  sql/
    dwd/
    fact/
    dws/
    ads/
    payment/
    product_theme/
    channel_theme/
    multi_theme/
    dq/
    realistic/
  trade_domain_realistic_runner.py
  README_trade_domain_realistic_project.md
  README_trade_domain_resume_interview.md
realtime/
  README_late_data_repair_project.md
```

## 重点文档

- [交易域真实化总项目文档](pipeline/README_trade_domain_realistic_project.md)
- [Python Runner 说明](pipeline/README_trade_domain_realistic_runner.md)
- [Airflow DAG 说明](airflow/README_trade_domain_realistic_daily_dag.md)
- [支付对账 7 天验证](pipeline/README_trade_domain_payment_reconcile_7d.md)
- [多主题 7 天回刷](pipeline/README_trade_domain_multi_theme_7d.md)
- [简历项目描述与面试问答](pipeline/README_trade_domain_resume_interview.md)

## 学习价值

这个项目完整覆盖了数据开发实习常见能力点：

- SQL 指标开发
- 离线数仓建模
- 交易域业务口径设计
- 数据质量校验
- 异常治理
- Python 跑批工程化
- Airflow 调度
- 项目复盘与面试表达

