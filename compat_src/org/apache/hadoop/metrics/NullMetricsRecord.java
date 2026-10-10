package org.apache.hadoop.metrics;

final class NullMetricsRecord implements MetricsRecord {
    static final NullMetricsRecord INSTANCE = new NullMetricsRecord();

    private NullMetricsRecord() {}

    public void setTag(String tagName, String tagValue) {}
    public void setTag(String tagName, int tagValue) {}
    public void setTag(String tagName, long tagValue) {}
    public void setMetric(String metricName, int metricValue) {}
    public void setMetric(String metricName, long metricValue) {}
    public void incrMetric(String metricName, int metricValue) {}
    public void incrMetric(String metricName, long metricValue) {}
    public void update() {}
    public void remove() {}
}
