package org.apache.hadoop.metrics;

final class NullMetricsContext implements MetricsContext {
    static final NullMetricsContext INSTANCE = new NullMetricsContext();

    private NullMetricsContext() {}

    public MetricsRecord createRecord(String recordName) {
        return NullMetricsRecord.INSTANCE;
    }

    public void registerUpdater(Updater updater) {}
    public void unregisterUpdater(Updater updater) {}
    public void close() {}
}
