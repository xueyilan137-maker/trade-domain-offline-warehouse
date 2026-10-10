# 交易域真实化 Python Runner

## 1. 目标

`pipeline/trade_domain_realistic_runner.py` 用来把 7 天真实化交易域项目从手动分天跑 SQL，升级成可传日期范围和主题的工程化跑批脚本。

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

## 2. 支持的 subject

| subject | 作用 |
| --- | --- |
| dwd_order | 订单、取消、退款 DWD 清洗和质量校验 |
| fct_order | 订单事实、订单状态事实、退款状态事实 |
| refund_anomaly | 退款异常明细沉淀 |
| dws_ads | 交易域统一 DWS / ADS 指标 |
| payment | 支付清洗、支付事实、订单支付对账、支付 ADS |
| multi_theme | 用户、商品、渠道、多主题统一 ADS / DQ |
| all | 按依赖顺序执行以上所有主题 |

执行顺序：

```text
dwd_order
-> fct_order
-> refund_anomaly
-> dws_ads
-> payment
-> multi_theme
```

## 3. 常用命令

只渲染 SQL，不执行 Spark：

```powershell
python pipeline/trade_domain_realistic_runner.py `
  --start-dt 2026-03-01 `
  --end-dt 2026-03-07 `
  --subject multi_theme `
  --dry-run
```

初始化某个主题相关表：

```powershell
python pipeline/trade_domain_realistic_runner.py `
  --start-dt 2026-03-01 `
  --end-dt 2026-03-07 `
  --subject payment `
  --init-tables `
  --init-only
```

回刷支付对账 7 天：

```powershell
python pipeline/trade_domain_realistic_runner.py `
  --start-dt 2026-03-01 `
  --end-dt 2026-03-07 `
  --subject payment
```

回刷多主题 7 天，并允许 03-07 的预期质量异常继续执行：

```powershell
python pipeline/trade_domain_realistic_runner.py `
  --start-dt 2026-03-01 `
  --end-dt 2026-03-07 `
  --subject multi_theme `
  --allow-quality-fail
```

## 4. 严格模式和异常观察模式

默认是严格模式：

```text
如果质量 SQL 输出包含 check failed，runner 会失败退出。
```

适合：

```text
正常生产跑批
不希望异常数据继续向下游扩散
```

`--allow-quality-fail` 是异常观察模式：

```text
如果质量 SQL 输出 check failed，runner 会记录 WARN，但继续跑后续日期或主题。
```

适合：

```text
学习和验证异常传导
例如 2026-03-07 的 o1503 退款金额大于订单金额
```

## 5. 输出位置

生成 SQL：

```text
pipeline/generated/trade_domain_realistic_runner/{subject}/{run_dt}/{subject}_{run_dt}.sql
```

日志：

```text
pipeline/logs/trade_domain_realistic_runner_{subject}_{start_dt}_{end_dt}_{timestamp}.log
```

## 6. 和单 SQL runner 的区别

`learn_sql_runner.py`：

```text
一次只跑一份 SQL 模板
适合学习单个 SQL 的渲染和执行
```

`trade_domain_realistic_runner.py`：

```text
按日期范围循环
按 subject 编排多份 SQL
每个 subject 每天合并成一份 SQL 执行
支持 init、dry-run、质量失败阻断和异常观察
```

这更接近真实离线数仓里“主题级跑批脚本”的形态。

## 7. 面试表达

可以这样说：

```text
我把原来手动执行的 SQL 模板封装成了一个 Python 跑批 runner。
它支持 start_dt/end_dt 做范围补数，也支持 subject 参数按主题执行，比如 DWD、FCT、支付对账、多主题 ADS。
脚本会渲染 SQL 模板、生成可追踪的 generated SQL、复制到 Spark 容器执行，并记录日志。
同时我保留了严格质量校验模式，遇到 check failed 会阻断；也支持 allow-quality-fail，用于学习项目里观察异常如何向下游传导。
```

