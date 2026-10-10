# 用户 / 商品 / 渠道主题 7 天回刷

## 1. 本步骤目标

本步骤把 2026-03-01 ~ 2026-03-07 的交易事实接入三个分析视角：

```text
用户主题：按用户等级看交易
商品主题：按商品品类看交易
渠道主题：按渠道来源看交易
```

最后统一汇总到：

```text
ads_trade_multi_theme_day_overview
dq_multi_theme_check_result_di
```

这一步不是重新计算订单事实，而是把已有事实表接到不同维度上做分析。

## 2. 回刷链路

用户主题：

```text
ods_user_info_di
-> dwd_user_info_clean_di
-> dim_user_snapshot_di
+ fct_order_refund_status_di
-> dws_user_level_trade_day_agg
-> ads_user_level_trade_day_overview
```

商品主题：

```text
ods_product_info_di
-> dim_product_snapshot_di

ods_order_item_di
-> dwd_order_item_clean_di
-> fct_order_item_di

fct_order_item_di
+ dim_product_snapshot_di
+ fct_order_refund_status_di
-> dws_category_trade_day_agg
-> ads_category_trade_day_overview
```

渠道主题：

```text
ods_channel_info_di
-> dim_channel_snapshot_di

ods_order_channel_di
-> dwd_order_channel_clean_di
-> fct_order_channel_di

fct_order_refund_status_di
+ fct_order_channel_di
+ dim_channel_snapshot_di
-> dws_channel_trade_day_agg
-> ads_channel_trade_day_overview
```

统一多主题：

```text
ads_user_level_trade_day_overview
+ ads_category_trade_day_overview
+ ads_channel_trade_day_overview
-> ads_trade_multi_theme_day_overview
-> dq_multi_theme_check_result_di
```

## 3. 统一 ADS 汇总结果

| dt | theme_name | row_cnt | valid_amount | refund_amount | net_amount |
| --- | --- | ---: | ---: | ---: | ---: |
| 2026-03-01 | user_theme | 3 | 240.00 | 0.00 | 240.00 |
| 2026-03-01 | product_theme | 3 | 240.00 | 0.00 | 240.00 |
| 2026-03-01 | channel_theme | 3 | 240.00 | 0.00 | 240.00 |
| 2026-03-02 | user_theme | 3 | 210.00 | 0.00 | 210.00 |
| 2026-03-02 | product_theme | 4 | 210.00 | 0.00 | 210.00 |
| 2026-03-02 | channel_theme | 3 | 210.00 | 0.00 | 210.00 |
| 2026-03-03 | user_theme | 3 | 390.00 | 50.00 | 340.00 |
| 2026-03-03 | product_theme | 4 | 390.00 | 50.00 | 340.00 |
| 2026-03-03 | channel_theme | 3 | 390.00 | 50.00 | 340.00 |
| 2026-03-04 | user_theme | 2 | 454.00 | 310.00 | 144.00 |
| 2026-03-04 | product_theme | 3 | 454.00 | 310.00 | 144.00 |
| 2026-03-04 | channel_theme | 3 | 454.00 | 310.00 | 144.00 |
| 2026-03-05 | user_theme | 3 | 130.00 | 20.00 | 110.00 |
| 2026-03-05 | product_theme | 2 | 130.00 | 20.00 | 110.00 |
| 2026-03-05 | channel_theme | 3 | 130.00 | 20.00 | 110.00 |
| 2026-03-06 | user_theme | 3 | 300.00 | 0.00 | 300.00 |
| 2026-03-06 | product_theme | 4 | 300.00 | 0.00 | 300.00 |
| 2026-03-06 | channel_theme | 3 | 300.00 | 0.00 | 300.00 |
| 2026-03-07 | user_theme | 2 | 320.00 | 80.00 | 240.00 |
| 2026-03-07 | product_theme | 3 | 320.00 | 80.00 | 240.00 |
| 2026-03-07 | channel_theme | 4 | 320.00 | 80.00 | 240.00 |

## 4. DQ 结论

2026-03-01 ~ 2026-03-06：

```text
row_count_positive：PASS
source_row_count_reconcile：PASS
theme_row_count_reconcile：PASS
dimension_unique：PASS
metric_non_negative：PASS
rate_range_valid：PASS
user_theme_amount_reconcile：PASS
product_theme_amount_reconcile：PASS
channel_theme_amount_reconcile：PASS
```

2026-03-07：

```text
row_count_positive：PASS
source_row_count_reconcile：PASS
theme_row_count_reconcile：PASS
dimension_unique：PASS
user_theme_amount_reconcile：PASS
product_theme_amount_reconcile：PASS
channel_theme_amount_reconcile：PASS
metric_non_negative：FAIL
rate_range_valid：FAIL
```

03-07 的 FAIL 是预期业务异常传导，不是跑批失败。

## 5. 03-07 异常传导

前置异常：

```text
order_id = o1503
order_amount = 50.00
refund_amount = 80.00
net_amount = -30.00
```

传导到多主题后：

| theme_name | dimension_value | valid_amount | refund_amount | net_amount | refund_rate |
| --- | --- | ---: | ---: | ---: | ---: |
| product_theme | Daily Goods | 50.00 | 80.00 | -30.00 | 1.6000 |
| channel_theme | Mini Program | 50.00 | 80.00 | -30.00 | 1.6000 |

用户主题 03-07 汇总后总净额仍为正，所以统一 ADS 的负指标只出现在商品和渠道两个维度。

## 6. 面试表达

可以这样说：

```text
我把交易事实扩展到了用户、商品、渠道三个分析主题。
用户主题按用户等级看交易贡献，商品主题需要引入订单明细粒度并把订单级退款分摊到商品明细，渠道主题按订单渠道看交易来源。
最后我没有重新算一套交易指标，而是把三个主题 ADS 汇总到统一多主题 ADS，再做统一 DQ。

这个设计能验证两件事：
第一，各主题的金额能和自己的来源 ADS 对齐；
第二，退款金额大于订单金额这类异常会继续传导到商品和渠道维度，并被非负指标和比例范围校验识别出来。
```

