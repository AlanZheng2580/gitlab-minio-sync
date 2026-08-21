#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
load_env
ADMIN_TOKEN=$(<"$STATE_DIR/admin-token")

ensure_group() {
  local name=$1 path=$2
  api GET "/api/v4/groups/$(urlencode "$path")" >/dev/null 2>&1 || \
    api POST /api/v4/groups --data-urlencode "name=$name" --data-urlencode "path=$path" >/dev/null
}
ensure_project() {
  local namespace=$1 name=$2 branch=$3 gid
  gid=$(api GET "/api/v4/groups/$(urlencode "$namespace")" | jq -er .id)
  api GET "/api/v4/projects/$(urlencode "$namespace/$name")" >/dev/null 2>&1 || \
    api POST /api/v4/projects --data-urlencode "namespace_id=$gid" --data-urlencode "name=$name" \
      --data-urlencode "path=$name" --data-urlencode 'visibility=private' \
      --data-urlencode "default_branch=$branch" --data-urlencode 'initialize_with_readme=false' >/dev/null
}
push_seed() {
  local namespace=$1 name=$2 branch=$3 source=$4 repo_dir
  repo_dir=$(mktemp -d "$STATE_DIR/seed.XXXXXX")
  cp -a "$source/." "$repo_dir/"
  git -C "$repo_dir" init -q
  git -C "$repo_dir" checkout -q -b "$branch"
  git -C "$repo_dir" config user.name 'PoC Bootstrap'
  git -C "$repo_dir" config user.email 'poc@example.invalid'
  git -C "$repo_dir" add .
  git -C "$repo_dir" commit -q -m 'Initial PoC content'
  git -C "$repo_dir" remote add origin "http://oauth2:${ADMIN_TOKEN}@localhost:8929/$namespace/$name.git"
  if ! git ls-remote --exit-code "http://oauth2:${ADMIN_TOKEN}@localhost:8929/$namespace/$name.git" "refs/heads/$branch" >/dev/null 2>&1; then
    git -C "$repo_dir" push -q -o ci.skip origin "$branch"
  fi
  rm -rf "$repo_dir"
}

ensure_group Platform platform
ensure_group 'Demo Configs' demo-configs
ensure_group 'Demo Sync' demo-sync
ensure_project platform ci-components main
ensure_project demo-configs A-config master
ensure_project demo-configs B-config release
ensure_project demo-configs C-config develop
ensure_project demo-sync sync-repo main

push_seed platform ci-components main "$ROOT_DIR/repositories/ci-components"
push_seed demo-configs A-config master "$ROOT_DIR/repositories/A-config"
push_seed demo-configs B-config release "$ROOT_DIR/repositories/B-config"
push_seed demo-configs C-config develop "$ROOT_DIR/repositories/C-config"
push_seed demo-sync sync-repo main "$ROOT_DIR/repositories/sync-repo"

component_id=$(project_id platform/ci-components)
tag_exists=$(api GET "/api/v4/projects/$component_id/repository/tags/1.0.0" >/dev/null 2>&1 && echo yes || echo no)
if [ "$tag_exists" = no ]; then
  api POST "/api/v4/projects/$component_id/repository/tags" --data-urlencode 'tag_name=1.0.0' --data-urlencode 'ref=main' >/dev/null
fi
api GET "/api/v4/projects/$component_id/releases/1.0.0" >/dev/null 2>&1 || \
  api POST "/api/v4/projects/$component_id/releases" --data-urlencode 'name=config-sync 1.0.0' --data-urlencode 'tag_name=1.0.0' >/dev/null
log "Groups, private projects, branches and component 1.0.0 created"
