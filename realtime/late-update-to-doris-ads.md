# 实时数仓下一步：迟到修正结果如何正确落 Doris / ADS

你现在已经走到了一个很关键的位置：

主链路已经不是问题，真正要掌握的是：

`Kafka 原始流 -> Flink 窗口聚合 -> 结果 topic -> Doris ADS 结果表`

这里的难点不是“能不能写进去”，而是：

同一个窗口的结果被迟到数据修正之后，下游是不是还能把它当成一次“更新”正确承接。

## 1. 先把这件事翻译成数仓语言

你现在面对的不是“明细 append”，而是“聚合结果 upsert”。

同一个业务键会出现多次结果版本，例如：

1. `09:20:00 ~ 09:20:10` 这个窗口先算出 `pv=4`
2. 窗口关闭后，allowed lateness 范围内又来了一条迟到 visit
3. Flink 会重新输出这个窗口，结果变成 `pv=5`
4. 下游 Doris 不能再把它当成一条新事实简单追加
5. Doris 必须把这个窗口主键对应的旧值 `4` 更新成新值 `5`

这就是你现在这一步真正要吃透的核心。

## 2. 结果 topic 里应该长什么样

对于实时 ADS 结果表，结果 topic 最好承载“可更新的结果行”，而不是只放一个裸指标值。

建议最少带上这些字段：

1. `metric_code`
2. `window_start`
3. `window_end`
4. `pv`
5. `update_time`
6. `version_ts`

其中最关键的是两类字段：

1. 业务唯一键
   `metric_code + window_start + window_end`
2. 版本字段
   `version_ts`

这样同一个窗口即使被重复输出多次，Doris 也知道它们其实是在更新同一行。

## 3. Doris 表为什么不能只靠 append

如果 Doris 结果表用的是纯追加思维，比如 Duplicate Key，那么你会得到：

1. 同一个窗口有多条记录
2. 一条是旧值 `pv=4`
3. 一条是修正后的 `pv=5`

这对 ADS 查询是危险的，因为：

1. 看板可能读到旧值
2. 汇总时可能重复累加
3. 结果流已经是“聚合结果”，再重复叠加就会把口径搞错

所以这里应该使用：

1. `UNIQUE KEY`
2. `Merge-on-Write`
3. 必要时再加 `sequence column`

这正是 `olap/sql/10_create_ads_rt_visit_pv_10s.sql` 里那张表的设计思路。

## 4. 为什么我又加了 version_ts

你已经理解了：

1. Flink 自己可以做到很强的一致性
2. 但最终结果是否正确，还要看 sink / 下游表怎么承接

`version_ts` 的价值就在这里：

如果同一个窗口结果因为重放、重启、补发，出现“旧版本晚到”的情况，Doris 可以按更大的版本号保留新值。

你可以把它理解成：

1. 主键回答“是不是同一行”
2. 版本列回答“同一行里谁更新谁”

这一步很像离线数仓里的“幂等 + 覆盖”，只是现在发生在实时结果层。

## 5. 你现在这一步最推荐的建模方式

对你当前学习阶段，我建议先坚持“整行 upsert”，不要一上来做复杂的部分列更新。

也就是：

1. Flink 每次输出窗口结果时，把这一行完整结果都发到结果 topic
2. Doris Routine Load 直接消费 JSON
3. Doris 用 Unique Key 表覆盖同主键旧值

这样最适合你当前的主线，因为你要先吃透：

1. 迟到修正为什么会产生多次输出
2. 多次输出为什么不能当 append
3. Doris 为什么要用 Unique Key 来承接

等这条线吃透，再学：

1. partial update
2. sequence column 的高级用法
3. late side output 的补偿表设计

## 6. 主链路和补偿链路怎么分

你前面已经学过 `allowed lateness` 和 `side output`，现在可以把它们放到结果落库视角理解：

1. 主链路
   watermark 允许范围内的迟到修正，继续更新主 ADS 结果表
2. 补偿链路
   超过 allowed lateness 的极晚数据，不再直接改主窗口结果，而是先进入补偿 topic / 补偿表

这背后的生产思维是：

1. 主结果表要稳定
2. 无限晚到不能无限重写主 ADS
3. 超晚数据通常走离线回刷、定时修正、人工补偿或专门补偿任务

所以你现在先学的是：

`主链路内可接受迟到 -> 主 ADS 表 upsert`

而不是：

`所有迟到都直接写爆主结果表`

## 7. 你当前项目里这一步怎么落

我已经给你补了两份脚手架 SQL：

1. `olap/sql/10_create_ads_rt_visit_pv_10s.sql`
   用于创建可以承接窗口修正更新的 Doris ADS 结果表
2. `olap/sql/11_create_routine_load_ads_rt_visit_pv_10s.sql`
   用于把 Kafka 结果 topic 持续导入 Doris

你接下来只需要让 Flink 结果 topic 产出一类稳定 JSON：

```json
{
  "metric_code": "visit_pv_10s",
  "window_start": "2026-04-14 09:20:00.000",
  "window_end": "2026-04-14 09:20:10.000",
  "pv": 5,
  "update_time": "2026-04-14 09:20:11.000",
  "version_ts": 1776158411000,
  "watermark_time": "2026-04-14 09:20:10.000",
  "source_job": "allowed_lateness_visit_pv_demo"
}
```

然后你观察同一个窗口：

1. 第一次写入 `pv=4`
2. 迟到修正后再次写入 `pv=5`
3. Doris 表中最终只保留同一主键的一行最新值

如果你看到的是“只有一行，但值从 4 变成 5”，那你就真正完成了这一步。

## 8. 这一步学会以后，你就进入下一个层次了

这一步一旦吃透，你对实时数仓的理解会从：

1. “我会写窗口 SQL”

升级成：

1. “我知道窗口结果是动态更新流”
2. “我知道结果 topic 是可复用的结果层，不是终点”
3. “我知道 ADS 结果表必须按 upsert 思维承接”
4. “我知道 allowed lateness 影响的不是概念，而是下游结果正确性”

这就是从“会 Flink”走向“会实时数仓结果链路”的分水岭。
