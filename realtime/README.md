# Realtime Practice Environment

This directory contains a minimal Kafka + Flink SQL practice stack and the
first hands-on exercises for a realtime warehouse learning path.

## Services

The compose file starts:

- `rt-kafka`
- `rt-flink-jobmanager`
- `rt-flink-taskmanager`

Host ports:

- Kafka: `9092`
- Flink Web UI: `8082`

Start:

```powershell
docker compose -f "C:\Users\21495\Documents\New project\dw_project\realtime\docker-compose.realtime.yml" up -d
```

Stop:

```powershell
docker compose -f "C:\Users\21495\Documents\New project\dw_project\realtime\docker-compose.realtime.yml" down
```

## Learning Order

1. Confirm containers are running.
2. Open Flink SQL Client inside `rt-flink-jobmanager`.
3. Create the Kafka source table.
4. Run the minimal aggregation by `event_type`.
5. Send more events into Kafka and observe the changelog output.
6. Run the first 10-second event-time window aggregation.

## SQL Files

- `sql/00_rt_user_events_source.sql`
- `sql/01_min_event_type_count.sql`
- `sql/02_tumble_10s_event_type_count.sql`

## Sample Event Schema

The practice SQL expects JSON messages shaped like this:

```json
{
  "event_id": "e001",
  "user_id": "u1001",
  "event_type": "visit",
  "ts_ms": 1743328802000
}
```

Notes:

- `ts_ms` is event time in milliseconds.
- Flink computes `event_time` with `TO_TIMESTAMP_LTZ(ts_ms, 3)`.
- Watermark is `event_time - 5 seconds`.

Sample records are stored in:

- `sample-data/rt_user_events_sample.jsonl`

## Run In Flink SQL Client

Enter the container:

```powershell
docker exec -it rt-flink-jobmanager bash
```

Start SQL client:

```bash
/opt/flink/bin/sql-client.sh embedded
```

Inside the SQL client, execute the source DDL first:

```sql
-- copy content from sql/00_rt_user_events_source.sql
```

Then run the minimal aggregation:

```sql
-- copy content from sql/01_min_event_type_count.sql
```

Expected behavior:

- The query does not finish by itself.
- When new Kafka messages arrive, counts by `event_type` keep updating.
- Output is a dynamic table / changelog view, not a one-time batch result.

After that, open another SQL client session and run the first window query:

```sql
-- copy content from sql/02_tumble_10s_event_type_count.sql
```

Expected behavior:

- Rows are emitted by 10-second windows.
- You should focus on `window_start`, `window_end`, `event_type`, and `cnt`.
- This is the first practical bridge from raw event streams to realtime DWS-style stats.

## Send More Test Data

If you want quick manual testing from the host:

```powershell
Get-Content "C:\Users\21495\Documents\New project\dw_project\realtime\sample-data\rt_user_events_sample.jsonl" |
docker exec -i rt-kafka /opt/kafka/bin/kafka-console-producer.sh --topic rt_user_events --bootstrap-server rt-kafka:29092
```

If you prefer single-message testing:

```powershell
docker exec -it rt-kafka /opt/kafka/bin/kafka-console-producer.sh --topic rt_user_events --bootstrap-server rt-kafka:29092
```

Then paste JSON lines one by one.

## What To Learn At This Stage

- Kafka is the append-only event log.
- Flink SQL source tables map stream data into relational form.
- `GROUP BY event_type` is the smallest useful realtime aggregation.
- Windowing adds a time boundary and is the foundation of many realtime metrics.
- Watermarks determine when event-time windows can be considered complete.
