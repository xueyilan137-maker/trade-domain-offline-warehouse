#!/usr/bin/env bash

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
  SPARK_SQL_OUTPUT=""

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

  SPARK_SQL_OUTPUT="${output}"
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

invoke_check_template() {
  local check_name="$1"
  local template_name="$2"
  local output_name="$3"
  local check_sql=""

  log_info "Starting ${check_name} step for ${RUN_DT}"
  check_sql="$(new_sql_from_template "${SQL_DIR}/${template_name}" "${output_name}")"
  invoke_spark_sql_file "${check_sql}" "${output_name}"

  if echo "${SPARK_SQL_OUTPUT}" | grep -q 'check failed'; then
    log_error "${check_name} failed for ${RUN_DT}. Check log: ${LOG_FILE}"
    return 1
  fi

  log_info "${check_name} passed for ${RUN_DT}"
}
