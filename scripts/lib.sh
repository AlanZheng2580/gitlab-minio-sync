#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
STATE_DIR="$ROOT_DIR/.state"
mkdir -p "$STATE_DIR"

load_env() {
  [ -f "$ROOT_DIR/.env" ] || { echo "Missing .env; run: cp .env.example .env" >&2; exit 1; }
  set -a
  # shellcheck disable=SC1091
  source "$ROOT_DIR/.env"
  set +a
}

log() { printf '[poc] %s\n' "$*"; }
die() { log "ERROR: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null || die "Required command not found: $1"; }

api() {
  local method=$1 path=$2; shift 2
  curl --fail --silent --show-error --request "$method" \
    --header "PRIVATE-TOKEN: ${ADMIN_TOKEN:?}" "$@" "${GITLAB_EXTERNAL_URL}${path}"
}

urlencode() { jq -rn --arg v "$1" '$v|@uri'; }

project_id() {
  api GET "/api/v4/projects/$(urlencode "$1")" | jq -er .id
}

wait_pipeline() {
  local pipeline_id=$1 deadline=$((SECONDS + 900)) status
  while (( SECONDS < deadline )); do
    status=$(api GET "/api/v4/projects/${SYNC_REPO_PROJECT_ID:?}/pipelines/${pipeline_id}" | jq -r .status)
    log "Pipeline $pipeline_id: $status"
    case "$status" in
      success) return 0 ;;
      failed|canceled|skipped|manual) return 1 ;;
    esac
    sleep 5
  done
  die "Timed out waiting for pipeline $pipeline_id"
}
