#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
load_env
"$SCRIPT_DIR/wait-gitlab.sh"

if [ ! -s "$STATE_DIR/admin-token" ]; then
  token="glpat-$(openssl rand -hex 20)"
  expires_at=$(date -u -d '+364 days' +%F)
  rails="u=User.find_by_username('root'); t=u.personal_access_tokens.find_or_initialize_by(name:'poc-bootstrap'); t.scopes=['api']; t.expires_at=Date.parse('$expires_at'); t.set_token('$token'); t.save!; puts t.token"
  docker compose -f "$ROOT_DIR/docker-compose.yml" exec -T gitlab gitlab-rails runner "$rails" | tail -n1 >"$STATE_DIR/admin-token"
  chmod 600 "$STATE_DIR/admin-token"
fi
ADMIN_TOKEN=$(<"$STATE_DIR/admin-token")
api GET /api/v4/user | jq -e '.username == "root"' >/dev/null || die "Bootstrap admin token is invalid"
"$SCRIPT_DIR/create-projects.sh"
"$SCRIPT_DIR/register-runner.sh"
"$SCRIPT_DIR/configure-ci.sh"
log "GitLab bootstrap complete"
