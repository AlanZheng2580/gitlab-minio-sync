#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
load_env
deadline=$((SECONDS + 900))
until curl --fail --silent --output /dev/null "$GITLAB_EXTERNAL_URL/users/sign_in"; do
  (( SECONDS < deadline )) || die "GitLab did not become ready within 15 minutes"
  log "Waiting for GitLab..."
  sleep 10
done
log "GitLab is ready"
