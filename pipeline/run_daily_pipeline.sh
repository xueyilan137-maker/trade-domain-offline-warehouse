#!/usr/bin/env bash
set -euo pipefail

RUN_DT=""
INIT_TABLES="false"

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
    -h|--help)
      cat <<'EOF'
Usage:
  bash run_daily_pipeline.sh --run-dt 2026-03-03 [--init-tables]

Options:
  --run-dt       Required. Pipeline date in YYYY-MM-DD format.
  --init-tables  Optional. Initialize partition tables before running DWD/DWS/ADS.
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_DIR="${SCRIPT_DIR}/sql"
TEMP_DIR="${SCRIPT_DIR}/generated"
LOG_DIR="${SCRIPT_DIR}/logs"
mkdir -p "${TEMP_DIR}" "${LOG_DIR}"

LOG_TS="$(date '+%Y%m%d_%H%M%S_%3N' 2>/dev/null || date '+%Y%m%d_%H%M%S')"
RUN_ID="$$"
LOG_FILE="${LOG_DIR}/run_daily_pipeline_${RUN_DT}_${LOG_TS}_${RUN_ID}.log"
touch "${LOG_FILE}"

log() {
  local level="$1"
  shift
  local msg="$*"
  local line="[$(date '+%F %T')] [${level}] ${msg}"
  echo "${line}"
  printf '%s\n' "${line}" >> "${LOG_FILE}"
}

log_info() {
  log INFO "$@"
}

log_warn() {
  log WARN "$@"
}

log_error() {
  log ERROR "$@"
}

new_sql_from_template() {
  local template_path="$1"
  local output_name="$2"
  local out_path="${TEMP_DIR}/${output_name}"

  sed "s/__RUN_DT__/${RUN_DT}/g" "${template_path}" > "${out_path}"
  printf '%s\n' "${out_path}"
}

invoke_spark_sql_file() {
  local local_sql_path="$1"
  local sql_label="$2"
  local container_sql="/tmp/$(basename "${local_sql_path}")"
  local output=""

  log_info "Executing SQL file: ${sql_label}"

  docker cp "${local_sql_path}" "hadoop-spark:${container_sql}" >/dev/null

  set +e
  output=$(docker exec hadoop-spark bash -lc "/spark/bin/spark-sql --master local[*] -f ${container_sql}" 2>&1)
  local exit_code=$?
  set -e

  if [[ -n "${output}" ]]; then
    while IFS= read -r line; do
      if [[ "${line}" == *WARN* ]]; then
        log_warn "${line}"
      else
        log SPARK "${line}"
      fi
    done <<< "${output}"
  fi

  if [[ ${exit_code} -ne 0 ]]; then
    log_error "SQL execution failed: ${sql_label}"
    return ${exit_code}
  fi

  return 0
}

invoke_template_step() {
  local step_name="$1"
  local template_name="$2"
  local output_name="$3"
  local sql_path=""

  log_info "Starting ${step_name} step for ${RUN_DT}"
  sql_path="$(new_sql_from_template "${SQL_DIR}/${template_name}" "${output_name}")"
  invoke_spark_sql_file "${sql_path}" "${output_name}"
  log_info "${step_name} step finished for ${RUN_DT}"
}

invoke_quality_checks() {
  local quality_sql=""
  local quality_output=""
  local container_sql="/tmp/40_quality_checks.sql"

  log_info "Starting quality check step for ${RUN_DT}"
  quality_sql="$(new_sql_from_template "${SQL_DIR}/40_quality_checks.sql.tpl" "40_quality_checks.sql")"

  docker cp "${quality_sql}" "hadoop-spark:${container_sql}" >/dev/null

  set +e
  quality_output=$(docker exec hadoop-spark bash -lc "/spark/bin/spark-sql --master local[*] -f ${container_sql}" 2>&1)
  local exit_code=$?
  set -e

  if [[ -n "${quality_output}" ]]; then
    while IFS= read -r line; do
      if [[ "${line}" == *WARN* ]]; then
        log_warn "${line}"
      else
        log SPARK "${line}"
      fi
    done <<< "${quality_output}"
  fi

  if [[ ${exit_code} -ne 0 ]]; then
    log_error "SQL execution failed: 40_quality_checks.sql"
    return ${exit_code}
  fi

  if echo "${quality_output}" | grep -q 'check failed'; then
    log_error "Quality check failed for ${RUN_DT}. Check log: ${LOG_FILE}"
    return 1
  fi

  log_info "Quality check passed for ${RUN_DT}"
}

log_info "Pipeline started. RunDt=${RUN_DT}"
log_info "Log file: ${LOG_FILE}"

if [[ "${INIT_TABLES}" == "true" ]]; then
  log_info "Starting init step"
  invoke_spark_sql_file "${SQL_DIR}/00_init_partition_tables.sql" "00_init_partition_tables.sql"
  log_info "Init step finished"
fi

invoke_template_step "DWD" "10_dwd_daily.sql.tpl" "10_dwd_daily.sql"
invoke_template_step "DWS" "20_dws_daily.sql.tpl" "20_dws_daily.sql"
invoke_template_step "ADS" "30_ads_daily.sql.tpl" "30_ads_daily.sql"
invoke_quality_checks

log_info "Pipeline finished successfully for ${RUN_DT}"
echo "Validate with:"
echo "SELECT * FROM hive_demo.ads_daily_overview_dp WHERE dt = '${RUN_DT}';"
echo "Log file: ${LOG_FILE}"
