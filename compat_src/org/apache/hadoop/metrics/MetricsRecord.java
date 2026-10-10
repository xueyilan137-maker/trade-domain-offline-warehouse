package org.apache.hadoop.metrics;

public interface MetricsRecord {
    void setTag(String tagName, String tagValue);
    void setTag(String tagName, int tagValue);
    void setTag(String tagName, long tagValue);
    void setMetric(String metricName, int metricValue);
    void setMetric(String metricName, long metricValue);
    void incrMetric(String metricName, int metricValue);
    void incrMetric(String metricName, long metricValue);
    void update();
    void remove();
}
