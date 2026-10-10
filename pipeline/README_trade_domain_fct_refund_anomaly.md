# Trade Domain FCT Refund Anomaly Handling

## 1. Background

In the 7-day realistic trade-domain demo, `2026-03-07` intentionally contains a refund anomaly:

```text
order_id: o1503
order_amount: 50.00
refund_amount: 80.00
net_amount: -30.00
```

This case is used to practice how an offline warehouse pipeline handles business-quality exceptions.

## 2. Layer Responsibility

### DWD

DWD keeps structurally valid refund events.

For `dwd_order_refund_clean_di`, the row is valid when:

- `order_id`, `user_id`, and `refund_date` are not empty
- `refund_amount > 0`
- the order can be matched in historical clean orders

So `o1503` is kept in DWD because it is a valid refund event record structurally.

### FCT

FCT combines order amount, order status, refund amount, and net amount at order grain.

This is where business rules become visible:

```text
net_amount = amount - refund_amount
```

For a valid order, `refund_amount > amount` is not acceptable because it creates negative net GMV.

## 3. Anomaly Detail

Anomaly detail table:

```text
dq_order_refund_anomaly_di
```

Generation SQL:

```text
pipeline/sql/dq/11_order_refund_anomaly_detail.sql.tpl
```

Current anomaly type:

```text
refund_amount_over_order
```

Current blocking rule:

```text
order_status = 'VALID' AND refund_amount > amount
```

## 4. Processing Strategy

For this learning project, the recommended strategy is:

```text
FCT keeps the calculated row.
DQ records the exact abnormal order.
The quality check blocks downstream DWS/ADS refresh for the abnormal date.
```

This is better than silently clipping the refund amount, because clipping would hide the source-system problem.

## 5. Interview Expression

```text
In my trade-domain warehouse project, DWD handles structural cleansing and keeps refund events that have valid keys, positive refund amount, and a matching historical order. Business exceptions are handled later in FCT/DQ. For example, one 7-day demo order has amount 50 but refund_amount 80. DWD keeps the refund event, but FCT calculates net_amount as -30 and DQ records it as refund_amount_over_order. This blocks the date from entering trusted DWS/ADS metrics, so negative net GMV does not pollute downstream reports.
```
