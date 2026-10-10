# 用户等级日快照表练习

这套任务是拉链表练习的配套版本，用同一份 `dwd_user_info_clean_di` 输入，构建一张更直观的日快照维表：

- 拉链表回答“状态从哪天开始，到哪天结束”
- 快照表回答“某一天的全量状态是什么”

## 涉及文件

- `pipeline/sql/snapshot/00_init_user_snapshot_tables.sql`
  创建 `dim_user_snapshot_di`
- `pipeline/sql/snapshot/10_dim_user_snapshot_di.sql.tpl`
  按 `run_dt` 把当天 `dwd_user_info_clean_di` 直接写成快照分区
- `pipeline/sql/snapshot/20_dim_user_snapshot_quality.sql.tpl`
  检查分区非空、主键不重复、关键字段非空
- `pipeline/run_user_snapshot_pipeline.ps1`
  单天快照任务入口
- `pipeline/run_user_snapshot_backfill.ps1`
  区间快照回刷入口

## 表结构特点

`dim_user_snapshot_di` 是一张按 `dt` 分区的日快照表。

每个分区只回答一个问题：

“这一天结束时，每个用户的等级状态是什么？”

所以和拉链表相比：

- 快照表查询某一天更直接：`WHERE dt = '2026-04-21'`
- 快照表会重复保存没变化的用户状态
- 快照表不天然保存状态生效区间

## 推荐练习顺序

先确认你已经有这三天的 `dwd_user_info_clean_di`：

- `2026-04-20`
- `2026-04-21`
- `2026-04-22`

然后初始化快照表：

```powershell
powershell -ExecutionPolicy Bypass -File .\pipeline\run_user_snapshot_pipeline.ps1 -RunDt 2026-04-20 -InitTables -InitOnly
```

再跑区间回刷：

```powershell
powershell -ExecutionPolicy Bypass -File .\pipeline\run_user_snapshot_backfill.ps1 -StartDt 2026-04-20 -EndDt 2026-04-22
```

## 验证 SQL

查询快照表：

```sql
SELECT dt, user_id, user_name, user_level
FROM hive_demo.dim_user_snapshot_di
ORDER BY dt, user_id;
```

对照拉链表：

```sql
SELECT user_id, user_name, user_level, start_date, end_date, is_current
FROM hive_demo.dim_user_zipper
ORDER BY user_id, start_date;
```

## 你现在最应该比较的点

1. 查 `2026-04-21` 这一天，快照表只需要 `WHERE dt = '2026-04-21'`
2. 查拉链表的 `2026-04-21` 状态，需要用生效区间条件
3. 快照表更直观，拉链表更节省且更适合描述变化历史

## 一句面试表达

“我用同一份用户等级输入同时做过日快照表和拉链表。快照表按天保存全量状态，查询简单；拉链表按生效区间保存历史版本，更适合追踪慢变维变化过程。” 
