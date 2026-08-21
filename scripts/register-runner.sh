#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
load_env
ADMIN_TOKEN=$(<"$STATE_DIR/admin-token")

if docker compose -f "$ROOT_DIR/docker-compose.yml" exec -T gitlab-runner gitlab-runner list 2>&1 | grep -q 'poc-docker-runner'; then
  log "Runner already registered"
  exit 0
fi
runner_json=$(api POST /api/v4/user/runners \
  --data-urlencode 'runner_type=instance_type' \
  --data-urlencode 'description=poc-docker-runner' \
  --data-urlencode 'tag_list=docker' \
  --data-urlencode 'run_untagged=true')
runner_token=$(jq -er .token <<<"$runner_json")
docker compose -f "$ROOT_DIR/docker-compose.yml" exec -T gitlab-runner gitlab-runner register \
  --non-interactive --url "$GITLAB_INTERNAL_URL" --token "$runner_token" \
  --executor docker --docker-image "$ALPINE_IMAGE" \
  --docker-network-mode gitlab-minio-sync-poc \
  --description poc-docker-runner
log "Docker executor Runner registered"
