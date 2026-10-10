# Allowed Lateness -> Doris ADS Demo

这个练习把你当前卡住的主线补完整：

`Kafka 原始事件 -> Flink allowed lateness 窗口修正 -> Kafka 结果 topic -> Doris ADS Unique Key 表`

## 1. 这次练习会产出什么

这个 job 现在会写两个 Kafka topic：

1. `dws_rt_visit_pv_10s`
   主结果流，同一个窗口会因为迟到修正而多次输出
2. `rt_allowed_lateness_too_late`
   超过 allowed lateness 的极晚数据

主结果流里最关键的字段：

1. `metric_code`
2. `window_start`
3. `window_end`
4. `pv`
5. `version_ts`

其中：

1. `metric_code + window_start + window_end` 是 Doris ADS 的业务主键
2. `version_ts` 是同一窗口内的递增版本

## 2. 先创建 Kafka topic

```powershell
docker exec rt-kafka /opt/kafka/bin/kafka-topics.sh --create --if-not-exists --topic rt_allowed_lateness_demo --bootstrap-server rt-kafka:29092 --partitions 1 --replication-factor 1
docker exec rt-kafka /opt/kafka/bin/kafka-topics.sh --create --if-not-exists --topic dws_rt_visit_pv_10s --bootstrap-server rt-kafka:29092 --partitions 1 --replication-factor 1
docker exec rt-kafka /opt/kafka/bin/kafka-topics.sh --create --if-not-exists --topic rt_allowed_lateness_too_late --bootstrap-server rt-kafka:29092 --partitions 1 --replication-factor 1
```

## 3. 打包并提交 Flink job

在项目目录执行：

```powershell
cd "C:\Users\21495\Documents\New project\dw_project\realtime\allowed-lateness-demo"
mvn clean package
```

提交到 Flink：

```powershell
docker cp "C:\Users\21495\Documents\New project\dw_project\realtime\allowed-lateness-demo\target\allowed-lateness-demo-1.0-SNAPSHOT.jar" rt-flink-jobmanager:/tmp/allowed-lateness-demo.jar
docker exec rt-flink-jobmanager /opt/flink/bin/flink run -d /tmp/allowed-lateness-demo.jar
```

## 4. 先打开两个观察窗口

消费主结果 topic：

```powershell
docker exec -it rt-kafka /opt/kafka/bin/kafka-console-consumer.sh --topic dws_rt_visit_pv_10s --from-beginning --bootstrap-server rt-kafka:29092
```

消费极晚数据 topic：

```powershell
docker exec -it rt-kafka /opt/kafka/bin/kafka-console-consumer.sh --topic rt_allowed_lateness_too_late --from-beginning --bootstrap-server rt-kafka:29092
```

## 5. 发送这组顺序数据

样例文件：

- `C:\Users\21495\Documents\New project\dw_project\realtime\sample-data\rt_allowed_lateness_demo_sequence.jsonl`

发送：

```powershell
Get-Content "C:\Users\21495\Documents\New project\dw_project\realtime\sample-data\rt_allowed_lateness_demo_sequence.jsonl" |
docker exec -i rt-kafka /opt/kafka/bin/kafka-console-producer.sh --topic rt_allowed_lateness_demo --bootstrap-server rt-kafka:29092
```

这组数据按顺序会触发：

1. 第一版窗口结果 `pv=2`
2. allowed lateness 范围内迟到修正，同一窗口更新为 `pv=3`
3. 超过 allowed lateness 的极晚数据进入 `rt_allowed_lateness_too_late`

## 6. 把 Doris ADS 表和 Routine Load 建起来

执行：

1. `C:\Users\21495\Documents\New project\dw_project\olap\sql\10_create_ads_rt_visit_pv_10s.sql`
2. `C:\Users\21495\Documents\New project\dw_project\olap\sql\11_create_routine_load_ads_rt_visit_pv_10s.sql`

如果之前建过同名 Routine Load，需要先：

```sql
STOP ROUTINE LOAD FOR rt_dw.rl_ads_rt_visit_pv_10s;
DROP ROUTINE LOAD FOR rt_dw.rl_ads_rt_visit_pv_10s;
```

## 7. 最关键的验证点

在 Doris 里查询：

```sql
USE rt_dw;

SELECT
    metric_code,
    window_start,
    window_end,
    pv,
    revision,
    version_ts,
    update_time
FROM ads_rt_visit_pv_10s
ORDER BY window_start, version_ts;
```

你要观察的不是“有没有两条消息写进 Kafka”，而是：

1. Kafka 结果流里，同一窗口会出现两次结果
2. Doris ADS 表里，同一主键最终只保留一行
3. 这一行的 `pv` 最终是修正后的新值

这就说明你已经真正掌握了：

`迟到修正 -> 结果重复输出 -> Doris Unique Key 承接更新`

## 8. 这次实验里的边界

这还是一个教学版最小闭环，所以我们刻意保持简单：

1. Kafka sink 先用 `AT_LEAST_ONCE`
2. Doris 用 `UNIQUE KEY + merge-on-write`
3. `version_ts` 使用“窗口固定基线 + 本窗口 revision”来表达更新版本

这足够帮助你吃透当前阶段的主线。下一步如果你想继续，我们就可以接：

1. 结果 topic 的 replay / 重启影响
2. Doris sequence column 更严格的更新保护
3. side output 如何进入补偿 topic / 补偿表
