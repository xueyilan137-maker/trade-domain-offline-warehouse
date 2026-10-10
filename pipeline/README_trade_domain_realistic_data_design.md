# Trade Domain Realistic Demo Data Design

## 1. Goal

This document designs a 7-day demo dataset for the trade domain.

Date range:

```text
2026-03-01 ~ 2026-03-07
```

The dataset is used to upgrade the current learning project from a single-day demo into a more realistic offline warehouse practice project.

It should support:

- order clean and dirty handling
- cancel order modeling
- refund order modeling
- payment reconciliation
- user / product / channel theme analysis
- multi-theme ADS aggregation
- DQ and cross-layer reconciliation
- single-day rerun and range backfill

## 2. Design Principles

The goal is not to create a large dataset. The goal is to cover common trade-domain scenarios with a small but meaningful dataset.

The 7-day demo data should cover:

- normal orders
- successful payments
- unpaid orders
- user cancel
- timeout cancel
- partial refund
- full refund
- cross-day payment
- cross-day refund
- payment amount mismatch
- missing payment
- duplicate order
- empty key fields
- negative amount
- refund amount greater than order amount
- user level changes
- product category analysis
- channel analysis

## 3. Daily Scenario Plan

| Date | Scenario | Purpose |
| --- | --- | --- |
| 2026-03-01 | Basic normal trade day | Validate basic order, GMV and payment success metrics |
| 2026-03-02 | Cancel order day | Validate cancel orders are excluded from valid GMV |
| 2026-03-03 | Partial refund day | Validate gross GMV, refund amount and net GMV |
| 2026-03-04 | Full refund and payment mismatch day | Validate refund and payment reconciliation exceptions |
| 2026-03-05 | Current learning sample day | Keep the existing order/cancel/refund/multi-theme sample reproducible |
| 2026-03-06 | Cross-day payment and cross-day refund day | Understand business date and event date differences |
| 2026-03-07 | Dirty data and DQ validation day | Validate dirty table and DQ checks |

## 4. Order Data Draft

Target source table:

```text
dwd_order_p
```

| dt | order_id | user_id | order_date | amount | Scenario |
| --- | --- | --- | --- | ---: | --- |
| 2026-03-01 | o1001 | u10 | 2026-03-01 | 100.00 | Normal paid order |
| 2026-03-01 | o1002 | u11 | 2026-03-01 | 80.00 | Normal paid order |
| 2026-03-01 | o1003 | u12 | 2026-03-01 | 60.00 | Unpaid order |
| 2026-03-02 | o1101 | u10 | 2026-03-02 | 120.00 | Normal paid order |
| 2026-03-02 | o1102 | u13 | 2026-03-02 | 50.00 | User cancelled order |
| 2026-03-02 | o1103 | u14 | 2026-03-02 | 70.00 | Timeout cancelled order |
| 2026-03-02 | o1104 | u15 | 2026-03-02 | 90.00 | Normal paid order |
| 2026-03-03 | o1201 | u10 | 2026-03-03 | 200.00 | Partial refund order |
| 2026-03-03 | o1202 | u11 | 2026-03-03 | 40.00 | Normal paid order |
| 2026-03-03 | o1203 | u16 | 2026-03-03 | 150.00 | Normal paid order |
| 2026-03-04 | o1301 | u17 | 2026-03-04 | 300.00 | Full refund order |
| 2026-03-04 | o1302 | u12 | 2026-03-04 | 88.00 | Payment amount mismatch |
| 2026-03-04 | o1303 | u13 | 2026-03-04 | 66.00 | Normal paid order, later cross-day refund |
| 2026-03-05 | o2001 | u10 | 2026-03-05 | 100.00 | Existing sample, partial refund |
| 2026-03-05 | o2002 | u11 | 2026-03-05 | 90.00 | Existing sample, cancelled |
| 2026-03-05 | o2005 | u14 | 2026-03-05 | 30.00 | Existing sample, normal |
| 2026-03-06 | o1401 | u18 | 2026-03-05 | 75.00 | Cross-day payment |
| 2026-03-06 | o1402 | u19 | 2026-03-06 | 180.00 | Normal paid order |
| 2026-03-06 | o1403 | u10 | 2026-03-06 | 45.00 | Normal paid order |
| 2026-03-07 | o1501 | u20 | 2026-03-07 | 100.00 | Normal paid order |
| 2026-03-07 | o1502 | u21 | 2026-03-07 | 90.00 | Payment amount mismatch |
| 2026-03-07 | o1503 | u22 | 2026-03-07 | 50.00 | Refund amount abnormal |
| 2026-03-07 | o1504 | u23 | 2026-03-07 | 70.00 | Duplicate order, lower amount |
| 2026-03-07 | o1504 | u23 | 2026-03-07 | 80.00 | Duplicate order, retained row |
| 2026-03-07 | empty | u24 | 2026-03-07 | 60.00 | Empty order_id |
| 2026-03-07 | o1506 | empty | 2026-03-07 | 40.00 | Empty user_id |
| 2026-03-07 | o1507 | u25 | 2026-03-07 | -20.00 | Negative amount |

## 5. Cancel Data Draft

Target source table:

```text
dwd_order_cancel_p
```

| dt | order_id | user_id | cancel_date | cancel_reason |
| --- | --- | --- | --- | --- |
| 2026-03-02 | o1102 | u13 | 2026-03-02 | user_cancel |
| 2026-03-02 | o1103 | u14 | 2026-03-02 | timeout_cancel |
| 2026-03-05 | o2002 | u11 | 2026-03-05 | user_cancel |

## 6. Refund Data Draft

Target source table:

```text
dwd_order_refund_p
```

| dt | order_id | user_id | refund_date | refund_amount | refund_reason |
| --- | --- | --- | --- | ---: | --- |
| 2026-03-03 | o1201 | u10 | 2026-03-03 | 50.00 | partial_refund |
| 2026-03-04 | o1301 | u17 | 2026-03-04 | 300.00 | full_refund |
| 2026-03-05 | o2001 | u10 | 2026-03-05 | 20.00 | partial_refund |
| 2026-03-06 | o1303 | u13 | 2026-03-06 | 10.00 | partial_refund_cross_day |
| 2026-03-07 | o1503 | u22 | 2026-03-07 | 80.00 | refund_amount_over_order |

## 7. Payment Data Draft

Target source table:

```text
dwd_payment_p
```

| dt | payment_id | order_id | user_id | pay_date | pay_amount | pay_status | Scenario |
| --- | --- | --- | --- | --- | ---: | --- | --- |
| 2026-03-01 | p1001 | o1001 | u10 | 2026-03-01 | 100.00 | SUCCESS | Normal |
| 2026-03-01 | p1002 | o1002 | u11 | 2026-03-01 | 80.00 | SUCCESS | Normal |
| 2026-03-02 | p1101 | o1101 | u10 | 2026-03-02 | 120.00 | SUCCESS | Normal |
| 2026-03-02 | p1104 | o1104 | u15 | 2026-03-02 | 90.00 | SUCCESS | Normal |
| 2026-03-03 | p1201 | o1201 | u10 | 2026-03-03 | 200.00 | SUCCESS | Normal |
| 2026-03-03 | p1202 | o1202 | u11 | 2026-03-03 | 40.00 | SUCCESS | Normal |
| 2026-03-03 | p1203 | o1203 | u16 | 2026-03-03 | 150.00 | SUCCESS | Normal |
| 2026-03-04 | p1301 | o1301 | u17 | 2026-03-04 | 300.00 | SUCCESS | Full refund order |
| 2026-03-04 | p1302 | o1302 | u12 | 2026-03-04 | 80.00 | SUCCESS | Paid amount less than order amount |
| 2026-03-04 | p1303 | o1303 | u13 | 2026-03-04 | 66.00 | SUCCESS | Normal, later cross-day refund |
| 2026-03-05 | p2001 | o2001 | u10 | 2026-03-05 | 100.00 | SUCCESS | Existing sample |
| 2026-03-05 | p2005 | o2005 | u14 | 2026-03-05 | 30.00 | SUCCESS | Existing sample |
| 2026-03-06 | p1401 | o1401 | u18 | 2026-03-06 | 75.00 | SUCCESS | Cross-day payment |
| 2026-03-06 | p1402 | o1402 | u19 | 2026-03-06 | 180.00 | SUCCESS | Normal |
| 2026-03-06 | p1403 | o1403 | u10 | 2026-03-06 | 45.00 | SUCCESS | Normal |
| 2026-03-07 | p1501 | o1501 | u20 | 2026-03-07 | 100.00 | SUCCESS | Normal |
| 2026-03-07 | p1502 | o1502 | u21 | 2026-03-07 | 100.00 | SUCCESS | Paid amount greater than order amount |
| 2026-03-07 | p1503 | o1503 | u22 | 2026-03-07 | 50.00 | SUCCESS | Refund amount abnormal |
| 2026-03-07 | p1504 | o1504 | u23 | 2026-03-07 | 80.00 | SUCCESS | Matches retained duplicate order row |

## 8. User Dimension Draft

Target source table:

```text
ods_user_info_di
```

User levels should include stable users and changed users.

Example:

| dt | user_id | user_name | user_level |
| --- | --- | --- | --- |
| 2026-03-01 | u10 | Alice | GOLD |
| 2026-03-02 | u10 | Alice | GOLD |
| 2026-03-03 | u10 | Alice | VIP |
| 2026-03-05 | u10 | Alice | GOLD |
| 2026-03-07 | u23 | Nick | NORMAL |

For implementation, each day should include all users appearing in that day's orders, so that user theme joins do not fall into `unknown`.

## 9. Product Dimension Draft

Target source table:

```text
ods_product_info_di
```

Product dimension can stay stable in the first realistic version.

| product_id | product_name | category_id | category_name | brand_name |
| --- | --- | --- | --- | --- |
| p01 | Mouse | c01 | Digital Accessories | Logitech |
| p02 | Keyboard | c01 | Digital Accessories | Keychron |
| p03 | Bottle | c02 | Daily Goods | Migo |
| p04 | T-Shirt | c03 | Clothing | Uniqlo |
| p05 | Book | c04 | Books | OReilly |

## 10. Channel Dimension Draft

Target source table:

```text
ods_channel_info_di
```

Channel dimension can stay stable in the first realistic version.

| channel_id | channel_name | channel_type |
| --- | --- | --- |
| ch01 | App | Owned |
| ch02 | Mini Program | Owned |
| ch03 | Ad Campaign | Paid |
| ch04 | Organic Search | Free |

## 11. Order Item and Order Channel Draft

Target source tables:

```text
ods_order_item_di
ods_order_channel_di
```

Design rules:

- every valid business order should have at least one order item row
- some orders should have multiple product rows
- each order should have one channel row
- product item amount should sum to order amount for clean business orders
- duplicate or dirty orders can be used to validate DWD cleaning and DQ

Example:

| order_id | product_id | item_cnt | item_amount |
| --- | --- | ---: | ---: |
| o1001 | p01 | 1 | 40.00 |
| o1001 | p02 | 1 | 60.00 |
| o1002 | p03 | 1 | 80.00 |
| o1201 | p01 | 1 | 100.00 |
| o1201 | p04 | 2 | 100.00 |

Example:

| order_id | channel_id |
| --- | --- |
| o1001 | ch01 |
| o1002 | ch02 |
| o1102 | ch03 |
| o1401 | ch04 |

## 12. Expected Learning Value

This dataset supports the following learning tasks:

- daily partition processing
- idempotent rerun
- range backfill
- trend metrics
- order status modeling
- payment reconciliation
- refund net GMV modeling
- dirty data handling
- user-level trade analysis
- category-level trade analysis
- channel-level trade analysis
- multi-theme ADS aggregation
- multi-theme DQ reconciliation
- Airflow scheduling
- Python runner orchestration

## 13. Implementation Plan

Recommended implementation order:

1. Create 7-day seed SQL for orders, cancels, refunds and payments.
2. Create 7-day seed SQL for user, product and channel dimensions.
3. Create 7-day seed SQL for order items and order channels.
4. Run daily pipelines for `2026-03-01` to `2026-03-07`.
5. Validate DWD clean/dirty results.
6. Validate FCT, DWS and ADS metrics.
7. Validate payment reconciliation and multi-theme DQ.
8. Use Python runner for range backfill.
9. Connect the enhanced pipeline to Airflow.

## 14. One-Sentence Summary

This 7-day demo dataset is designed to make the trade domain project closer to real offline warehouse work by covering normal trade, cancel, refund, payment reconciliation, multi-theme analysis, DQ and backfill scenarios.
