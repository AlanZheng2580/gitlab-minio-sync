#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
load_env

MC=(docker run --rm --network gitlab-minio-sync-poc --entrypoint /bin/sh "$MINIO_MC_IMAGE" -c)
mc_cmd="mc alias set local http://minio:9000 '$MINIO_ROOT_USER' '$MINIO_ROOT_PASSWORD' >/dev/null"
"${MC[@]}" "$mc_cmd && mc mb --ignore-existing 'local/$MINIO_BUCKET' >/dev/null"

policy_file=$(mktemp "$STATE_DIR/minio-policy.XXXXXX")
trap 'rm -f "$policy_file"' EXIT
cat >"$policy_file" <<POLICY
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["s3:GetBucketLocation","s3:ListBucket"],"Resource":["arn:aws:s3:::$MINIO_BUCKET"]},{"Effect":"Allow","Action":["s3:GetObject","s3:PutObject"],"Resource":["arn:aws:s3:::$MINIO_BUCKET/*"]}]}
POLICY
docker run --rm --network gitlab-minio-sync-poc \
  -v "$policy_file:/tmp/policy.json:ro" --entrypoint /bin/sh "$MINIO_MC_IMAGE" -c \
  "$mc_cmd && (mc admin user info local '$MINIO_CI_ACCESS_KEY' >/dev/null 2>&1 || mc admin user add local '$MINIO_CI_ACCESS_KEY' '$MINIO_CI_SECRET_KEY' >/dev/null) && (mc admin policy info local config-sync-ci >/dev/null 2>&1 || mc admin policy create local config-sync-ci /tmp/policy.json >/dev/null) && mc admin policy attach local config-sync-ci --user '$MINIO_CI_ACCESS_KEY' >/dev/null"
log "MinIO bucket and least-privilege CI user configured"
