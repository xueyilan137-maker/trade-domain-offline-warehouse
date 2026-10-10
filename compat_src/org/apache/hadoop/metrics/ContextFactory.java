package org.apache.hadoop.metrics;

public class ContextFactory {
    public static ContextFactory getFactory() {
        return new ContextFactory();
    }

    public MetricsContext getContext(String refName, String contextName) {
        return NullMetricsContext.INSTANCE;
    }

    public Object getAttribute(String attributeName) {
        return null;
    }
}
