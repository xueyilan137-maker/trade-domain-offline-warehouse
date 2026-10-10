-- Minimal realtime aggregation without windowing.
-- This query keeps updating as new Kafka events arrive.

SELECT
    event_type,
    COUNT(*) AS cnt
FROM rt_user_events_src
GROUP BY event_type;
