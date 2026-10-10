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
  bash run_order_subject_dq_report_pipeline.sh --run-dt 2026-03-05 [--init-tables] [--init-only]
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
SQL_DIR="${SCRIPT_DIR}/sql/dq"
TEMP_DIR="${SCRIPT_DIR}/generated/dq"
LOG_DIR="${SCRIPT_DIR}/logs"
mkdir -p "${TEMP_DIR}" "${LOG_DIR}"

LOG_TS="$(date '+%Y%m%d_%H%M%S_%3N' 2>/dev/null || date '+%Y%m%d_%H%M%S')"
LOG_FILE="${LOG_DIR}/run_order_subject_dq_report_pipeline_${RUN_DT}_${LOG_TS}_$$.log"
touch "${LOG_FILE}"

# shellcheck source=lib/spark_sql_runner.sh
source "${SCRIPT_DIR}/lib/spark_sql_runner.sh"

log_info "Order subject DQ report pipeline started. RunDt=${RUN_DT}"
log_info "Log file: ${LOG_FILE}"

if [[ "${INIT_TABLES}" == "true" ]]; then
  log_info "Starting init step"
  invoke_spark_sql_file "${SQL_DIR}/00_init_dq_check_result_tables.sql" "00_init_dq_check_result_tables.sql"
  log_info "Init step finished"
fi

if [[ "${INIT_ONLY}" == "true" ]]; then
  log_info "Init only mode enabled. Skip DQ report step."
  exit 0
fi

invoke_template_step "Order Subject DQ Report" "10_order_subject_dq_report.sql.tpl" "10_order_subject_dq_report.sql"

log_info "Order subject DQ report pipeline finished successfully for ${RUN_DT}"
echo "Validate with:"
echo "SELECT * FROM hive_demo.dq_check_result_di WHERE dt = '${RUN_DT}' ORDER BY pipeline_name, layer_name, table_name, check_name;"
echo "Log file: ${LOG_FILE}"
