USE hive_demo;

SELECT 'dq_order_payment_reconcile_di row count check failed' AS err_msg
WHERE (
  SELECT COUNT(*)
  FROM dq_order_payment_reconcile_di
  WHERE dt = '__RUN_DT__'
) = 0;

SELECT 'dq_order_payment_reconcile_di status check failed' AS err_msg
WHERE EXISTS (
  SELECT 1
  FROM dq_order_payment_reconcile_di
  WHERE dt = '__RUN_DT__'
    AND reconcile_status NOT IN (
      'matched',
      'amount_mismatch',
      'order_without_payment',
      'payment_without_order'
    )
);

WITH order_stats AS (
  SELECT COUNT(*) AS order_cnt
  FROM fct_order_di
  WHERE dt = '__RUN_DT__'
),
payment_orphan_stats AS (
  SELECT COUNT(*) AS payment_without_order_cnt
  FROM dq_order_payment_reconcile_di
  WHERE dt = '__RUN_DT__'
    AND reconcile_status = 'payment_without_order'
),
reconcile_stats AS (
  SELECT COUNT(*) AS reconcile_cnt
  FROM dq_order_payment_reconcile_di
  WHERE dt = '__RUN_DT__'
)
SELECT 'dq_order_payment_reconcile_di row count reconcile check failed' AS err_msg
FROM order_stats
CROSS JOIN payment_orphan_stats
CROSS JOIN reconcile_stats
WHERE order_stats.order_cnt + payment_orphan_stats.payment_without_order_cnt <> reconcile_stats.reconcile_cnt;
