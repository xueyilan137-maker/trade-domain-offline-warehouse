# Trade Domain DWS / ADS Metrics

## 1. Goal

This document defines the unified DWS / ADS metric rules for the 7-day realistic trade-domain project.

The current trusted refresh range is:

```text
2026-03-01 ~ 2026-03-06
```

`2026-03-07` is not included in trusted DWS / ADS refresh because it contains a blocking FCT refund anomaly:

```text
order_id = o1503
order_amount = 50.00
refund_amount = 80.00
net_amount = -30.00
anomaly_type = refund_amount_over_order
anomaly_level = BLOCKER
```

## 2. Layer Responsibility

### FCT

FCT keeps order-grain business facts.

Core tables:

```text
fct_order_di
fct_order_status_di
fct_order_refund_status_di
```

FCT is responsible for:

- one row per clean order
- order status: `VALID` or `CANCELLED`
- refund status: `is_refunded`
- original order amount: `amount`
- refund amount: `refund_amount`
- net amount: `net_amount`
- blocking business anomalies before trusted downstream refresh

### DWS

DWS keeps reusable summary data.

Current key DWS table:

```text
dws_user_order_refund_day_agg
```

Grain:

```text
one user + one day
```

DWS is not the final report table. It is a reusable middle layer that lets ADS avoid scanning fact detail directly.

### ADS

ADS keeps report-facing final metrics.

Current ADS tables:

```text
ads_order_day_overview
ads_order_status_day_overview
ads_order_refund_day_overview
```

Grain:

```text
one day
```

ADS answers business-facing questions such as:

- How many clean orders were placed?
- How many orders were valid or cancelled?
- What was valid GMV?
- How much was refunded?
- What was net GMV after refunds?
- What were cancel and refund rates?

## 3. Unified Metric Rules

### Order Count Metrics

| Metric | Meaning | Rule |
| --- | --- | --- |
| `raw_order_cnt` | all clean orders | `COUNT(*)` from order status/refund status fact |
| `valid_order_cnt` | non-cancelled orders | `order_status = 'VALID'` |
| `cancel_order_cnt` | cancelled orders | `order_status = 'CANCELLED'` |

Core reconciliation:

```text
raw_order_cnt = valid_order_cnt + cancel_order_cnt
```

### GMV Metrics

| Metric | Meaning | Rule |
| --- | --- | --- |
| `raw_gmv` | all clean order amount | sum of all clean order `amount` |
| `valid_gmv` / `gross_valid_gmv` | valid order amount before refund | sum of `amount` where `order_status = 'VALID'` |
| `cancel_amount` | cancelled order amount | sum of `amount` where `order_status = 'CANCELLED'` |

Core reconciliation:

```text
raw_gmv = valid_gmv + cancel_amount
```

### Refund Metrics

| Metric | Meaning | Rule |
| --- | --- | --- |
| `refund_order_cnt` | valid orders with refund | `order_status = 'VALID' AND is_refunded = 1` |
| `refund_amount` | refund amount for valid orders | sum of `refund_amount` where `order_status = 'VALID'` |
| `net_gmv` | valid GMV after refund | `gross_valid_gmv - refund_amount` |

Core reconciliation:

```text
net_gmv = gross_valid_gmv - refund_amount
```

### Rate Metrics

| Metric | Meaning | Rule |
| --- | --- | --- |
| `valid_order_rate` | valid order ratio | `valid_order_cnt / raw_order_cnt` |
| `cancel_order_rate` | cancel order ratio | `cancel_order_cnt / raw_order_cnt` |
| `refund_order_rate` | refund order ratio | `refund_order_cnt / valid_order_cnt` |
| `refund_gmv_rate` | refund amount ratio | `refund_amount / gross_valid_gmv` |

Rates must be between 0 and 1.

## 4. Current Trusted 6-Day Result

### Refund ADS Overview

| dt | raw_order_cnt | valid_order_cnt | cancel_order_cnt | gross_valid_gmv | refund_order_cnt | refund_amount | net_gmv | refund_order_rate | refund_gmv_rate |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 2026-03-01 | 3 | 3 | 0 | 240.00 | 0 | 0.00 | 240.00 | 0.0000 | 0.0000 |
| 2026-03-02 | 4 | 2 | 2 | 210.00 | 0 | 0.00 | 210.00 | 0.0000 | 0.0000 |
| 2026-03-03 | 3 | 3 | 0 | 390.00 | 1 | 50.00 | 340.00 | 0.3333 | 0.1282 |
| 2026-03-04 | 3 | 3 | 0 | 454.00 | 2 | 310.00 | 144.00 | 0.6667 | 0.6828 |
| 2026-03-05 | 3 | 2 | 1 | 130.00 | 1 | 20.00 | 110.00 | 0.5000 | 0.1538 |
| 2026-03-06 | 3 | 3 | 0 | 300.00 | 0 | 0.00 | 300.00 | 0.0000 | 0.0000 |

### Status ADS Overview

| dt | raw_order_cnt | valid_order_cnt | cancel_order_cnt | raw_gmv | valid_gmv | cancel_amount | valid_order_rate | cancel_order_rate |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 2026-03-01 | 3 | 3 | 0 | 240.00 | 240.00 | 0.00 | 1.0000 | 0.0000 |
| 2026-03-02 | 4 | 2 | 2 | 330.00 | 210.00 | 120.00 | 0.5000 | 0.5000 |
| 2026-03-03 | 3 | 3 | 0 | 390.00 | 390.00 | 0.00 | 1.0000 | 0.0000 |
| 2026-03-04 | 3 | 3 | 0 | 454.00 | 454.00 | 0.00 | 1.0000 | 0.0000 |
| 2026-03-05 | 3 | 2 | 1 | 220.00 | 130.00 | 90.00 | 0.6667 | 0.3333 |
| 2026-03-06 | 3 | 3 | 0 | 300.00 | 300.00 | 0.00 | 1.0000 | 0.0000 |

## 5. Cross-Day Refund Rule

`2026-03-06` contains a cross-day refund event:

```text
order_id = o1303
order_dt = 2026-03-04
refund_dt = 2026-03-06
refund_amount = 10.00
```

Current FCT rule attributes refund impact back to the original order partition:

```text
order dt <= refund dt
```

So the refund appears in `2026-03-04` trusted metrics:

```text
2026-03-04 refund_amount = 300.00 + 10.00 = 310.00
2026-03-04 net_gmv = 454.00 - 310.00 = 144.00
```

This is an order-attribution metric view, not a refund-event-date cash-flow view.

## 6. Why 2026-03-07 Is Blocked

`2026-03-07` has this refund anomaly:

```text
order_id = o1503
order_amount = 50.00
refund_amount = 80.00
net_amount = -30.00
```

DWD keeps this refund because it is structurally valid:

- key fields are not empty
- `refund_amount > 0`
- the order can match historical clean orders

FCT exposes it as a business anomaly:

```text
refund_amount > amount
net_amount < 0
```

DQ records it in:

```text
dq_order_refund_anomaly_di
```

The downstream rule is:

```text
BLOCKER anomaly dates do not enter trusted DWS / ADS refresh.
```

This prevents negative net GMV from polluting final ADS metrics.

## 7. DQ And Reconciliation

Current quality strategy:

```text
FCT quality blocks bad business facts.
DWS quality checks reusable summary consistency.
ADS quality checks final report metrics.
Cross-layer reconciliation checks metric transfer correctness.
```

Key checks:

| Layer | Check |
| --- | --- |
| FCT | `net_amount >= 0` |
| FCT | `refund_amount <= amount` for valid orders |
| DWS | `raw_order_cnt = valid_order_cnt + cancel_order_cnt` |
| DWS | `net_gmv = gross_valid_gmv - refund_amount` |
| DWS | DWS summary matches FCT summary |
| ADS | one row per day |
| ADS | metrics are non-negative |
| ADS | rates are between 0 and 1 |
| ADS | ADS summary matches DWS summary |

Reconciliation principle:

```text
DWS is fed by FCT, so DWS reconciles with FCT.
ADS is fed by DWS, so ADS reconciles with DWS.
```

## 8. File Map

DWS:

```text
pipeline/sql/dws/10_dws_user_order_day_agg.sql.tpl
pipeline/sql/dws/11_dws_user_order_refund_day_agg.sql.tpl
pipeline/sql/dws/20_dws_user_order_day_agg_quality.sql.tpl
pipeline/sql/dws/21_dws_user_order_refund_day_agg_quality.sql.tpl
pipeline/run_dws_user_order_day_agg_pipeline.ps1
```

ADS:

```text
pipeline/sql/ads/10_ads_order_day_overview.sql.tpl
pipeline/sql/ads/11_ads_order_status_day_overview.sql.tpl
pipeline/sql/ads/12_ads_order_refund_day_overview.sql.tpl
pipeline/sql/ads/20_ads_order_day_overview_quality.sql.tpl
pipeline/sql/ads/21_ads_order_status_day_overview_quality.sql.tpl
pipeline/sql/ads/22_ads_order_refund_day_overview_quality.sql.tpl
pipeline/sql/ads/30_ads_order_day_overview_reconcile.sql.tpl
pipeline/sql/ads/31_ads_order_status_day_overview_reconcile.sql.tpl
pipeline/sql/ads/32_ads_order_refund_day_overview_reconcile.sql.tpl
pipeline/run_ads_order_day_overview_pipeline.ps1
```

Anomaly handling:

```text
pipeline/sql/dq/11_order_refund_anomaly_detail.sql.tpl
pipeline/README_trade_domain_fct_refund_anomaly.md
```

## 9. Interview Expression

```text
In my trade-domain warehouse project, I defined DWS and ADS metrics around raw orders, valid orders, cancelled orders, refunds, and net GMV. FCT keeps order-grain facts, including order status, refund amount, and net amount. DWS summarizes these facts by user and day, so the aggregation can be reused. ADS then produces one-row-per-day report metrics from DWS.

For metric rules, raw_order_cnt means all clean orders, valid_order_cnt excludes cancelled orders, gross_valid_gmv is valid order amount before refund, refund_amount is valid-order refund amount, and net_gmv equals gross_valid_gmv minus refund_amount. I also added reconciliation rules: DWS reconciles with FCT, ADS reconciles with DWS.

For abnormal data, I do not silently fix bad metrics. For example, on 2026-03-07 one order has amount 50 but refund_amount 80. DWD keeps the structurally valid refund event, FCT identifies negative net_amount, DQ records it as refund_amount_over_order with BLOCKER level, and the date is blocked from trusted DWS/ADS refresh. This prevents negative net GMV from entering report metrics.
```

## 10. Next Step

After this metric standard is fixed, the next recommended step is:

```text
7-day payment reconciliation refresh and anomaly validation
```

Expected payment anomalies:

```text
2026-03-04: o1302 order amount 88.00, payment amount 80.00
2026-03-07: o1502 order amount 90.00, payment amount 100.00
```
