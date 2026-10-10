#!/usr/bin/env bash
set -euo pipefail

RUN_DT=""
INIT_TABLES="false"
INIT_ONLY="false"

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
    -h|--help)
      cat <<'EOF'
Usage:
  bash run_ads_order_day_overview_pipeline.sh --run-dt 2026-03-01 [--init-tables] [--init-only]
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
SQL_DIR="${SCRIPT_DIR}/sql/ads"
TEMP_DIR="${SCRIPT_DIR}/generated/ads"
LOG_DIR="${SCRIPT_DIR}/logs"
mkdir -p "${TEMP_DIR}" "${LOG_DIR}"

LOG_TS="$(date '+%Y%m%d_%H%M%S_%3N' 2>/dev/null || date '+%Y%m%d_%H%M%S')"
LOG_FILE="${LOG_DIR}/run_ads_order_day_overview_pipeline_${RUN_DT}_${LOG_TS}_$$.log"
touch "${LOG_FILE}"

# shellcheck source=lib/spark_sql_runner.sh
source "${SCRIPT_DIR}/lib/spark_sql_runner.sh"

log_info "ADS order day overview pipeline started. RunDt=${RUN_DT}"
log_info "Log file: ${LOG_FILE}"

if [[ "${INIT_TABLES}" == "true" ]]; then
  log_info "Starting init step"
  invoke_spark_sql_file "${SQL_DIR}/00_init_ads_order_day_overview_tables.sql" "00_init_ads_order_day_overview_tables.sql"
  log_info "Init step finished"
fi

if [[ "${INIT_ONLY}" == "true" ]]; then
  log_info "Init only mode enabled. Skip ADS overview step."
  exit 0
fi

invoke_template_step "ADS Order Day Overview" "10_ads_order_day_overview.sql.tpl" "10_ads_order_day_overview.sql"
invoke_template_step "ADS Order Status Day Overview" "11_ads_order_status_day_overview.sql.tpl" "11_ads_order_status_day_overview.sql"
invoke_template_step "ADS Order Refund Day Overview" "12_ads_order_refund_day_overview.sql.tpl" "12_ads_order_refund_day_overview.sql"
invoke_check_template "Quality check" "20_ads_order_day_overview_quality.sql.tpl" "20_ads_order_day_overview_quality.sql"
invoke_check_template "Order status quality check" "21_ads_order_status_day_overview_quality.sql.tpl" "21_ads_order_status_day_overview_quality.sql"
invoke_check_template "Order refund quality check" "22_ads_order_refund_day_overview_quality.sql.tpl" "22_ads_order_refund_day_overview_quality.sql"
invoke_check_template "Reconcile check" "30_ads_order_day_overview_reconcile.sql.tpl" "30_ads_order_day_overview_reconcile.sql"
invoke_check_template "Order status reconcile check" "31_ads_order_status_day_overview_reconcile.sql.tpl" "31_ads_order_status_day_overview_reconcile.sql"
invoke_check_template "Order refund reconcile check" "32_ads_order_refund_day_overview_reconcile.sql.tpl" "32_ads_order_refund_day_overview_reconcile.sql"

log_info "ADS order day overview pipeline finished successfully for ${RUN_DT}"
echo "Validate with:"
echo "SELECT * FROM hive_demo.ads_order_day_overview WHERE dt = '${RUN_DT}';"
echo "SELECT * FROM hive_demo.ads_order_status_day_overview WHERE dt = '${RUN_DT}';"
echo "SELECT * FROM hive_demo.ads_order_refund_day_overview WHERE dt = '${RUN_DT}';"
echo "Log file: ${LOG_FILE}"
