#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
load_env
ADMIN_TOKEN=$(<"$STATE_DIR/admin-token")
[ "$#" = 2 ] || die "Usage: update-config.sh A|B|C VERSION"
name=$1 version=$2
[[ "$version" =~ ^[0-9]+$ ]] || die "VERSION must be numeric"
case "$name" in
  A) repo=A-config; branch=master; file=a.yaml ;;
  B) repo=B-config; branch=release; file=b.yaml ;;
  C) repo=C-config; branch=develop; file=c.yaml ;;
  *) die "Repository must be A, B or C" ;;
esac
work=$(mktemp -d "$STATE_DIR/update.XXXXXX")
trap 'rm -rf "$work"' EXIT
git clone -q --branch "$branch" "http://oauth2:${ADMIN_TOKEN}@localhost:8929/demo-configs/$repo.git" "$work/repo"
sed -i -E "s/^version: .*/version: $version/" "$work/repo/configs/$file"
git -C "$work/repo" config user.name 'PoC Demo'
git -C "$work/repo" config user.email 'poc@example.invalid'
if git -C "$work/repo" diff --quiet; then
  log "$repo is already version $version"
else
  git -C "$work/repo" add "configs/$file"
  git -C "$work/repo" commit -q -m "Set $name version $version"
  git -C "$work/repo" push -q -o ci.skip origin "$branch"
  log "Updated $repo/$branch to version $version"
fi
