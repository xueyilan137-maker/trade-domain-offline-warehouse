# trade_domain_realistic_daily DAG

## 1. 作用

`trade_domain_realistic_daily` 把交易域真实化 Python runner 接入 Airflow，用 Airflow 管理 7 天离线数仓链路的调度、依赖、日志和失败重跑。

对应 runner：

```text
/opt/project/pipeline/trade_domain_realistic_runner.py
```

本机文件：

```text
pipeline/trade_domain_realistic_runner.py
airflow/dags/trade_domain_realistic_daily_dag.py
```

## 2. Task 链路

```text
validate_params
-> run_dwd_order
-> run_fct_order
-> run_refund_anomaly
-> run_dws_ads
-> run_payment
-> run_multi_theme
```

含义：

| task_id | subject | 作用 |
| --- | --- | --- |
| validate_params | - | 校验 start_dt/end_dt 是否在 2026-03-01 ~ 2026-03-07 |
| run_dwd_order | dwd_order | 订单、取消、退款 DWD 清洗 |
| run_fct_order | fct_order | 订单事实、状态事实、退款状态事实 |
| run_refund_anomaly | refund_anomaly | 退款异常明细沉淀 |
| run_dws_ads | dws_ads | 交易域统一 DWS / ADS 指标 |
| run_payment | payment | 支付对账与异常汇总 |
| run_multi_theme | multi_theme | 用户、商品、渠道、多主题 ADS / DQ |

## 3. 手动触发参数

Airflow UI 手动 Trigger DAG 时传：

```json
{
  "start_dt": "2026-03-01",
  "end_dt": "2026-03-07"
}
```

当前 DAG 限定 demo 范围：

```text
2026-03-01 ~ 2026-03-07
```

## 4. 为什么部分 task 允许质量失败

以下 task 使用了 `--allow-quality-fail`：

```text
run_fct_order
run_dws_ads
run_multi_theme
```

原因是 2026-03-07 有一条故意设计的异常：

```text
order_id = o1503
order_amount = 50.00
refund_amount = 80.00
net_amount = -30.00
```

这条异常会导致退款状态事实、DWS/ADS、多主题 ADS 出现质量校验失败。教学项目里我们希望它继续向下游传导，方便观察异常如何被 DQ 捕获。

生产场景通常不建议默认放行这种异常，可以去掉 `--allow-quality-fail`，让任务失败阻断。

## 5. 已验证

已在 Airflow 容器中验证：

```text
airflow dags list | grep trade_domain_realistic_daily
airflow dags list-import-errors
airflow tasks list trade_domain_realistic_daily
airflow tasks test trade_domain_realistic_daily validate_params 2026-03-01
```

结果：

```text
DAG 可见
无 import error
7 个 task 可见
validate_params 测试成功
```

## 6. 面试表达

可以这样说：

```text
我把交易域真实化项目接入了 Airflow DAG。
DAG 按主题拆成 DWD、FCT、异常沉淀、DWS/ADS、支付对账、多主题分析几个 task，
每个 task 调用同一个 Python runner，只是通过 subject 参数控制跑哪条链路。
这样 Airflow UI 里可以看到每个主题的依赖关系、运行日志和失败位置，也可以单独 Clear 某个 task 重跑。
```

