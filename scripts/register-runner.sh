#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
load_env
ADMIN_TOKEN=$(<"$STATE_DIR/admin-token")

configure_clone_url() {
  docker compose -f "$ROOT_DIR/docker-compose.yml" exec -T gitlab-runner \
    sh -c '
      set -eu
      config=/etc/gitlab-runner/config.toml
      clone_url=$1
      if grep -q "^  clone_url = " "$config"; then
        sed -i "s|^  clone_url = .*|  clone_url = \"${clone_url}\"|" "$config"
      else
        sed -i "/^  url = /a\\  clone_url = \"${clone_url}\"" "$config"
      fi
    ' _ "$GITLAB_INTERNAL_URL"
}

if docker compose -f "$ROOT_DIR/docker-compose.yml" exec -T gitlab-runner gitlab-runner list 2>&1 | grep -q 'poc-docker-runner'; then
  configure_clone_url
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
  --clone-url "$GITLAB_INTERNAL_URL" \
  --executor docker --docker-image "$ALPINE_IMAGE" \
  --docker-network-mode gitlab-minio-sync-poc \
  --description poc-docker-runner
configure_clone_url
log "Docker executor Runner registered"
