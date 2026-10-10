# 离线数仓工程化调度项目

## 1. 项目定位

这个项目用于沉淀离线数仓从“能写 SQL”到“能稳定跑批”的工程化能力。

它关注的问题不是某一个指标怎么算，而是：

- 如何按业务日期 `run_dt` 跑一条离线链路
- 如何用 SQL 模板支持每日跑批和补数
- 如何让重跑具备幂等性
- 如何记录日志、定位失败
- 如何用 Airflow 编排多 Task 依赖
- 如何处理 DQ 结果和任务状态之间的关系

这类能力很适合在面试中补充说明：你不只是会写数仓分层 SQL，也理解实际离线任务如何执行、补数、重跑和调度。

## 2. 工程链路

早期最小链路：

```text
run_daily_pipeline.ps1 / run_daily_pipeline.sh
  -> 10_dwd_daily.sql.tpl
  -> 20_dws_daily.sql.tpl
  -> 30_ads_daily.sql.tpl
  -> 40_quality_checks.sql.tpl
```

订单主题多脚本链路：

```text
run_order_subject_daily_pipeline.ps1
  -> run_dwd_order_clean_pipeline.ps1
  -> run_order_fact_pipeline.ps1
  -> run_dws_user_order_day_agg_pipeline.ps1
  -> run_ads_order_day_overview_pipeline.ps1
  -> run_order_subject_dq_report_pipeline.sh
```

Airflow 多 Task 链路：

```text
validate_run_dt
  -> run_dwd_order_clean
  -> run_fct_order
  -> run_dws_user_order_day_agg
  -> run_ads_order_day_overview
  -> run_order_subject_dq_report
  -> run_order_payment_reconcile
```

## 3. 涉及文件

基础离线跑批：

- `pipeline/run_daily_pipeline.ps1`
- `pipeline/run_daily_pipeline.sh`
- `pipeline/run_backfill_range.ps1`
- `pipeline/sql/00_init_partition_tables.sql`
- `pipeline/sql/10_dwd_daily.sql.tpl`
- `pipeline/sql/20_dws_daily.sql.tpl`
- `pipeline/sql/30_ads_daily.sql.tpl`
- `pipeline/sql/40_quality_checks.sql.tpl`
- `airflow/dags/dw_daily_pipeline_dag.py`

订单主题工程化：

- `pipeline/run_order_subject_daily_pipeline.ps1`
- `pipeline/run_dwd_order_clean_pipeline.ps1`
- `pipeline/run_order_fact_pipeline.ps1`
- `pipeline/run_dws_user_order_day_agg_pipeline.ps1`
- `pipeline/run_ads_order_day_overview_pipeline.ps1`
- `pipeline/run_order_subject_dq_report_pipeline.sh`
- `pipeline/run_order_payment_reconcile_pipeline.sh`
- `airflow/dags/order_subject_daily_multi_task_dag.py`

通用脚本能力：

- `pipeline/lib/spark_sql_runner.sh`
- `pipeline/generated/`
- `pipeline/logs/`

## 4. 参数化跑批

当前离线脚本统一围绕 `run_dt` 执行。

PowerShell 示例：

```powershell
powershell -ExecutionPolicy Bypass -File .\pipeline\run_daily_pipeline.ps1 -RunDt 2026-03-03
```

Shell 示例：

```bash
bash /opt/project/pipeline/run_daily_pipeline.sh --run-dt 2026-03-03
```

`run_dt` 的作用是把业务日期从脚本传入 SQL 模板，例如：

```sql
WHERE dt = '__RUN_DT__'
```

脚本运行时会把 `__RUN_DT__` 替换成真实日期，并生成可执行 SQL 文件到 `pipeline/generated/`。

这个设计的价值是：

- 同一套 SQL 可以跑不同业务日期
- 支持补数和重跑
- SQL 模板和执行产物分离
- 日志里能明确看到本次处理的是哪一天

## 5. SQL 模板渲染与执行

当前执行模式是：

```text
.sql.tpl
  -> 替换 __RUN_DT__
  -> pipeline/generated/*.sql
  -> docker cp 到 hadoop-spark:/tmp
  -> spark-sql -f 执行
```

PowerShell 脚本里对应能力：

- `New-SqlFromTemplate`
- `Invoke-SparkSqlFile`
- `Invoke-TemplateStep`
- `Invoke-QualityChecks`

Shell 脚本里对应能力：

- `new_sql_from_template`
- `invoke_spark_sql_file`
- `invoke_template_step`
- `invoke_check_template`

`pipeline/lib/spark_sql_runner.sh` 已经把 Shell 版本的通用执行逻辑抽出来，减少多个 `.sh` 脚本重复写模板渲染、拷贝 SQL、执行 Spark SQL、记录日志的代码。

## 6. 幂等性设计

当前多数离线表使用分区覆盖：

```sql
INSERT OVERWRITE TABLE xxx PARTITION (dt='__RUN_DT__')
```

这意味着：

- 同一天重跑不会追加重复数据
- 只覆盖当前业务日期分区
- 只要源数据和计算逻辑不变，结果可重复

已经具备分区幂等的典型表包括：

- `dwd_order_clean_di`
- `dwd_order_dirty_di`
- `fct_order_di`
- `dws_user_order_day_agg`
- `ads_order_day_overview`
- `dwd_payment_clean_di`
- `dwd_payment_dirty_di`
- `fct_payment_di`
- `dq_order_payment_reconcile_di`
- `ads_order_payment_reconcile_overview`
- `dq_check_result_di`

这个点非常适合面试时讲，因为离线数仓里补数、重跑、失败重试都依赖幂等设计。

## 7. 补数与重跑

单日重跑：

```powershell
powershell -ExecutionPolicy Bypass -File .\pipeline\run_daily_pipeline.ps1 -RunDt 2026-03-03
```

范围补数：

```powershell
powershell -ExecutionPolicy Bypass -File .\pipeline\run_backfill_range.ps1 -StartDt 2026-03-01 -EndDt 2026-03-03
```

`run_backfill_range.ps1` 的逻辑是：

```text
解析 StartDt / EndDt
  -> 按天循环
  -> 每天调用 run_daily_pipeline.ps1
  -> 某天失败则停止
```

这体现了一个很重要的工程思路：补数不是重新写一套逻辑，而是复用单日跑批入口，通过日期参数驱动多次执行。

## 8. 日志与失败定位

脚本会为每次运行生成日志文件，目录是：

```text
pipeline/logs/
```

日志文件名通常包含：

- 脚本名
- `run_dt`
- 执行时间
- 进程 ID 或短 run id

例如：

```text
run_order_fact_pipeline_2026-03-05_20260508_145520_585_52156.log
```

日志里会记录：

- pipeline started
- 当前 `RunDt`
- SQL 文件执行过程
- Spark 输出
- WARN / ERROR
- DQ 是否通过
- 最终成功或失败

这个能力对应生产中的基本要求：任务失败时，要能通过日志定位失败在哪一层、哪个 SQL、哪一天。

## 9. Airflow 单 Task DAG

早期 DAG：

- `airflow/dags/dw_daily_pipeline_dag.py`

它用一个 `BashOperator` 调用主脚本：

```python
bash_command=(
    "bash /opt/project/pipeline/run_daily_pipeline.sh "
    "--run-dt {{ dag_run.conf.get('run_dt', ds) }}"
)
```

这个版本适合理解：

- DAG 是任务编排入口
- BashOperator 可以调用 Shell 脚本
- `dag_run.conf` 可以传入手动触发参数
- 如果没有传 `run_dt`，可以退回到 Airflow 的 `ds`

它的缺点是：整条链路只有一个 Task，失败时 Airflow 图上看不出是 DWD、DWS、ADS 还是 DQ 失败，需要进入脚本日志排查。

## 10. Airflow 多 Task DAG

当前订单主题多 Task DAG：

- `airflow/dags/order_subject_daily_multi_task_dag.py`

任务结构：

```text
validate_run_dt
  -> run_dwd_order_clean
  -> run_fct_order
  -> run_dws_user_order_day_agg
  -> run_ads_order_day_overview
  -> run_order_subject_dq_report
  -> run_order_payment_reconcile
```

它比单 Task DAG 更适合工程化复盘：

- 每一层是独立 Task
- 失败位置在 Airflow Graph 里更直观
- 可以单独 Clear and Retry 某个失败 Task
- 任务依赖符合数据血缘
- `validate_run_dt` 提前校验参数格式和样例日期范围

当前 `validate_run_dt` 做了两类检查：

- `run_dt` 必须是 `YYYY-MM-DD`
- `run_dt` 必须在样例范围 `2026-03-01` 到 `2026-03-05`

这体现了调度层参数治理：尽早失败，避免错误日期进入下游计算。

## 11. Airflow 与 Docker 执行边界

当前环境里有三个关键位置：

```text
Windows 本机项目目录
  -> Airflow 容器 /opt/project
  -> hadoop-spark 容器 /tmp/*.sql
```

需要区分：

- Airflow 容器通过 volume 挂载看到 `/opt/project`
- `.sh` 脚本在 Airflow 容器中执行
- 真正的 Spark SQL 在 `hadoop-spark` 容器里执行
- SQL 文件需要先从 Airflow 容器可见路径 `docker cp` 到 `hadoop-spark:/tmp`

这也是你当前项目很有价值的地方：它不是只在本地执行 SQL，而是已经模拟了调度容器和计算容器分离的工程环境。

## 12. DQ 与任务状态

当前 DQ 有两种形态：

第一种是脚本内质量校验：

- 例如 `20_fct_order_quality.sql.tpl`
- 如果输出包含 `check failed`，脚本直接失败
- Airflow Task 也会失败

第二种是 DQ 汇总入表：

- `dq_check_result_di`
- `pipeline/sql/dq/10_order_subject_dq_report.sql.tpl`
- `pipeline/sql/payment/50_order_payment_dq_report.sql.tpl`

这种方式会把检查项写入汇总表，记录：

- pipeline
- layer
- table
- check_name
- check_status
- err_msg
- dt

订单支付对账中出现过一种典型情况：Airflow Task 成功，但 `dq_check_result_di` 里有业务对账 FAIL。

这说明：

- Airflow 成功表示任务技术执行成功
- DQ FAIL 表示数据质量或业务对账发现异常
- 是否让 Airflow 失败，要看该 DQ 是强阻断还是观察告警

这是很成熟的工程化思路，后续可以扩展成：

- 强规则失败：直接让 Task 失败
- 弱规则失败：写 DQ 表并告警
- 对账异常：保留明细，供业务或数据开发排查

## 13. 项目当前能力边界

当前项目已经具备：

- 参数化跑批
- SQL 模板渲染
- 生成 SQL 产物
- Docker 容器内 Spark SQL 执行
- 分区覆盖幂等
- 单日重跑
- 范围补数
- 日志记录
- 内嵌 DQ
- Airflow 单 Task DAG
- Airflow 多 Task DAG
- 支付对账链路接入调度

当前还可以增强：

- 统一 PowerShell / Shell / Python runner
- 把更多 DQ 拆成独立 Airflow Task
- 增加失败告警
- 增加任务运行元数据表
- 支持并发日期补数和依赖控制
- 将样例日期校验改成配置化

## 14. 面试表达

可以这样讲：

> 我在离线数仓项目里做过一套跑批工程化实践。SQL 使用 `.sql.tpl` 模板，通过 `run_dt` 渲染成具体业务日期的 SQL，再复制到 Spark 容器执行。各层表采用 `INSERT OVERWRITE PARTITION` 保证同一天重跑幂等。脚本会记录日志、执行质量校验，也支持按日期范围补数。后面我把订单主题链路接入 Airflow，从单 Task DAG 演进到多 Task DAG，把 DWD、FCT、DWS、ADS、DQ、支付对账拆成独立任务，并通过 `validate_run_dt` 提前校验参数。

如果继续追问 DQ 和 Airflow 状态，可以补充：

> 我区分技术失败和数据质量失败。脚本执行错误会让 Airflow Task 失败；一些业务对账异常可以先写入 `dq_check_result_di`，让任务技术上成功，但在 DQ 汇总表中保留 FAIL 明细。生产中可以按规则等级决定是否阻断调度。

## 15. 后续扩展方向

这个项目后续最适合继续升级为 Python 数据开发脚本化项目：

- 用 Python 统一替代部分 PowerShell 逻辑
- 封装参数解析、模板渲染、Docker/Spark 调用、日志、异常处理
- 支持 `--run-dt`、`--start-dt`、`--end-dt`
- 支持 dry-run 和只生成 SQL
- 支持读取配置文件定义任务链路
- 把 DQ 检查结果结构化输出

这样它会从“会跑脚本”升级成“能设计离线数仓任务执行框架”。
