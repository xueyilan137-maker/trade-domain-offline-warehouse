package com.dwproject.realtime;

import org.apache.flink.api.common.eventtime.SerializableTimestampAssigner;
import org.apache.flink.api.common.eventtime.WatermarkStrategy;
import org.apache.flink.api.common.functions.AggregateFunction;
import org.apache.flink.api.common.serialization.SimpleStringSchema;
import org.apache.flink.api.common.state.ValueState;
import org.apache.flink.api.common.state.ValueStateDescriptor;
import org.apache.flink.api.common.typeinfo.TypeInformation;
import org.apache.flink.connector.base.DeliveryGuarantee;
import org.apache.flink.connector.kafka.sink.KafkaRecordSerializationSchema;
import org.apache.flink.connector.kafka.sink.KafkaSink;
import org.apache.flink.connector.kafka.source.KafkaSource;
import org.apache.flink.connector.kafka.source.enumerator.initializer.OffsetsInitializer;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.datastream.SingleOutputStreamOperator;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.functions.windowing.ProcessWindowFunction;
import org.apache.flink.streaming.api.windowing.assigners.TumblingEventTimeWindows;
import org.apache.flink.streaming.api.windowing.time.Time;
import org.apache.flink.streaming.api.windowing.windows.TimeWindow;
import org.apache.flink.util.Collector;
import org.apache.flink.util.OutputTag;

import java.text.SimpleDateFormat;
import java.time.Duration;
import java.util.Date;
import java.util.TimeZone;

public class AllowedLatenessDemoJob {

    private static final String BOOTSTRAP_SERVERS = "rt-kafka:29092";
    private static final String SOURCE_TOPIC = "visit_src";
    private static final String RESULT_TOPIC = "visit_main";
    private static final String TOO_LATE_TOPIC = "visit_fix";
    private static final String GROUP_ID = "flink_visit_main_fix_demo";
    private static final SimpleDateFormat TS_FORMAT = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
    private static final SimpleDateFormat TS_FORMAT_MS = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS");

    static {
        TS_FORMAT.setTimeZone(TimeZone.getTimeZone("Asia/Shanghai"));
        TS_FORMAT_MS.setTimeZone(TimeZone.getTimeZone("Asia/Shanghai"));
    }

    public static void main(String[] args) throws Exception {
        final StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        env.setParallelism(1);

        KafkaSource<String> source = KafkaSource.<String>builder()
                .setBootstrapServers(BOOTSTRAP_SERVERS)
                .setTopics(SOURCE_TOPIC)
                .setGroupId(GROUP_ID)
                .setStartingOffsets(OffsetsInitializer.earliest())
                .setValueOnlyDeserializer(new SimpleStringSchema())
                .build();

        KafkaSink<String> resultSink = KafkaSink.<String>builder()
                .setBootstrapServers(BOOTSTRAP_SERVERS)
                .setRecordSerializer(
                        KafkaRecordSerializationSchema.builder()
                                .setTopic(RESULT_TOPIC)
                                .setValueSerializationSchema(new SimpleStringSchema())
                                .build()
                )
                .setDeliveryGuarantee(DeliveryGuarantee.AT_LEAST_ONCE)
                .build();

        KafkaSink<String> tooLateSink = KafkaSink.<String>builder()
                .setBootstrapServers(BOOTSTRAP_SERVERS)
                .setRecordSerializer(
                        KafkaRecordSerializationSchema.builder()
                                .setTopic(TOO_LATE_TOPIC)
                                .setValueSerializationSchema(new SimpleStringSchema())
                                .build()
                )
                .setDeliveryGuarantee(DeliveryGuarantee.AT_LEAST_ONCE)
                .build();

        OutputTag<Event> tooLateTag = new OutputTag<Event>("too-late", TypeInformation.of(Event.class));

        DataStream<String> kafkaStream = env.fromSource(
                source,
                WatermarkStrategy.noWatermarks(),
                "allowed-lateness-kafka-source"
        );

        SingleOutputStreamOperator<WindowResult> resultStream = kafkaStream
                .map(AllowedLatenessDemoJob::parseEvent)
                .returns(TypeInformation.of(Event.class))
                .filter(event -> "visit".equals(event.eventType))
                .assignTimestampsAndWatermarks(
                        WatermarkStrategy.<Event>forBoundedOutOfOrderness(Duration.ofSeconds(5))
                                .withTimestampAssigner((SerializableTimestampAssigner<Event>) (event, recordTimestamp) -> event.tsMs)
                )
                .keyBy(event -> "visit_pv")
                .window(TumblingEventTimeWindows.of(Time.seconds(10)))
                .allowedLateness(Time.seconds(10))
                .sideOutputLateData(tooLateTag)
                .aggregate(new CountAgg(), new WindowResultProcessFunction());

        DataStream<String> resultJsonStream = resultStream
                .map(WindowResult::toJson)
                .returns(TypeInformation.of(String.class));

        resultStream
                .map(WindowResult::formatForLog)
                .returns(TypeInformation.of(String.class))
                .print("WINDOW_RESULT");

        resultJsonStream
                .sinkTo(resultSink)
                .name("visit-pv-result-kafka-sink");

        DataStream<String> tooLateJsonStream = resultStream
                .getSideOutput(tooLateTag)
                .map(AllowedLatenessDemoJob::formatTooLateJson)
                .returns(TypeInformation.of(String.class));

        tooLateJsonStream
                .sinkTo(tooLateSink)
                .name("too-late-kafka-sink");

        resultStream
                .getSideOutput(tooLateTag)
                .map(AllowedLatenessDemoJob::formatTooLate)
                .returns(TypeInformation.of(String.class))
                .print("TOO_LATE");

        env.execute("allowed-lateness-demo-job");
    }

    private static Event parseEvent(String json) {
        return new Event(
                extractJsonValue(json, "user_id"),
                extractJsonValue(json, "event_type"),
                Long.parseLong(extractJsonValue(json, "ts_ms"))
        );
    }

    private static String extractJsonValue(String json, String key) {
        String token = "\"" + key + "\"";
        int keyIndex = json.indexOf(token);
        if (keyIndex < 0) {
            throw new IllegalArgumentException("Missing key: " + key + " in json: " + json);
        }
        int colonIndex = json.indexOf(':', keyIndex);
        int valueStart = colonIndex + 1;
        while (valueStart < json.length() && Character.isWhitespace(json.charAt(valueStart))) {
            valueStart++;
        }

        if (json.charAt(valueStart) == '"') {
            int valueEnd = json.indexOf('"', valueStart + 1);
            return json.substring(valueStart + 1, valueEnd);
        }

        int valueEnd = valueStart;
        while (valueEnd < json.length()
                && json.charAt(valueEnd) != ','
                && json.charAt(valueEnd) != '}'
                && !Character.isWhitespace(json.charAt(valueEnd))) {
            valueEnd++;
        }
        return json.substring(valueStart, valueEnd);
    }

    private static String formatTooLate(Event event) {
        return String.format(
                "too-late event -> user_id=%s, event_type=%s, event_time=%s",
                event.userId,
                event.eventType,
                formatTs(event.tsMs)
        );
    }

    private static String formatTooLateJson(Event event) {
        long windowStart = event.tsMs - (event.tsMs % 10_000L);
        long windowEnd = windowStart + 10_000L;
        return String.format(
                "{\"window_start\":\"%s\",\"window_end\":\"%s\",\"pv\":1,\"is_fix\":1}",
                formatTsMs(windowStart),
                formatTsMs(windowEnd)
        );
    }

    private static String formatTs(long tsMs) {
        return TS_FORMAT.format(new Date(tsMs));
    }

    private static String formatTsMs(long tsMs) {
        return TS_FORMAT_MS.format(new Date(tsMs));
    }

    private static String formatWatermark(long watermarkTs) {
        return watermarkTs >= 0 ? formatTsMs(watermarkTs) : "";
    }

    private static String escapeJson(String value) {
        return value == null ? "" : value.replace("\\", "\\\\").replace("\"", "\\\"");
    }

    public static class Event {
        public String userId;
        public String eventType;
        public long tsMs;

        public Event() {
        }

        public Event(String userId, String eventType, long tsMs) {
            this.userId = userId;
            this.eventType = eventType;
            this.tsMs = tsMs;
        }
    }

    public static class CountAgg implements AggregateFunction<Event, Long, Long> {
        @Override
        public Long createAccumulator() {
            return 0L;
        }

        @Override
        public Long add(Event value, Long accumulator) {
            return accumulator + 1;
        }

        @Override
        public Long getResult(Long accumulator) {
            return accumulator;
        }

        @Override
        public Long merge(Long a, Long b) {
            return a + b;
        }
    }

    public static class WindowResultProcessFunction extends ProcessWindowFunction<Long, WindowResult, String, TimeWindow> {
        private transient ValueState<Integer> revisionState;

        @Override
        public void process(String key,
                            Context context,
                            Iterable<Long> elements,
                            Collector<WindowResult> out) throws Exception {
            long count = elements.iterator().next();
            if (revisionState == null) {
                revisionState = context.windowState().getState(
                        new ValueStateDescriptor<>("window-revision", Integer.class)
                );
            }
            Integer currentRevision = revisionState.value();
            int nextRevision = currentRevision == null ? 1 : currentRevision + 1;
            revisionState.update(nextRevision);

            long updateTs = System.currentTimeMillis();
            long versionTs = context.window().getEnd() * 1000L + nextRevision;
            out.collect(new WindowResult(
                    context.window().getStart(),
                    context.window().getEnd(),
                    count,
                    updateTs,
                    versionTs,
                    context.currentWatermark(),
                    nextRevision
            ));
        }

        @Override
        public void clear(Context context) throws Exception {
            if (revisionState == null) {
                revisionState = context.windowState().getState(
                        new ValueStateDescriptor<>("window-revision", Integer.class)
                );
            }
            revisionState.clear();
        }
    }

    public static class WindowResult {
        public long windowStart;
        public long windowEnd;
        public long pv;
        public long updateTs;
        public long versionTs;
        public long watermarkTs;
        public int revision;

        public WindowResult() {
        }

        public WindowResult(long windowStart,
                            long windowEnd,
                            long pv,
                            long updateTs,
                            long versionTs,
                            long watermarkTs,
                            int revision) {
            this.windowStart = windowStart;
            this.windowEnd = windowEnd;
            this.pv = pv;
            this.updateTs = updateTs;
            this.versionTs = versionTs;
            this.watermarkTs = watermarkTs;
            this.revision = revision;
        }

        public String formatForLog() {
            return String.format(
                    "window=[%s, %s), visit_pv=%d, revision=%d, version_ts=%d, watermark=%s",
                    formatTs(windowStart),
                    formatTs(windowEnd),
                    pv,
                    revision,
                    versionTs,
                    watermarkTs >= 0 ? formatTs(watermarkTs) : "N/A"
            );
        }

        public String toJson() {
            return String.format(
                    "{\"window_start\":\"%s\",\"window_end\":\"%s\",\"pv\":%d}",
                    formatTsMs(windowStart),
                    formatTsMs(windowEnd),
                    pv
            );
        }
    }
}
