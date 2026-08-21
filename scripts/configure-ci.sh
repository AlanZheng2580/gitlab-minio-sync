#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
load_env
ADMIN_TOKEN=$(<"$STATE_DIR/admin-token")
SYNC_PROJECT_ID=$(project_id demo-sync/sync-repo)
CONFIG_GROUP_ID=$(api GET "/api/v4/groups/$(urlencode demo-configs)" | jq -er .id)

if [ ! -s "$STATE_DIR/config-deploy-token.json" ]; then
  api POST "/api/v4/groups/$CONFIG_GROUP_ID/deploy_tokens" \
    --data-urlencode 'name=config-sync-readonly' \
    --data-urlencode 'scopes[]=read_repository' >"$STATE_DIR/config-deploy-token.json"
  chmod 600 "$STATE_DIR/config-deploy-token.json"
fi
CONFIG_GIT_USERNAME=$(jq -er .username "$STATE_DIR/config-deploy-token.json")
CONFIG_GIT_TOKEN=$(jq -er .token "$STATE_DIR/config-deploy-token.json")

if [ ! -s "$STATE_DIR/sync-api-token" ]; then
  expires_at=$(date -u -d '+364 days' +%F)
  token_json=$(api POST "/api/v4/projects/$SYNC_PROJECT_ID/access_tokens" \
    --data-urlencode 'name=config-sync-read-api' \
    --data-urlencode 'access_level=20' \
    --data-urlencode 'scopes[]=read_api' \
    --data-urlencode "expires_at=$expires_at")
  jq -er .token <<<"$token_json" >"$STATE_DIR/sync-api-token"
  chmod 600 "$STATE_DIR/sync-api-token"
fi
SYNC_API_TOKEN=$(<"$STATE_DIR/sync-api-token")

put_variable() {
  local key=$1 value=$2 masked=${3:-false}
  log "Configure CI variable: $key (masked=$masked)"
  if api GET "/api/v4/projects/$SYNC_PROJECT_ID/variables/$key" >/dev/null 2>&1; then
    api PUT "/api/v4/projects/$SYNC_PROJECT_ID/variables/$key" \
      --data-urlencode "value=$value" --data-urlencode "masked=$masked" \
      --data-urlencode 'protected=false' --data-urlencode 'raw=true' >/dev/null
  else
    api POST "/api/v4/projects/$SYNC_PROJECT_ID/variables" \
      --data-urlencode "key=$key" --data-urlencode "value=$value" \
      --data-urlencode "masked=$masked" --data-urlencode 'protected=false' \
      --data-urlencode 'raw=true' >/dev/null
  fi
}
put_variable CONFIG_GIT_USERNAME "$CONFIG_GIT_USERNAME" false
put_variable CONFIG_GIT_TOKEN "$CONFIG_GIT_TOKEN" true
put_variable CONFIG_GITLAB_URL "$GITLAB_INTERNAL_URL" false
put_variable MINIO_ENDPOINT 'http://minio:9000' false
put_variable MINIO_ACCESS_KEY "$MINIO_CI_ACCESS_KEY" true
put_variable MINIO_SECRET_KEY "$MINIO_CI_SECRET_KEY" true
put_variable SYNC_API_TOKEN "$SYNC_API_TOKEN" true

if [ ! -s "$STATE_DIR/trigger.json" ]; then
  api POST "/api/v4/projects/$SYNC_PROJECT_ID/triggers" \
    --data-urlencode 'description=config-repository-webhooks' >"$STATE_DIR/trigger.json"
  chmod 600 "$STATE_DIR/trigger.json"
fi
TRIGGER_TOKEN=$(jq -er .token "$STATE_DIR/trigger.json")
cat >"$STATE_DIR/runtime.env" <<EOF
SYNC_REPO_PROJECT_ID=$SYNC_PROJECT_ID
TRIGGER_TOKEN=$TRIGGER_TOKEN
EOF
chmod 600 "$STATE_DIR/runtime.env"
log "Scoped Git and API tokens, CI variables and pipeline trigger configured"
