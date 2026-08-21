#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
load_env
need docker
docker compose -f "$ROOT_DIR/docker-compose.yml" config --quiet
log "Starting GitLab, Runner and MinIO (first GitLab start can take 5-10 minutes)"
docker compose -f "$ROOT_DIR/docker-compose.yml" up -d
"$SCRIPT_DIR/wait-gitlab.sh"
