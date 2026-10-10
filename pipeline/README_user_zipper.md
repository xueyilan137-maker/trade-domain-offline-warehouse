# 用户等级拉链表工程化练习

这套任务把原来的最小拉链表 SQL 练习升级成了可参数化的离线任务，重点是把三件事连起来：

1. `ODS -> DWD -> DIM` 的任务拆分
2. `run_dt` 跑批日驱动的单日执行和区间回刷
3. 可复用的脚本、日志、质量校验、Airflow DAG

## 目录说明

- `pipeline/sql/zipper/00_init_user_zipper_tables.sql`
  创建 `ods_user_info_di`、`dwd_user_info_clean_di`、`dim_user_zipper`、`dim_user_zipper_tmp`
- `pipeline/sql/zipper/01_seed_ods_user_info_di_demo.sql`
  演示数据，方便本地直接验证三天拉链变化
- `pipeline/sql/zipper/10_dwd_user_info_clean.sql.tpl`
  `ODS -> DWD` 清洗模板，包含空值过滤、字符串标准化、练习版去重
- `pipeline/sql/zipper/20_dim_user_zipper_merge.sql.tpl`
  拉链更新模板，核心是 `changed / carry_forward / closed / opened`
- `pipeline/sql/zipper/30_dim_user_zipper_quality.sql.tpl`
  基础质量校验
- `pipeline/run_user_zipper_pipeline.ps1`
  Windows 单日跑批入口
- `pipeline/run_user_zipper_backfill.ps1`
  Windows 多天回刷入口
- `pipeline/run_user_zipper_pipeline.py`
  Python 版单日跑批入口，也可给 Airflow 直接调用
- `airflow/dags/dim_user_zipper_pipeline_dag.py`
  两任务 DAG：先初始化，再执行跑批

## 任务流转

1. `ods_user_info_di`
   每天一份用户快照分区
2. `dwd_user_info_clean_di`
   做基础清洗和练习版去重
3. `dim_user_zipper`
   保存历史版本和当前版本

这版拉链 SQL 做了一个对练习更友好的处理：
如果某个用户当天没有出现在 `today` 数据里，不会直接被关闭，而是先继续保留当前版本。
这样既兼容“全量日快照”练习，也避免因为当天源数据不完整而误关链。

## 本地演示

先初始化表：

```powershell
powershell -ExecutionPolicy Bypass -File .\pipeline\run_user_zipper_pipeline.ps1 -RunDt 2026-04-20 -InitTables -InitOnly
```

再把演示数据灌入 `ods_user_info_di`：

```powershell
docker cp .\pipeline\sql\zipper\01_seed_ods_user_info_di_demo.sql hadoop-spark:/tmp/01_seed_ods_user_info_di_demo.sql
docker exec hadoop-spark bash -lc "/spark/bin/spark-sql --master local[*] -f /tmp/01_seed_ods_user_info_di_demo.sql"
```

按天跑：

```powershell
powershell -ExecutionPolicy Bypass -File .\pipeline\run_user_zipper_pipeline.ps1 -RunDt 2026-04-20
powershell -ExecutionPolicy Bypass -File .\pipeline\run_user_zipper_pipeline.ps1 -RunDt 2026-04-21
powershell -ExecutionPolicy Bypass -File .\pipeline\run_user_zipper_pipeline.ps1 -RunDt 2026-04-22
```

或者直接区间回刷：

```powershell
powershell -ExecutionPolicy Bypass -File .\pipeline\run_user_zipper_backfill.ps1 -StartDt 2026-04-20 -EndDt 2026-04-22 -InitTables
```

验证结果：

```sql
SELECT *
FROM hive_demo.dim_user_zipper
ORDER BY user_id, start_date;
```

预期你会看到：

- `u1001` 从 `NORMAL` 变成 `VIP`
- `u1002` 从 `VIP` 变成 `SVIP`
- `u1003`、`u1004` 是新增用户

## Airflow 触发示例

在 Airflow UI 里触发 `dim_user_zipper_pipeline`，传入：

```json
{
  "run_dt": "2026-04-22"
}
```

## 常见环境问题

如果你看到类似下面的报错：

`ERROR XSDB6: Another instance of Derby may have already booted the database /metastore_db`

说明 `hadoop-spark` 容器里可能还残留着旧的 `spark-sql` 进程，占住了本地 metastore 锁。

可以先检查：

```powershell
docker exec hadoop-spark bash -lc "ps -ef | grep -E 'spark-sql|SparkSQLCLIDriver' | grep -v grep"
```

确认是残留进程后，再清掉它：

```powershell
docker exec hadoop-spark bash -lc "kill <pid>"
```

然后重新执行拉链任务。

## 当前这版最值得你会讲的点

1. 为什么不能边读 `dim_user_zipper` 边 `insert overwrite` 回自己，所以要加 `dim_user_zipper_tmp`
2. 为什么离线拉链表也需要 `run_dt` 参数，才能支持补数和重跑
3. 为什么会拆出 `DWD clean` 这一步，而不是让 ODS 直接参与拉链合并
4. 为什么拉链表和快照表不是二选一，而是不同场景下的不同建模方式

## 面试表达模板

你可以把这段任务概括成一句更像工作的表达：

“我把用户等级维度做成了带跑批日参数的离线拉链任务。任务按 `ODS -> DWD clean -> DIM zipper` 拆分，支持单天重跑和区间回刷，并且通过临时表规避了 `insert overwrite` 读写同表的问题，还补了基础质量校验和 Airflow DAG。” 
