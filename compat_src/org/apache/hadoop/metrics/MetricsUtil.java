package org.apache.hadoop.metrics;

public class MetricsUtil {
    private MetricsUtil() {}

    public static MetricsContext getContext(String refName) {
        return NullMetricsContext.INSTANCE;
    }

    public static MetricsRecord createRecord(MetricsContext context, String recordName) {
        if (context == null) {
            return NullMetricsRecord.INSTANCE;
        }
        return context.createRecord(recordName);
    }
}
