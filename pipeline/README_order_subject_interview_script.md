# 订单主题综合项目面试表达稿

## 1. 1 分钟版本

适合面试刚开始，被问到“你做过什么数据开发项目？”时使用。

```text
我做过一个订单主题的离线数仓项目，主要围绕订单、取消订单和退款订单做分层建模。

整个链路按 DWD、FCT、DWS、ADS 分层设计。DWD 层负责订单清洗和 dirty 异常落表，FCT 层沉淀订单事实、订单状态事实和退款状态事实，DWS 层按用户天粒度汇总订单、取消、退款和净 GMV，ADS 层输出订单日概览、取消订单概览和退款订单概览。

项目里我还做了质量校验和跨层对账，比如 DWS 对 FCT，ADS 对 DWS，并把检查结果统一写入 dq_check_result_di。最后我把整条订单主线接入 Airflow 多 Task DAG，通过 run_dt 参数跑批，已经用 2026-03-05 这个业务日期完整验收通过。
```

这个版本重点突出：

- 你做的是完整链路，不是单个 SQL
- 你理解分层
- 你做过 DQ 和 Airflow
- 你有可验证的跑批结果

## 2. 3 分钟版本

适合面试官愿意听你展开项目时使用。

```text
这个项目是一个订单主题的离线数仓综合练习，目标是把订单域里的下单、取消、退款几个核心业务过程做成一条可运行、可重跑、可校验的离线链路。

在 DWD 层，我先对原始订单表做清洗，处理 order_id、user_id、order_date 为空、amount 为空或为负、订单重复等问题。清洗后的数据进入 dwd_order_clean_di，异常数据不会直接丢掉，而是进入 dwd_order_dirty_di，并记录 dirty_reason，比如 order_id_empty、amount_negative、duplicate_order_id。这样下游用 clean 表保证指标可信，同时 dirty 表可以用于问题追溯。

在 FCT 层，我先基于 clean 表生成 fct_order_di，粒度是一行一笔清洗后的订单。然后结合取消订单明细生成 fct_order_status_di，沉淀订单是 VALID 还是 CANCELLED。最后结合退款明细生成 fct_order_refund_status_di，保留 amount、refund_amount、net_amount 三个金额口径。这里我没有直接修改订单金额，因为直接改金额会丢失原始交易规模，不利于后面同时分析原始 GMV、退款金额和净 GMV。

在 DWS 层，我做了用户天粒度汇总，核心表是 dws_user_order_refund_day_agg，粒度是一个用户一天一行，指标包括 raw_order_cnt、valid_order_cnt、cancel_order_cnt、gross_valid_gmv、refund_amount 和 net_gmv。这样 ADS 不需要直接扫订单明细，而是从 DWS 汇总。

在 ADS 层，我输出了订单日概览、订单状态日概览和退款日概览。比如 2026-03-05 这天，清洗后有 3 笔订单，其中 1 笔取消，1 笔发生 20 元退款，最终 gross_valid_gmv 是 130，net_gmv 是 110。

为了保证链路可信，我在每层都做了质量校验。单表校验包括主键唯一、关键字段不为空、金额非负、比率范围合法；跨层对账包括 DWS 对 FCT、ADS 对 DWS。最后统一写入 dq_check_result_di，方便查看每个检查项的 PASS 或 FAIL。

工程化上，我用 run_dt 作为业务日期参数，SQL 使用 .sql.tpl 模板，通过 INSERT OVERWRITE PARTITION 保证同一天重跑幂等。最后用 Airflow 多 Task DAG 编排，任务包括 validate_run_dt、run_dwd_order_clean、run_fct_order、run_dws_user_order_day_agg、run_ads_order_day_overview、run_order_subject_dq_report。这个 DAG 我已经用 run_dt=2026-03-05 跑通，所有 task 都是 success，统一 DQ 没有非 PASS 结果。
```

这个版本适合完整介绍一次项目。

建议语速不要太快，重点放在：

- DWD clean / dirty
- FCT 状态事实和退款事实
- DWS 用户天粒度
- ADS 指标
- DQ 和 Airflow

## 3. 5 分钟版本

适合面试官明确让你详细讲一个项目时使用。

```text
我这个项目是围绕订单主题做的离线数仓综合项目。它不是单独写一个指标 SQL，而是从数据清洗、事实建模、汇总建模、应用指标、质量校验到 Airflow 调度都做了一遍。

项目的主链路是 dwd_order_p 到 dwd_order_clean_di 和 dwd_order_dirty_di，然后到 fct_order_di、fct_order_status_di、fct_order_refund_status_di，再到 dws_user_order_refund_day_agg，最后到 ads_order_refund_day_overview 和统一 DQ 表 dq_check_result_di。

第一部分是 DWD 清洗治理。原始订单数据里可能有 order_id 为空、user_id 为空、订单日期为空、金额为空、金额为负、订单重复等问题。如果直接用源表算 GMV 和订单数，下游指标会被污染。所以我把数据分成 clean 和 dirty 两类。clean 表只保留可信订单，dirty 表保留异常记录和 dirty_reason。比如重复订单不会全部进入下游，而是按规则保留一条，其他重复记录进入 dirty 表，原因是 duplicate_order_id。这样既保证下游指标正确，也保留了异常追溯能力。

第二部分是事实层建模。fct_order_di 是事务事实表，粒度是一行一笔清洗后的订单，可以支撑订单数、GMV、下单用户数等基础指标。之后我补了取消订单主题，用 dwd_order_cancel_clean_di 生成 fct_order_status_di，把订单标记成 VALID 或 CANCELLED。这个表解决的是订单是否有效的问题，因为取消订单通常要从有效 GMV 中排除。

第三部分是退款建模。退款和取消不一样，取消订单一般直接不计入有效 GMV，而退款订单可能是有效订单发生了部分或全部退款。所以我在 fct_order_refund_status_di 里保留 amount、refund_amount、net_amount。口径是：取消订单 net_amount 等于 0；有效未退款订单 net_amount 等于 amount；有效已退款订单 net_amount 等于 amount 减 refund_amount。这样既能看原始交易规模，也能看扣除退款后的净 GMV。

第四部分是 DWS。最小闭环其实可以从 FCT 直接到 ADS，但我补了 DWS 层，因为 DWS 可以沉淀可复用的中间汇总。退款主题里我做了 dws_user_order_refund_day_agg，粒度是一个用户一天一行，指标包括原始订单数、有效订单数、取消订单数、有效 GMV、退款订单数、退款金额和净 GMV。这样以后如果要做用户维度分析，不需要每次都扫明细事实表。

第五部分是 ADS。ADS 面向最终报表或分析结果，比如 ads_order_refund_day_overview 是一天一行，输出 raw_order_cnt、valid_order_cnt、cancel_order_cnt、gross_valid_gmv、refund_order_cnt、refund_amount、net_gmv、refund_order_rate、refund_gmv_rate。2026-03-05 这天的验证结果是 raw_order_cnt 为 3，valid_order_cnt 为 2，cancel_order_cnt 为 1，gross_valid_gmv 为 130，refund_amount 为 20，net_gmv 为 110。

第六部分是 DQ。我的 DQ 分两类，一类是每层脚本内的 quality SQL，用于跑批时拦截明显问题；另一类是统一 DQ 汇总，把检查结果写入 dq_check_result_di。单表检查包括字段非空、金额非负、主键唯一、比率范围合法；跨层对账包括 DWS 对 FCT、ADS 对 DWS。我理解的原则是，谁直接喂给 ADS，ADS 就先跟谁对账；DWS 来源是 FCT，所以 DWS 对 FCT。

第七部分是工程化和调度。脚本都支持 run_dt 参数，SQL 用 .sql.tpl 模板，通过 __RUN_DT__ 渲染业务日期。写表时使用 INSERT OVERWRITE PARTITION，所以同一天重跑是幂等的。PowerShell 用于 Windows 手动验证，Shell 用于 Airflow 容器执行。Airflow DAG 拆成多个 Task，包括参数校验、DWD、FCT、DWS、ADS 和统一 DQ 汇总。相比单 Task DAG，多 Task 的好处是失败时可以直接看到是哪一层失败，也可以单独 Clear and Retry。

最后我用 run_dt=2026-03-05 跑了 Airflow DAG 验收，validate_run_dt、run_dwd_order_clean、run_fct_order、run_dws_user_order_day_agg、run_ads_order_day_overview、run_order_subject_dq_report 全部 success。DWS 退款汇总有 u10、u11、u14 三行，ADS 净 GMV 是 110，dq_check_result_di 里没有非 PASS 检查项。
```

这个版本更适合你主动讲项目，讲完基本能覆盖：

- 建模
- 指标
- DQ
- 调度
- 幂等
- 验收

## 4. 常见追问回答

### 4.1 你这个项目的亮点是什么？

```text
我觉得亮点主要有三个。

第一，不是单点 SQL，而是完整的订单主题链路，从 DWD 清洗到 ADS 指标，再到 DQ 和 Airflow 调度。

第二，建模时区分了订单、取消和退款的业务含义。取消订单影响有效订单和有效 GMV，退款订单则保留 amount、refund_amount、net_amount 三个口径，用来同时分析原始 GMV 和净 GMV。

第三，做了质量校验和跨层对账。比如 DWS 对 FCT，ADS 对 DWS，检查结果还会统一写入 dq_check_result_di，方便复盘。
```

### 4.2 为什么要做 clean 和 dirty 两张表？

```text
clean 表是给下游使用的可信明细，dirty 表是保留异常明细和异常原因。

如果只过滤异常数据，下游指标虽然干净了，但后面很难解释为什么源表有 7 行，clean 表只剩 3 行。dirty 表可以保留 order_id_empty、amount_negative、duplicate_order_id 这类原因，方便数据治理和问题追溯。
```

### 4.3 为什么退款不直接改订单金额？

```text
因为直接改订单金额会丢失原始交易规模，也不利于区分退款金额和净 GMV。

所以我保留 amount、refund_amount、net_amount。amount 表示原始订单金额，refund_amount 表示退款金额，net_amount 表示退款后的净金额。这样既能看原始 GMV，也能看退款后的净 GMV。
```

### 4.4 FCT、DWS、ADS 分别是什么作用？

```text
FCT 是事实层，沉淀业务过程明细，比如一行一笔订单，以及订单是否取消、是否退款、净金额是多少。

DWS 是可复用汇总层，比如一个用户一天一行，提前聚合用户天粒度的订单、取消和退款指标。

ADS 是面向应用和报表的指标层，比如一天一行的订单退款概览，直接给业务或报表使用。
```

### 4.5 为什么 ADS 要对 DWS 对账，不直接对 FCT？

```text
我的理解是谁直接喂给 ADS，ADS 就先跟谁对账。

当前 ads_order_refund_day_overview 是从 dws_user_order_refund_day_agg 汇总来的，所以 ADS 应该优先对 DWS。DWS 本身再对 FCT 做对账。这样每一层只对自己的直接来源负责，链路关系更清楚。
```

### 4.6 Airflow 在项目里解决了什么？

```text
Airflow 主要解决任务编排、依赖管理和失败定位。

我把订单主题拆成 validate_run_dt、DWD、FCT、DWS、ADS、DQ 几个 Task。这样比一个大脚本更清楚，失败时能直接看到是哪一层失败，也可以单独重跑失败 Task。
```

### 4.7 你怎么保证重跑不会产生重复数据？

```text
我使用 run_dt 控制业务日期，写分区表时使用 INSERT OVERWRITE TABLE xxx PARTITION(dt='run_dt')。

这样同一天重跑时会覆盖当前日期分区，而不是追加数据。所以只要源数据和逻辑不变，重跑结果就是幂等的。
```

### 4.8 单表质量校验和跨层对账有什么区别？

```text
单表质量校验看表自己是否合理，比如主键是否重复、关键字段是否为空、金额是否非负、比率是否在 0 到 1 之间。

跨层对账看上下游是否一致，比如 DWS 汇总结果是否和 FCT 明细汇总一致，ADS 汇总结果是否和 DWS 一致。

单表校验解决表内质量，跨层对账解决链路传递中的漏数、重复或口径不一致。
```

## 5. 背诵建议

不要逐字背整段，建议按下面这个顺序记：

```text
项目定位
  -> DWD clean/dirty
  -> FCT 订单、取消、退款事实
  -> DWS 用户天汇总
  -> ADS 日指标
  -> DQ 单表校验和跨层对账
  -> Airflow 多 Task 调度
  -> 2026-03-05 验收结果
```

最核心的一句话：

```text
这是一个订单主题离线数仓综合项目，我把订单、取消、退款按 DWD、FCT、DWS、ADS 分层建模，并接入 DQ 和 Airflow 调度，最终能稳定产出有效 GMV、退款金额和净 GMV 等指标。
```

