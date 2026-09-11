#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
load_env
need curl; need jq; need git; need docker; need openssl
"$SCRIPT_DIR/wait-gitlab.sh"
"$SCRIPT_DIR/bootstrap-minio.sh"
"$SCRIPT_DIR/bootstrap-gitlab.sh"

ADMIN_TOKEN=$(<"$STATE_DIR/admin-token")
# shellcheck disable=SC1091
source "$STATE_DIR/runtime.env"
initial_pipeline=$("$SCRIPT_DIR/trigger-sync.sh")
log "Initial pipeline created: $initial_pipeline"
for _ in $(seq 1 60); do
  if api PUT "/api/v4/projects/$SYNC_REPO_PROJECT_ID/resource_groups/config-sync" \
    --data-urlencode 'process_mode=newest_first' >/dev/null 2>&1; then
    log "Resource group process mode set to newest_first"
    break
  fi
  sleep 2
done
mode=$(api GET "/api/v4/projects/$SYNC_REPO_PROJECT_ID/resource_groups/config-sync" | jq -er .process_mode) || die "Resource group was not created"
[ "$mode" = newest_first ] || die "Resource group process_mode is $mode, expected newest_first"

# Webhooks are delivered by the GitLab container. Use Docker DNS instead of
# localhost, which would resolve to the container loopback (often ::1).
webhook="$GITLAB_INTERNAL_URL/api/v4/projects/$SYNC_REPO_PROJECT_ID/ref/main/trigger/pipeline?token=$TRIGGER_TOKEN"
cat <<EOF

Bootstrap complete.
SYNC_REPO_PROJECT_ID=$SYNC_REPO_PROJECT_ID
TRIGGER_TOKEN=$TRIGGER_TOKEN

A-config
Push event
Branch filter: master
Webhook URL: $webhook

B-config
Push event
Branch filter: release
Webhook URL: $webhook

C-config
Push event
Branch filter: develop
Webhook URL: $webhook
EOF
