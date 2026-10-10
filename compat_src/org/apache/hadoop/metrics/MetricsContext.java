package org.apache.hadoop.metrics;

public interface MetricsContext {
    MetricsRecord createRecord(String recordName);
    void registerUpdater(Updater updater);
    void unregisterUpdater(Updater updater);
    void close();
}
