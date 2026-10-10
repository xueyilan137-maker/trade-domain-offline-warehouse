USE hive_demo;

INSERT OVERWRITE TABLE dq_order_refund_anomaly_di PARTITION (dt='__RUN_DT__')
SELECT
  order_id,
  user_id,
  order_date,
  refund_date,
  amount AS order_amount,
  refund_amount,
  net_amount,
  order_status,
  is_cancelled,
  is_refunded,
  CASE
    WHEN is_refunded NOT IN (0, 1) THEN 'refund_flag_invalid'
    WHEN is_refunded = 0 AND refund_amount <> 0 THEN 'refund_amount_without_refund_flag'
    WHEN is_refunded = 1 AND refund_amount <= 0 THEN 'refund_amount_not_positive'
    WHEN is_refunded = 1 AND (refund_date IS NULL OR TRIM(refund_date) = '') THEN 'refund_date_empty'
    WHEN order_status = 'VALID' AND refund_amount > amount THEN 'refund_amount_over_order'
    WHEN net_amount < 0 THEN 'net_amount_negative'
    WHEN order_status = 'CANCELLED' AND net_amount <> 0 THEN 'cancelled_order_net_amount_not_zero'
    WHEN order_status = 'VALID' AND net_amount <> amount - refund_amount THEN 'net_amount_calculate_mismatch'
    ELSE 'unknown_refund_anomaly'
  END AS anomaly_type,
  CASE
    WHEN order_status = 'VALID' AND refund_amount > amount THEN 'BLOCKER'
    WHEN net_amount < 0 THEN 'BLOCKER'
    ELSE 'WARN'
  END AS anomaly_level,
  CASE
    WHEN order_status = 'VALID' AND refund_amount > amount THEN 'refund_amount is greater than order amount; downstream net GMV would be negative'
    WHEN net_amount < 0 THEN 'net_amount is negative; downstream net GMV would be polluted'
    WHEN order_status = 'CANCELLED' AND net_amount <> 0 THEN 'cancelled order net_amount should be zero'
    WHEN order_status = 'VALID' AND net_amount <> amount - refund_amount THEN 'net_amount does not equal order amount minus refund amount'
    WHEN is_refunded NOT IN (0, 1) THEN 'is_refunded flag is invalid'
    WHEN is_refunded = 0 AND refund_amount <> 0 THEN 'refund_amount exists when is_refunded is zero'
    WHEN is_refunded = 1 AND refund_amount <= 0 THEN 'refund_amount should be positive for refunded orders'
    WHEN is_refunded = 1 AND (refund_date IS NULL OR TRIM(refund_date) = '') THEN 'refund_date should not be empty for refunded orders'
    ELSE 'unknown refund anomaly'
  END AS anomaly_desc,
  'fct_order_refund_status_di' AS source_table,
  CAST(current_timestamp() AS STRING) AS checked_at
FROM fct_order_refund_status_di
WHERE dt = '__RUN_DT__'
  AND (
    is_refunded NOT IN (0, 1)
    OR (is_refunded = 0 AND refund_amount <> 0)
    OR (is_refunded = 1 AND refund_amount <= 0)
    OR (is_refunded = 1 AND (refund_date IS NULL OR TRIM(refund_date) = ''))
    OR net_amount < 0
    OR (order_status = 'CANCELLED' AND net_amount <> 0)
    OR (order_status = 'VALID' AND net_amount <> amount - refund_amount)
    OR (order_status = 'VALID' AND refund_amount > amount)
  );
