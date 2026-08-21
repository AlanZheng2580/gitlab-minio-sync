#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
load_env
ADMIN_TOKEN=$(<"$STATE_DIR/admin-token")
# shellcheck disable=SC1091
source "$STATE_DIR/runtime.env"

log "Demo 1: reset all repositories to version 1 and perform first sync"
"$SCRIPT_DIR/update-config.sh" A 1
"$SCRIPT_DIR/update-config.sh" B 1
"$SCRIPT_DIR/update-config.sh" C 1
p1=$("$SCRIPT_DIR/trigger-sync.sh")
wait_pipeline "$p1" || die "Demo 1 pipeline failed"
"$SCRIPT_DIR/verify.sh" 1 1 1

log "Demo 2: update A-config to version 2"
"$SCRIPT_DIR/update-config.sh" A 2
p2=$("$SCRIPT_DIR/trigger-sync.sh")
wait_pipeline "$p2" || die "Demo 2 pipeline failed"
"$SCRIPT_DIR/verify.sh" 2 1 1

log "Demo 3: rapidly update and trigger A/B/C/A"
batch_ids=()
"$SCRIPT_DIR/update-config.sh" A 3; batch_ids+=("$("$SCRIPT_DIR/trigger-sync.sh")")
"$SCRIPT_DIR/update-config.sh" B 2; batch_ids+=("$("$SCRIPT_DIR/trigger-sync.sh")")
"$SCRIPT_DIR/update-config.sh" C 2; batch_ids+=("$("$SCRIPT_DIR/trigger-sync.sh")")
"$SCRIPT_DIR/update-config.sh" A 4; batch_ids+=("$("$SCRIPT_DIR/trigger-sync.sh")")
for pipeline_id in "${batch_ids[@]}"; do
  wait_pipeline "$pipeline_id" || die "Batch pipeline $pipeline_id failed"
done
"$SCRIPT_DIR/verify.sh" 4 2 2

skip_count=0
for pipeline_id in "${batch_ids[@]}"; do
  job_id=$(api GET "/api/v4/projects/$SYNC_REPO_PROJECT_ID/pipelines/$pipeline_id/jobs" | jq -r '.[0].id // empty')
  [ -n "$job_id" ] || continue
  if api GET "/api/v4/projects/$SYNC_REPO_PROJECT_ID/jobs/$job_id/trace" | grep -q 'Newer sync pipeline exists'; then
    skip_count=$((skip_count + 1))
  fi
done
[ "$skip_count" -gt 0 ] || die "Batch completed but no superseded job logged a skip"
log "PASS: Demo 1, Demo 2 and Demo 3; $skip_count superseded batch pipeline(s) skipped expensive work"
