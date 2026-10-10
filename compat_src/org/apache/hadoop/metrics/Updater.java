package org.apache.hadoop.metrics;

public interface Updater {
    void doUpdates(MetricsContext context);
}
