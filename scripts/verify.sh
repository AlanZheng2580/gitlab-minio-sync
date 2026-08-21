#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
load_env

expected_a=${1:-}
expected_b=${2:-}
expected_c=${3:-}
work=$(mktemp -d "$STATE_DIR/verify.XXXXXX")
trap 'rm -rf "$work"' EXIT
docker run --rm --network gitlab-minio-sync-poc -v "$work:/downloads" \
  --entrypoint /bin/sh "$MINIO_MC_IMAGE" -c \
  "mc alias set local http://minio:9000 '$MINIO_ROOT_USER' '$MINIO_ROOT_PASSWORD' >/dev/null && mc cp 'local/$MINIO_BUCKET/demo/configs.tar.gz' /downloads/configs.tar.gz >/dev/null"
tar -tzf "$work/configs.tar.gz" >"$work/list.txt"
for path in A-config/configs/a.yaml B-config/configs/b.yaml C-config/configs/c.yaml; do
  grep -Eq "^(\./)?$path$" "$work/list.txt" || die "Archive is missing $path"
done
if grep -Eq '(^|/)\.git(/|$)' "$work/list.txt"; then die "Archive contains .git metadata"; fi
tar -xzf "$work/configs.tar.gz" -C "$work"
check_version() {
  local repo=$1 file=$2 expected=$3 actual
  [ -n "$expected" ] || return 0
  actual=$(awk '$1=="version:" {print $2}' "$work/$repo/configs/$file")
  [ "$actual" = "$expected" ] || die "$repo version is $actual, expected $expected"
}
check_version A-config a.yaml "$expected_a"
check_version B-config b.yaml "$expected_b"
check_version C-config c.yaml "$expected_c"
log "PASS: MinIO archive structure, content versions and .git exclusion verified"
