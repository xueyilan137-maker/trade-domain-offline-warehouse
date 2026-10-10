# 订单主题日跑批主执行脚本

这份主执行脚本把订单主题的三层任务串成一条完整日跑批链路：

`FCT -> DWS -> ADS`

## 主脚本

- `pipeline/run_order_subject_daily_pipeline.ps1`

## 脚本大纲

1. 接收跑批日期 `RunDt`
2. 可选初始化三层结果表
   - `fct_order_di`
   - `dws_user_order_day_agg`
   - `ads_order_day_overview`
3. 执行 FCT 层订单事务事实表任务
   - 来源：`dwd_order_p`
   - 结果：`fct_order_di`
   - 校验：订单非空、订单不重复、金额非负
4. 执行 DWS 层用户订单日汇总任务
   - 来源：`fct_order_di`
   - 结果：`dws_user_order_day_agg`
   - 校验：用户粒度不重复、指标非负
5. 执行 ADS 层订单日总览任务
   - 来源：`dws_user_order_day_agg`
   - 结果：`ads_order_day_overview`
   - 校验：单表质量校验
   - 对账：FCT / DWS / ADS 三层 GMV、订单数、下单人数一致
6. 任一层失败，主脚本立刻失败退出
7. 全部成功后，输出最终 ADS 验证 SQL

## 初始化三层表

```powershell
powershell -ExecutionPolicy Bypass -File .\pipeline\run_order_subject_daily_pipeline.ps1 -RunDt 2026-03-01 -InitTables -InitOnly
```

## 跑一天完整订单主题链路

```powershell
powershell -ExecutionPolicy Bypass -File .\pipeline\run_order_subject_daily_pipeline.ps1 -RunDt 2026-03-01
```

## 验证结果

```sql
SELECT *
FROM hive_demo.ads_order_day_overview
WHERE dt = '2026-03-01';
```

## 这次最应该会讲的点

主执行脚本不是重新写业务 SQL，而是编排已有分层任务。

每一层仍然由自己的脚本和 SQL 文件负责，主脚本只负责：

- 顺序
- 参数
- 失败中断
- 总日志
