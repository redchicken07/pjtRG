#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOCK_DIR="${SCRIPT_DIR}/.sync_ranks.lock"
LOG_DIR="${PROJECT_DIR}/logs"
LOG_FILE="${LOG_DIR}/sync_ranks_$(date '+%Y%m%d').log"
ENV_FILE="${SCRIPT_DIR}/.env.sync_ranks"

timestamp() {
  date '+%Y-%m-%d %H:%M:%S%z'
}

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
fi

mkdir -p "${LOG_DIR}"

if ! mkdir "${LOCK_DIR}" 2>/dev/null; then
  echo "[$(timestamp)] skip: sync_ranks is already running"
  exit 0
fi

cleanup() {
  rmdir "${LOCK_DIR}" 2>/dev/null || true
}
trap cleanup EXIT

status=0
{
  echo "[$(timestamp)] start sync:ranks"
  if npm --prefix "${SCRIPT_DIR}" run sync:ranks; then
    echo "[$(timestamp)] completed sync:ranks"
  else
    status=$?
    echo "[$(timestamp)] failed sync:ranks (exit=${status})"
  fi
} >>"${LOG_FILE}" 2>&1

exit "${status}"
