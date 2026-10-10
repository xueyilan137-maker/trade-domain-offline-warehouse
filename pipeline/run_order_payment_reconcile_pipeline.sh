#!/usr/bin/env bash
set -euo pipefail

RUN_DT=""
INIT_TABLES="false"
INIT_ONLY="false"
SEED_DEMO="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-dt)
      RUN_DT="${2:-}"
      shift 2
      ;;
    --init-tables)
      INIT_TABLES="true"
      shift
      ;;
    --init-only)
      INIT_ONLY="true"
      shift
      ;;
    --seed-demo)
      SEED_DEMO="true"
      shift
      ;;
    -h|--help)
      cat <<'EOF'
Usage:
  bash run_order_payment_reconcile_pipeline.sh --run-dt 2026-03-05 [--init-tables] [--init-only] [--seed-demo]
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "${RUN_DT}" ]]; then
  echo "Missing required argument: --run-dt" >&2
  exit 1
fi

date -d "${RUN_DT}" '+%F' >/dev/null

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_DIR="${SCRIPT_DIR}/sql/payment"
TEMP_DIR="${SCRIPT_DIR}/generated/payment"
LOG_DIR="${SCRIPT_DIR}/logs"
mkdir -p "${TEMP_DIR}" "${LOG_DIR}"

LOG_TS="$(date '+%Y%m%d_%H%M%S_%3N' 2>/dev/null || date '+%Y%m%d_%H%M%S')"
LOG_FILE="${LOG_DIR}/run_order_payment_reconcile_pipeline_${RUN_DT}_${LOG_TS}_$$.log"
touch "${LOG_FILE}"

# shellcheck source=lib/spark_sql_runner.sh
source "${SCRIPT_DIR}/lib/spark_sql_runner.sh"

log_info "Order payment reconcile pipeline started. RunDt=${RUN_DT}"
log_info "Log file: ${LOG_FILE}"

if [[ "${INIT_TABLES}" == "true" ]]; then
  log_info "Starting init step"
  invoke_spark_sql_file "${SQL_DIR}/00_init_payment_reconcile_tables.sql" "00_init_payment_reconcile_tables.sql"
  log_info "Init step finished"
fi

if [[ "${INIT_ONLY}" == "true" ]]; then
  log_info "Init only mode enabled. Skip payment reconcile steps."
  exit 0
fi

if [[ "${SEED_DEMO}" == "true" ]]; then
  log_info "Starting demo seed step"
  invoke_spark_sql_file "${SQL_DIR}/01_seed_dwd_payment_p_demo.sql" "01_seed_dwd_payment_p_demo.sql"
  log_info "Demo seed step finished"
fi

invoke_template_step "DWD Payment Dirty Capture" "11_dwd_payment_dirty_di.sql.tpl" "11_dwd_payment_dirty_di.sql"
invoke_template_step "DWD Payment Clean" "10_dwd_payment_clean_di.sql.tpl" "10_dwd_payment_clean_di.sql"
invoke_check_template "DWD payment quality check" "21_dwd_payment_quality.sql.tpl" "21_dwd_payment_quality.sql"
invoke_template_step "Payment Fact" "20_fct_payment_di.sql.tpl" "20_fct_payment_di.sql"
invoke_template_step "Order Payment Reconcile" "30_dq_order_payment_reconcile_di.sql.tpl" "30_dq_order_payment_reconcile_di.sql"
invoke_check_template "Order payment reconcile structural check" "40_order_payment_reconcile_quality.sql.tpl" "40_order_payment_reconcile_quality.sql"
invoke_template_step "Order Payment DQ Report" "50_order_payment_dq_report.sql.tpl" "50_order_payment_dq_report.sql"
invoke_template_step "ADS Order Payment Reconcile Overview" "60_ads_order_payment_reconcile_overview.sql.tpl" "60_ads_order_payment_reconcile_overview.sql"
invoke_check_template "ADS order payment reconcile overview quality check" "70_ads_order_payment_reconcile_overview_quality.sql.tpl" "70_ads_order_payment_reconcile_overview_quality.sql"

log_info "Order payment reconcile pipeline finished successfully for ${RUN_DT}"
echo "Validate with:"
echo "SELECT * FROM hive_demo.dwd_payment_dirty_di WHERE dt = '${RUN_DT}' ORDER BY dirty_reason, payment_id;"
echo "SELECT * FROM hive_demo.dq_order_payment_reconcile_di WHERE dt = '${RUN_DT}' ORDER BY reconcile_status, order_id;"
echo "SELECT * FROM hive_demo.ads_order_payment_reconcile_overview WHERE dt = '${RUN_DT}';"
echo "Log file: ${LOG_FILE}"
