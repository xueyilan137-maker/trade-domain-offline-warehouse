-- First event-time window aggregation.
-- This groups events into 10-second tumbling windows by event_type.

SELECT
    window_start,
    window_end,
    event_type,
    COUNT(*) AS cnt
FROM TABLE(
    TUMBLE(
        TABLE rt_user_events_src,
        DESCRIPTOR(event_time),
        INTERVAL '10' SECOND
    )
)
GROUP BY
    window_start,
    window_end,
    event_type;
