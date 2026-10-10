USE hive_demo;

WITH order_fct AS (
  SELECT
    order_id,
    user_id,
    amount
  FROM fct_order_di
  WHERE dt = '__RUN_DT__'
),
payment_fct AS (
  SELECT
    payment_id,
    order_id,
    user_id,
    pay_amount
  FROM fct_payment_di
  WHERE dt = '__RUN_DT__'
),
joined AS (
  SELECT
    COALESCE(o.order_id, p.order_id) AS order_id,
    o.user_id AS order_user_id,
    o.amount AS order_amount,
    p.payment_id,
    p.user_id AS payment_user_id,
    p.pay_amount,
    CASE
      WHEN o.order_id IS NULL THEN 'payment_without_order'
      WHEN p.order_id IS NULL THEN 'order_without_payment'
      WHEN o.amount <> p.pay_amount THEN 'amount_mismatch'
      ELSE 'matched'
    END AS reconcile_status,
    CAST(COALESCE(o.amount, 0) - COALESCE(p.pay_amount, 0) AS DECIMAL(10,2)) AS diff_amount
  FROM order_fct o
  FULL OUTER JOIN payment_fct p
    ON o.order_id = p.order_id
)
INSERT OVERWRITE TABLE dq_order_payment_reconcile_di PARTITION (dt='__RUN_DT__')
SELECT
  order_id,
  order_user_id,
  order_amount,
  payment_id,
  payment_user_id,
  pay_amount,
  reconcile_status,
  diff_amount
FROM joined;
