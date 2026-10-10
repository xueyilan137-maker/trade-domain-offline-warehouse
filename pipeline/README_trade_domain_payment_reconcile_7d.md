# 7 天支付对账回刷与异常验证

## 1. 本步骤目标

本步骤把交易域 2026-03-01 ~ 2026-03-07 的支付链路回刷一遍，并验证订单与支付是否一致。

链路：

```text
dwd_payment_p
-> dwd_payment_clean_di / dwd_payment_dirty_di
-> fct_payment_di
+ fct_order_di
-> dq_order_payment_reconcile_di
-> ads_order_payment_reconcile_overview
-> dq_check_result_di
```

支付对账解决的问题不是“退款后净 GMV 怎么算”，而是“订单应付金额和实际支付金额是否对得上”。

## 2. 核心口径

`dq_order_payment_reconcile_di` 一行代表一个订单和支付的对账结果。

对账状态：

```text
matched：订单金额 = 支付金额
amount_mismatch：订单金额和支付金额不一致
order_without_payment：有订单，没有支付
payment_without_order：有支付，没有订单
```

差异金额：

```text
diff_amount = order_amount - pay_amount
```

所以：

```text
diff_amount > 0：少支付
diff_amount < 0：多支付
```

## 3. 7 天异常明细

| dt | order_id | order_amount | payment_id | pay_amount | reconcile_status | diff_amount | 说明 |
| --- | --- | ---: | --- | ---: | --- | ---: | --- |
| 2026-03-01 | o1003 | 60.00 | NULL | NULL | order_without_payment | 60.00 | 未支付订单 |
| 2026-03-02 | o1102 | 50.00 | NULL | NULL | order_without_payment | 50.00 | 取消订单无支付 |
| 2026-03-02 | o1103 | 70.00 | NULL | NULL | order_without_payment | 70.00 | 取消订单无支付 |
| 2026-03-04 | o1302 | 88.00 | p1302 | 80.00 | amount_mismatch | 8.00 | 少支付 8 |
| 2026-03-05 | o2002 | 90.00 | NULL | NULL | order_without_payment | 90.00 | 取消订单无支付 |
| 2026-03-07 | o1502 | 90.00 | p1502 | 100.00 | amount_mismatch | -10.00 | 多支付 10 |

## 4. ADS 汇总结果

| dt | reconcile_cnt | matched_cnt | amount_mismatch_cnt | order_without_payment_cnt | payment_without_order_cnt | abnormal_cnt | matched_rate | abnormal_rate | total_diff_amount |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 2026-03-01 | 3 | 2 | 0 | 1 | 0 | 1 | 0.6667 | 0.3333 | 60.00 |
| 2026-03-02 | 4 | 2 | 0 | 2 | 0 | 2 | 0.5000 | 0.5000 | 120.00 |
| 2026-03-03 | 3 | 3 | 0 | 0 | 0 | 0 | 1.0000 | 0.0000 | 0.00 |
| 2026-03-04 | 3 | 2 | 1 | 0 | 0 | 1 | 0.6667 | 0.3333 | 8.00 |
| 2026-03-05 | 3 | 2 | 0 | 1 | 0 | 1 | 0.6667 | 0.3333 | 90.00 |
| 2026-03-06 | 3 | 3 | 0 | 0 | 0 | 0 | 1.0000 | 0.0000 | 0.00 |
| 2026-03-07 | 4 | 3 | 1 | 0 | 0 | 1 | 0.7500 | 0.2500 | 10.00 |

## 5. DQ 结论

`dq_check_result_di` 中支付对账核心检查：

```text
row_count_positive：PASS
dirty_reason_not_null：PASS
all_orders_matched：
  2026-03-03 PASS
  2026-03-06 PASS
  其他日期 FAIL
```

这里的 `all_orders_matched = FAIL` 是符合预期的业务异常沉淀，不代表 pipeline 跑批失败。

## 6. 本次修正

修正文件：

```text
pipeline/sql/payment/50_order_payment_dq_report.sql.tpl
```

修正点：

```sql
COALESCE(SUM(CASE WHEN dirty_reason IS NULL OR TRIM(dirty_reason) = '' THEN 1 ELSE 0 END), 0)
```

原因：

```text
dwd_payment_dirty_di 某天没有脏数据时，SUM(...) 会返回 NULL。
如果直接判断 NULL = 0，会被 SQL 三值逻辑判成未知，从而误判为 FAIL。
```

修正后，空 dirty 表表示没有 dirty_reason 为空的脏数据，应该是 PASS。

## 7. 面试表达

可以这样说：

```text
我在交易域里单独做了订单支付对账链路。订单事实表提供应付金额，支付事实表提供实付金额，
通过订单和支付 full outer join 识别四类结果：金额一致、金额不一致、有单无支付、有支付无单。
然后把异常明细沉淀到 DQ 明细表，把每日匹配率、异常率、差异金额沉淀到 ADS。

这一步和退款主题不一样：退款主题关注售后后净 GMV，支付对账关注订单金额和支付金额是否一致。
对账异常不会直接改交易指标，而是作为财务和数据质量异常单独沉淀。
```

