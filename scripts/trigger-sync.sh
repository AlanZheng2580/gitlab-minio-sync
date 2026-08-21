#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
load_env
# shellcheck disable=SC1091
source "$STATE_DIR/runtime.env"
response=$(curl --fail --silent --show-error --request POST \
  --form "token=$TRIGGER_TOKEN" --form 'ref=main' \
  "$GITLAB_EXTERNAL_URL/api/v4/projects/$SYNC_REPO_PROJECT_ID/trigger/pipeline")
jq -er .id <<<"$response"
