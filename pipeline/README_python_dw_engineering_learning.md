# Python 数据开发工程化学习复盘

## 1. 学习定位

这部分学习的目标不是泛泛学习 Python 语法，而是围绕离线数仓任务，掌握数据开发中常见的工程化脚本能力。

核心目标是：

```text
把“会写 SQL”
升级为
“能用 Python 封装离线数仓跑批任务”
```

当前已经围绕订单主题项目完成了一条学习闭环：

```text
参数解析
  -> SQL 模板渲染
  -> generated SQL 产物
  -> subprocess 调外部命令
  -> docker cp
  -> docker exec spark-sql
  -> 多 step 顺序执行
  -> 日志记录
  -> 失败中断
  -> DQ 查询
  -> 范围补数
  -> 真实 DWD 小 pipeline
```

## 2. 为什么要学这部分

离线数据开发不是只写 SQL。实际工作里还要考虑：

- 这次任务跑哪一天的数据
- 同一套 SQL 如何跑不同日期
- SQL 如何提交给 Spark / Hive 执行
- 任务失败后怎么定位
- 某一步失败后后续是否继续
- 如何按日期范围补数
- 跑完后如何确认 DQ 是否通过
- generated SQL 和日志如何留存

这些能力共同构成了数据开发工程化能力。

可以用一句话概括：

```text
SQL 负责表达计算逻辑，Python runner 负责把 SQL 稳定、可控、可追溯地跑起来。
```

## 3. 已完成的学习脚本

### 3.1 run_dt 参数解析

文件：

```text
pipeline/learn_run_dt_arg.py
```

学习内容：

- 使用 `argparse` 接收 `--run-dt`
- 校验日期格式必须是 `YYYY-MM-DD`
- 漏传参数时自动报错
- 日期格式错误时给出清晰提示

示例：

```powershell
python pipeline/learn_run_dt_arg.py --run-dt 2026-03-05
```

核心理解：

```text
run_dt 是离线跑批的业务日期，用来告诉脚本这次处理哪一天的数据。
```

## 4. SQL 模板渲染

文件：

```text
pipeline/learn_render_sql_template.py
```

学习内容：

- 接收 `--run-dt`
- 接收 `--template`
- 接收 `--output`
- 读取 `.sql.tpl` 模板
- 把 `__RUN_DT__` 替换成真实业务日期
- 生成可执行 SQL 文件

示例：

```powershell
python pipeline/learn_render_sql_template.py `
  --run-dt 2026-03-05 `
  --template pipeline/sql/dwd/10_dwd_order_clean_di.sql.tpl `
  --output pipeline/generated/python_learning/10_dwd_order_clean_di.sql
```

模板中：

```sql
WHERE dt = '__RUN_DT__'
```

渲染后：

```sql
WHERE dt = '2026-03-05'
```

核心理解：

```text
SQL 模板渲染让同一份 SQL 可以跑不同业务日期，避免每天手工改 SQL。
```

## 5. subprocess 调外部命令

文件：

```text
pipeline/learn_subprocess.py
```

学习内容：

- 使用 `subprocess.run()` 执行外部命令
- 捕获 `stdout`
- 捕获 `stderr`
- 获取 `returncode`
- 当 `returncode != 0` 时失败退出

核心概念：

```text
stdout：命令正常输出结果
stderr：命令日志、警告、错误信息
returncode：命令最终是否成功
```

判断原则：

```text
returncode = 0：技术执行成功
returncode != 0：技术执行失败
```

Spark 里经常会把 WARN 输出到 `stderr`，所以不能只看 `stderr` 是否有内容来判断失败。

## 6. Python 调 Docker

文件：

```text
pipeline/learn_docker_subprocess.py
```

学习内容：

- Python 执行 `docker ps`
- Python 执行 `docker exec hadoop-spark ls /tmp`
- 打通 Python 到 Docker 容器的调用链路

核心链路：

```text
Python
  -> subprocess
  -> docker
  -> hadoop-spark 容器
```

这一步是后续执行 Spark SQL 的前提。

## 7. Python 执行 Spark SQL

文件：

```text
pipeline/learn_execute_spark_sql.py
pipeline/sql/learning/select_current_database.sql
```

学习内容：

- 接收 `--sql-file`
- `docker cp` 本地 SQL 到 `hadoop-spark:/tmp`
- `docker exec hadoop-spark /spark/bin/spark-sql -f`
- 判断 Spark SQL 的 `returncode`

执行链路：

```text
本地 SQL 文件
  -> docker cp
  -> hadoop-spark:/tmp
  -> spark-sql -f
  -> stdout / stderr / returncode
```

示例：

```powershell
python pipeline/learn_execute_spark_sql.py `
  --sql-file pipeline/sql/learning/select_current_database.sql
```

核心理解：

```text
Python 不只是生成 SQL，也可以提交 SQL 到 Spark 执行。
```

## 8. 小型 SQL runner

文件：

```text
pipeline/learn_sql_runner.py
pipeline/sql/learning/select_run_dt.sql.tpl
```

学习内容：

- 接收 `--run-dt`
- 渲染 SQL 模板
- 生成 SQL 文件
- 执行 Spark SQL

执行链路：

```text
--run-dt
  -> .sql.tpl
  -> generated SQL
  -> docker cp
  -> spark-sql -f
```

这个脚本是最小版离线数仓 Python runner。

## 9. 多 step runner

文件：

```text
pipeline/learn_multi_step_runner.py
pipeline/sql/learning/select_run_dt.sql.tpl
pipeline/sql/learning/select_current_database.sql.tpl
```

学习内容：

- 用 `STEPS` 列表定义多个 SQL 步骤
- 每个 step 包含 `name`、`template`、`output`
- 使用 `for step in steps` 顺序执行
- 每个 step 都执行模板渲染和 Spark SQL

核心结构：

```python
STEPS = [
    {
        "name": "Select run_dt and current database",
        "template": Path("..."),
        "output": Path("..."),
    },
]
```

核心理解：

```text
真实离线任务通常不是一个 SQL，而是一组有顺序的 SQL step。
```

这对应 PowerShell 脚本里的：

```powershell
Invoke-TemplateStep
Invoke-TemplateStep
Invoke-QualityChecks
```

## 10. 日志记录

文件：

```text
pipeline/learn_multi_step_runner.py
```

学习内容：

- 生成日志文件到 `pipeline/logs`
- 使用 `log_info()` 同时写终端和日志文件
- 记录 pipeline 开始、step 开始、命令、returncode、stdout、stderr、step 结束、pipeline 结束

日志示例：

```text
pipeline/logs/learn_multi_step_runner_2026-03-05_20260515_105117.log
```

核心理解：

```text
日志是给未来排查问题的自己留运行现场。
```

失败时可以通过日志回答：

- 跑的是哪一天
- 失败在哪个 step
- 执行了哪个 SQL
- 命令 returncode 是多少
- Spark 输出了什么错误

## 11. 异常处理和失败中断

文件：

```text
pipeline/learn_multi_step_runner.py
pipeline/sql/learning/select_not_exist_table.sql.tpl
```

学习内容：

- 故意查询不存在的表
- Spark SQL 返回 `returncode=1`
- runner 抛异常
- pipeline 停止
- 后续 step 不再执行
- 失败原因写入日志

核心理解：

```text
某一步失败后，后面的步骤不能继续跑。
```

原因是如果上游失败，下游继续跑可能会使用旧数据、空数据或不完整数据。

## 12. DQ 查询和阻断

文件：

```text
pipeline/sql/learning/check_dq_failures.sql.tpl
pipeline/learn_multi_step_runner.py
```

DQ 查询 SQL：

```sql
SELECT
  layer_name,
  table_name,
  check_name,
  check_status,
  err_msg
FROM dq_check_result_di
WHERE dt = '__RUN_DT__'
  AND check_status <> 'PASS'
ORDER BY layer_name, table_name, check_name;
```

学习内容：

- runner 增加 `--check-dq`
- 技术执行成功后查询 DQ 非 PASS 记录
- 如果 DQ 查询结果为空，说明没有失败项
- 如果 DQ 查询 `stdout` 有内容，说明查到非 PASS 记录，runner 失败退出

核心区别：

```text
技术执行失败：
spark-sql returncode != 0

数据质量失败：
DQ 查询 returncode = 0，但 stdout 查到了非 PASS 记录
```

核心理解：

```text
SQL 技术执行成功，并不代表数据质量一定通过。
```

## 13. 范围补数

文件：

```text
pipeline/learn_backfill_runner.py
```

学习内容：

- 接收 `--start-dt`
- 接收 `--end-dt`
- 校验日期格式
- 校验 `start_dt <= end_dt`
- 使用 `date_range()` 生成日期序列
- 对每一天复用单日跑批逻辑
- 按日期目录保存 generated SQL

示例：

```powershell
python pipeline/learn_backfill_runner.py `
  --start-dt 2026-03-04 `
  --end-dt 2026-03-05
```

生成目录：

```text
pipeline/generated/python_learning/backfill/2026-03-04/
pipeline/generated/python_learning/backfill/2026-03-05/
```

核心理解：

```text
范围补数 = 把一段日期拆成一天一天的 run_dt，然后复用单日跑批逻辑。
```

工作场景：

- 补跑历史分区
- 回刷一段时间的数据
- 修复 SQL 逻辑后重算历史指标
- 某几天调度失败后批量补数

## 14. 真实 DWD 小 pipeline

文件：

```text
pipeline/learn_dwd_order_clean_runner.py
```

真实 DWD steps：

```text
DWD Order Dirty Capture
DWD Order Clean
DWD Order Cancel Clean
DWD Order Refund Clean
DWD Order Clean Quality
DWD Order Dirty Quality
DWD Order Cancel Quality
DWD Order Refund Quality
```

对应 SQL：

```text
pipeline/sql/dwd/11_dwd_order_dirty_di.sql.tpl
pipeline/sql/dwd/10_dwd_order_clean_di.sql.tpl
pipeline/sql/dwd/12_dwd_order_cancel_clean_di.sql.tpl
pipeline/sql/dwd/13_dwd_order_refund_clean_di.sql.tpl
pipeline/sql/dwd/20_dwd_order_clean_quality.sql.tpl
pipeline/sql/dwd/30_dwd_order_dirty_quality.sql.tpl
pipeline/sql/dwd/40_dwd_order_cancel_quality.sql.tpl
pipeline/sql/dwd/50_dwd_order_refund_quality.sql.tpl
```

### dry-run

命令：

```powershell
python pipeline/learn_dwd_order_clean_runner.py `
  --run-dt 2026-03-05 `
  --dry-run
```

作用：

```text
只渲染 SQL，不执行 Spark SQL。
```

适合先检查：

- 模板路径是否正确
- `__RUN_DT__` 是否替换
- generated SQL 是否生成
- step 顺序是否合理

### 真正执行

命令：

```powershell
python pipeline/learn_dwd_order_clean_runner.py --run-dt 2026-03-05
```

执行结果：

```text
8 个 DWD step 全部 returncode=0
DWD order clean learning runner finished successfully.
```

验数结果：

```text
dwd_order_clean_di          3
dwd_order_dirty_di          4
dwd_order_cancel_clean_di   1
dwd_order_refund_clean_di   1
```

核心理解：

```text
学习版 runner 的结构，已经可以套到真实业务 SQL pipeline 上。
```

## 15. 当前已经掌握的能力

现在已经掌握：

```text
参数解析
日期校验
SQL 模板渲染
generated SQL 产物管理
subprocess 调命令
docker cp
docker exec spark-sql
stdout / stderr / returncode 理解
多 step 顺序执行
日志记录
失败中断
DQ 查询和阻断
范围补数
dry-run
真实 DWD pipeline 封装
```

这已经构成了一个初级数据开发很实用的 Python 工程化闭环。

## 16. 面试表达

可以这样说：

```text
我在离线数仓项目里做过 Python 数据开发工程化脚本练习。最开始从 run_dt 参数解析做起，然后实现 SQL 模板渲染，把 __RUN_DT__ 替换成业务日期，并生成可执行 SQL 文件。

后面我用 subprocess 封装 docker cp 和 docker exec，把本地 SQL 复制到 Spark 容器并通过 spark-sql -f 执行。为了让任务更接近真实跑批，我把多个 SQL 定义成 steps，按顺序执行，每一步都会记录日志、检查 returncode，失败时立即中断。

之后我又补充了 DQ 查询逻辑，任务技术执行成功后会查询 dq_check_result_di 中是否有非 PASS 记录，如果查到失败项就让 runner 失败退出。同时还实现了 start_dt/end_dt 范围补数，本质是把日期区间拆成多个 run_dt，复用单日跑批逻辑。

最后我把这个 runner 思路套到了真实的 DWD 订单清洗链路上，封装了 dirty capture、order clean、cancel clean、refund clean 以及对应质量校验，并用 run_dt=2026-03-05 完整执行通过。
```

如果被问这部分解决了什么，可以回答：

```text
它解决的是 SQL 到工程化执行的问题。SQL 负责计算逻辑，Python runner 负责参数化、模板渲染、任务提交、日志、失败中断、补数和 DQ 验收。
```

## 17. 后续可以继续增强

后续可以继续扩展：

- 把 DWD runner 抽象成通用 runner 配置
- 用 YAML / JSON 配置 steps
- 增加 `--start-dt / --end-dt` 到真实 DWD runner
- 增加 `--init-tables`
- 增加更清晰的日志级别：INFO / WARN / ERROR
- 增加运行元数据表
- 将 Python runner 接入 Airflow BashOperator

当前阶段不需要一次性做复杂框架。最重要的是已经理解：

```text
离线数仓任务如何从 SQL 变成可运行、可重跑、可追溯、可校验的工程化任务。
```

