# Realtime Late Data Repair Project

## Project Summary

This project builds a realtime data warehouse practice pipeline for late event handling and repair.

It covers:

```text
Kafka source events
Flink event-time window aggregation
watermark
allowed lateness
side output for too-late events
Kafka result topics
Doris realtime ADS tables
idempotent repair from fix table to main table
```

One-line interview version:

```text
Built a realtime visit PV pipeline with Kafka, Flink event-time windows, watermark and allowed lateness handling, side output for extremely late data, Doris ADS result tables, and an idempotent repair script for compensating late records.
```

## Why This Project Matters

Realtime metrics are not always final when a window first emits.

Events can arrive late because of:

```text
client delay
network delay
Kafka backlog
Flink restart or recovery
producer timestamp disorder
```

So the system needs to answer two questions:

```text
What should happen when late data arrives within the allowed lateness range?
What should happen when data arrives after the allowed lateness range?
```

This project uses two paths:

```text
main path: allowed-lateness updates
fix path: too-late compensation
```

## Full Data Flow

Current practice flow:

```text
Kafka topic: visit_src
  -> Flink AllowedLatenessDemoJob
  -> Kafka topic: visit_main
  -> Doris table: rt_dw2.ads_visit_main

Kafka topic: visit_src
  -> Flink side output for too-late events
  -> Kafka topic: visit_fix
  -> Doris table: rt_dw2.ads_visit_fix
  -> repair script
  -> Doris table: rt_dw2.ads_visit_main
  -> Doris table: rt_dw2.ads_visit_fix_repair_log
```

Older learning files also include an earlier naming version:

```text
dws_rt_visit_pv_10s
rt_dw.ads_rt_visit_pv_10s
```

The current project explanation should use the newer practice names:

```text
visit_src
visit_main
visit_fix
rt_dw2.ads_visit_main
rt_dw2.ads_visit_fix
rt_dw2.ads_visit_fix_repair_log
```

## Components

| Component | Path / Name | Purpose |
| --- | --- | --- |
| Flink job | `realtime/allowed-lateness-demo/src/main/java/com/dwproject/realtime/AllowedLatenessDemoJob.java` | Reads visit events, computes 10-second PV windows, handles late events. |
| Source topic | `visit_src` | Raw visit event stream. |
| Main topic | `visit_main` | Window PV results, including allowed-lateness corrections. |
| Fix topic | `visit_fix` | Too-late events emitted from side output. |
| Main ADS table | `rt_dw2.ads_visit_main` | Realtime PV result table. |
| Fix table | `rt_dw2.ads_visit_fix` | Stores too-late compensation records. |
| Repair log table | `rt_dw2.ads_visit_fix_repair_log` | Records already repaired fix rows for idempotency. |
| Repair script | `pipeline/run_rt_fix_repair.py` | Previews and applies fix-table compensation to main ADS. |
| PowerShell wrapper | `pipeline/run_rt_fix_repair.ps1` | Windows entrypoint for the same repair workflow. |

## Event Schema

Sample file:

```text
realtime/sample-data/rt_allowed_lateness_demo_sequence.jsonl
```

Example event:

```json
{"event_id":"e001","user_id":"u1001","event_type":"visit","ts_ms":1776129601000}
```

Fields:

```text
event_id: event id for testing
user_id: visitor id
event_type: event type, this job keeps only visit
ts_ms: event time in milliseconds
```

## Flink Job Logic

Job file:

```text
realtime/allowed-lateness-demo/src/main/java/com/dwproject/realtime/AllowedLatenessDemoJob.java
```

Core configuration:

```text
source topic: visit_src
main output topic: visit_main
too-late output topic: visit_fix
window: 10-second tumbling event-time window
watermark: bounded out-of-orderness, 5 seconds
allowed lateness: 10 seconds
parallelism: 1 for learning simplicity
sink guarantee: AT_LEAST_ONCE
```

Core Flink flow:

```text
read Kafka JSON
parse event
filter event_type = visit
assign event-time timestamp and watermark
key by metric key visit_pv
10-second tumbling window
allowedLateness(10 seconds)
sideOutputLateData(tooLateTag)
aggregate PV count
write main result to visit_main
write too-late side output to visit_fix
```

## Main Path: Allowed-Lateness Correction

Within the allowed lateness range, Flink can emit the same window more than once.

Example:

```text
first window result: pv = 2
late event arrives within allowed lateness
corrected window result: pv = 3
```

This means the main result topic is not pure append facts.

It is an update stream for window results.

Important idea:

```text
The business key is the window.
Later results for the same window should update the old value.
```

So downstream storage should use upsert-style thinking, not simple append-style thinking.

### Main Result Update Semantics

The earlier committed Doris sink practice used a stronger main-result contract for this problem:

```text
metric_code + window_start + window_end = stable business key
revision = firing number for the same window
version_ts = monotonic version used by Doris to decide which update wins
```

Example result versions for the same window:

| metric_code | window_start | window_end | pv | revision | version_ts | Meaning |
| --- | --- | --- | --- | --- | --- | --- |
| `visit_pv_10s` | `2026-04-14 09:20:00.000` | `2026-04-14 09:20:10.000` | 2 | 1 | `window_end * 1000 + 1` | First window firing |
| `visit_pv_10s` | `2026-04-14 09:20:00.000` | `2026-04-14 09:20:10.000` | 3 | 2 | `window_end * 1000 + 2` | Late-event correction |

The important point is:

```text
allowed-lateness output is an update stream keyed by the window,
not an append-only stream keyed by each Kafka message.
```

In the current Java code, `WindowResult` already calculates `revision` and `versionTs` internally for learning and logging. The current `toJson()` output is simplified and only emits:

```json
{"window_start":"2026-04-14 09:20:00.000","window_end":"2026-04-14 09:20:10.000","pv":3}
```

To fully match the earlier Doris Unique Key design, the main topic JSON should be enriched to this contract:

```json
{
  "metric_code": "visit_pv_10s",
  "window_start": "2026-04-14 09:20:00.000",
  "window_end": "2026-04-14 09:20:10.000",
  "pv": 3,
  "revision": 2,
  "update_time": "2026-04-14 09:20:11.000",
  "version_ts": 1776158410002,
  "watermark_time": "2026-04-14 09:20:10.000",
  "source_job": "allowed_lateness_visit_pv_demo"
}
```

This enriched schema makes the main path more robust when Kafka messages are replayed or consumed out of order.

## Fix Path: Too-Late Compensation

If an event arrives after the allowed lateness range, Flink does not update the main window result directly.

Instead, the event goes to side output:

```text
visit_fix
```

The fix event carries:

```text
window_start
window_end
pv
is_fix
```

Then Doris stores these records in:

```text
rt_dw2.ads_visit_fix
```

The repair script later aggregates unrepaired fix rows and adds their delta into:

```text
rt_dw2.ads_visit_main
```

This design avoids letting infinitely late events continuously rewrite the main realtime result directly.

## Doris ADS Design

For realtime window results, the main ADS table should support update semantics.

Recommended design:

```text
UNIQUE KEY(window_start, window_end)
merge-on-write
```

For earlier project files, one version uses:

```text
metric_code + window_start + window_end
version_ts
sequence column
```

That design is useful when the same window result may be replayed or arrive out of order.

The key concept:

```text
primary key answers: is this the same result row?
version or repair log answers: which update should win or has already been applied?
```

### Doris Unique Key Design From Earlier Commit

Earlier committed files include this Doris ADS table:

```text
olap/sql/10_create_ads_rt_visit_pv_10s.sql
```

Core DDL:

```sql
CREATE TABLE IF NOT EXISTS ads_rt_visit_pv_10s (
    metric_code VARCHAR(32) NOT NULL,
    window_start DATETIME(3) NOT NULL,
    window_end DATETIME(3) NOT NULL,
    pv BIGINT NOT NULL,
    revision INT NOT NULL,
    update_time DATETIME(3) NOT NULL,
    version_ts BIGINT NOT NULL,
    watermark_time DATETIME(3) NULL,
    source_job VARCHAR(64) NULL
)
UNIQUE KEY(metric_code, window_start, window_end)
DISTRIBUTED BY HASH(metric_code) BUCKETS 1
PROPERTIES (
    "replication_num" = "1",
    "enable_unique_key_merge_on_write" = "true",
    "function_column.sequence_col" = "version_ts"
);
```

This table design has three important ideas:

```text
UNIQUE KEY(metric_code, window_start, window_end)
  identifies one logical window metric row.

enable_unique_key_merge_on_write = true
  makes Doris store the latest value for the same unique key.

function_column.sequence_col = version_ts
  protects the table from older versions overwriting newer versions.
```

Without the sequence column, two updates for the same window depend more heavily on ingestion order. With `version_ts`, Doris can keep the newer logical version when records for the same key arrive out of order.

### Routine Load From Kafka To Doris

Earlier committed files also include the Routine Load job:

```text
olap/sql/11_create_routine_load_ads_rt_visit_pv_10s.sql
```

Core Routine Load:

```sql
CREATE ROUTINE LOAD rt_dw.rl_ads_rt_visit_pv_10s
ON ads_rt_visit_pv_10s
PROPERTIES (
    "desired_concurrent_number" = "1",
    "max_batch_interval" = "5",
    "max_batch_rows" = "200000",
    "max_batch_size" = "104857600",
    "format" = "json",
    "strict_mode" = "false"
)
FROM KAFKA (
    "kafka_broker_list" = "rt-kafka:29092",
    "kafka_topic" = "dws_rt_visit_pv_10s",
    "property.group.id" = "doris_ads_rt_visit_pv_10s",
    "property.kafka_default_offsets" = "OFFSET_BEGINNING"
);
```

The end-to-end update path is:

```text
Flink emits first result for window
  -> Kafka result topic
  -> Doris Routine Load consumes JSON
  -> Doris inserts one Unique Key row

Flink emits corrected result for same window
  -> Kafka result topic
  -> Doris Routine Load consumes JSON
  -> Doris updates the same Unique Key row
  -> sequence column keeps the newest version
```

So the main-path learning goal is not only "Flink can output late corrections". It is:

```text
Flink allowed lateness produces repeated window results,
Kafka carries those result versions,
Doris Unique Key + sequence column turns them into one latest ADS row.
```

### Naming Difference

The earlier Doris files use older names:

```text
Kafka topic: dws_rt_visit_pv_10s
Doris database/table: rt_dw.ads_rt_visit_pv_10s
```

The later repair practice uses newer names:

```text
Kafka topics: visit_main, visit_fix
Doris tables: rt_dw2.ads_visit_main, rt_dw2.ads_visit_fix
```

Conceptually they are the same main-path design. The recommended future cleanup is to unify the latest `visit_main` naming with the stronger earlier Doris DDL contract.

## Repair Script

Python script:

```text
pipeline/run_rt_fix_repair.py
```

PowerShell wrapper:

```text
pipeline/run_rt_fix_repair.ps1
```

Main tables used by the Python script:

```text
rt_dw2.ads_visit_main
rt_dw2.ads_visit_fix
rt_dw2.ads_visit_main_bak
rt_dw2.ads_visit_fix_repair_log
```

Repair workflow:

```text
1. Build a window filter from --start-window and --end-window.
2. Prepare repair log table.
3. Find affected windows from ads_visit_fix.
4. Compare current fix totals with already repaired totals.
5. Preview delta_fix_pv.
6. If --apply is not provided, stop after preview.
7. If --apply is provided, back up affected main rows.
8. Apply main_pv + delta_fix_pv into ads_visit_main.
9. Validate expected_pv vs actual_pv.
10. Write repaired totals into ads_visit_fix_repair_log.
```

Why it is idempotent:

```text
ads_visit_fix_repair_log records repaired_fix_rows and repaired_fix_pv by window.
Next repair only applies the delta between current fix totals and repaired totals.
Repeated runs do not double-count the same fix rows.
```

## Repair Script Modes

Preview mode:

```powershell
python pipeline/run_rt_fix_repair.py --start-window "2026-04-14 09:20:00" --end-window "2026-04-14 09:21:00"
```

Apply mode:

```powershell
python pipeline/run_rt_fix_repair.py --start-window "2026-04-14 09:20:00" --end-window "2026-04-14 09:21:00" --apply
```

Bootstrap mode:

```powershell
python pipeline/run_rt_fix_repair.py --bootstrap-current-state
```

Bootstrap mode is useful when the fix table already has historical rows and you want to mark the current state as repaired before future incremental repairs.

## Expected Demo Behavior

Sample event file:

```text
realtime/sample-data/rt_allowed_lateness_demo_sequence.jsonl
```

The sequence is designed to show:

```text
1. First window result is emitted.
2. A late event within allowed lateness updates the main result.
3. A too-late event goes to the fix stream.
4. The fix record can later repair the Doris main ADS result.
```

Expected conceptual result:

```text
visit_main receives corrected window results.
visit_fix receives extremely late records.
ads_visit_main stores the current main PV result.
ads_visit_fix stores compensation rows.
run_rt_fix_repair.py applies unrepaired compensation deltas.
ads_visit_fix_repair_log prevents repeated repair from double-counting.
```

## What To Verify

Flink main output:

```text
same window can emit more than once
later emit has corrected pv
```

Kafka main topic:

```text
same business window may have multiple result messages
revision or version_ts should increase for later corrections in the enriched design
```

Flink too-late output:

```text
events beyond allowed lateness appear in visit_fix
```

Doris main table:

```text
main table stores the current result for each window
when using Unique Key design, repeated window results collapse into one latest ADS row
when using sequence column, older versions should not overwrite newer versions
```

Doris fix table:

```text
fix table stores compensation rows by window_start and window_end
```

Repair script:

```text
preview shows affected windows and delta_fix_pv
apply updates ads_visit_main
repair log records repaired_fix_rows and repaired_fix_pv
rerunning the repair does not double count
```

## Main Concepts

Event time:

```text
The time when the event actually happened.
```

Processing time:

```text
The time when Flink processes the event.
```

Watermark:

```text
Flink's progress marker for event time. It decides when a window can be considered ready to emit.
```

Allowed lateness:

```text
The period after a window first closes during which late events can still update the window result.
```

Side output:

```text
A separate stream for records that are too late for the main window update.
```

Idempotent repair:

```text
Repair logic that can be rerun without repeatedly applying the same compensation data.
```

## What This Project Proves

This project shows that you understand:

```text
realtime results are often dynamic updates, not final append-only rows
allowed lateness can produce multiple outputs for the same window
too-late events should go into a compensation path
Doris ADS should be designed to handle updates or repairs
Doris Unique Key can model one latest row per window metric
version_ts / sequence column can protect update order
Routine Load can continuously ingest Kafka result JSON into Doris ADS
repair scripts need idempotency and repair logs
sink semantics affect end-to-end correctness
```

## Interview Explanation

Short version:

```text
I built a realtime visit PV demo using Kafka, Flink, and Doris. Flink reads visit events from Kafka, uses event-time tumbling windows with watermarks, and allows late events to update the same window result within a configured allowed lateness range. Events that arrive after the allowed lateness range go to a side output and are written to a fix topic. Doris stores the main result and fix records separately, and I wrote an idempotent repair script that aggregates unrepaired fix rows, applies the delta back to the main ADS table, and records the repair progress in a repair log table.
```

Problem and solution:

```text
The main problem is that realtime window results can change after the first output. If downstream storage simply appends every result, dashboards can double-count or read stale values. I handled this by treating window results as update rows and by separating extremely late data into a fix path. For fix data, I used a repair log to avoid applying the same compensation more than once.
```

Main-path Doris version:

```text
For late events within allowed lateness, Flink may emit multiple versions of the same window result. I used the window metric key as a Doris Unique Key, such as metric_code plus window_start and window_end. The result row carries revision and version_ts, and Doris can use version_ts as a sequence column so that a later correction wins even if Kafka replay or ingestion disorder happens.
```

Key technical points:

```text
Watermark controls when event-time windows are emitted.
Allowed lateness controls how long a closed window can still be corrected.
Side output captures data that is too late for normal window correction.
Kafka result topics carry main results and fix events separately.
Doris Routine Load consumes Kafka JSON into ADS tables.
Doris Unique Key stores the latest window result instead of appending duplicates.
version_ts can be used as a sequence column for overwrite protection.
The repair script is idempotent because it only applies unrepaired deltas.
```

Good follow-up answer:

```text
In production, I would strengthen the result topic schema with stable metric_code, update_time, revision, and version_ts fields, use Doris Unique Key with a sequence column for overwrite protection, enable stronger checkpoint and sink guarantees where needed, and add monitoring for fix-table backlog and repair lag.
```

## Current Limitations

This is a learning project, so it keeps some choices simple:

```text
Flink sink uses AT_LEAST_ONCE.
The Java JSON parsing is minimal and for controlled demo data.
Parallelism is set to 1 for easier observation.
Some older SQL files use earlier topic and table names.
Doris table setup for the latest rt_dw2 naming is represented by the repair script and previous manual practice, while older olap SQL files show the earlier Unique Key design.
Current visit_main JSON is simplified; the richer metric_code/revision/version_ts contract exists as an earlier Doris sink design and should be reintroduced when unifying the latest naming.
```

These limitations are acceptable for learning, but they are useful to mention honestly in interviews.

## Future Improvements

Recommended improvements:

```text
Unify all realtime topic and Doris table names into the latest visit_src / visit_main / visit_fix / rt_dw2 naming.
Add official Doris DDL files for rt_dw2.ads_visit_main and rt_dw2.ads_visit_fix.
Enrich visit_main JSON with metric_code, revision, update_time, version_ts, and source_job.
Use Doris Unique Key with sequence column for main result overwrite protection.
Add checkpoint configuration and stronger recovery testing.
Add a scheduled repair DAG or cron task for fix-table compensation.
Add DQ checks for main/fix row counts and unrepaired fix backlog.
Add replay tests to verify repair idempotency after duplicate fix records.
```
