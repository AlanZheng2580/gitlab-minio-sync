# EPS MinIO Sync Example

This directory contains two repository examples that are maintained separately
in GitLab:

- `template-pipeline`: shared `publish-to-minio.yml` CI template.
- `minio-sync-example-repo`: consumer pipeline and repository list.

The local files are reference copies. After changing them here, update the
corresponding files in the GitLab projects on the branch referenced by the
consumer include (`main` in this example).

## GitLab projects and files

```text
EPS/template-pipeline
└── templates/publish-to-minio.yml

EPS/minio-sync-example-repo
├── .gitlab-ci.yml
└── build/repo-config.yaml
```

The consumer includes the template using:

```yaml
include:
  - project: EPS/template-pipeline
    ref: main
    file: /templates/publish-to-minio.yml
```

## Required group variables

Define these variables on the `EPS` group:

| Variable | Purpose |
|---|---|
| `_MINIOSYNC_CONF_MINIO_SYNC_PAT` | Read-only Git credential used to clone repositories listed in `repo-config.yaml` |
| `_MINIOSYNC_CONF_MINIO_TST_USERNAME` | Test MinIO username |
| `_MINIOSYNC_CONF_MINIO_TST_PASSWORD` | Test MinIO password |
| `_MINIOSYNC_CONF_MINIO_STG_USERNAME` | Staging MinIO username |
| `_MINIOSYNC_CONF_MINIO_STG_PASSWORD` | Staging MinIO password |
| `_MINIOSYNC_CONF_MINIO_PRD_USERNAME` | Production MinIO username |
| `_MINIOSYNC_CONF_MINIO_PRD_PASSWORD` | Production MinIO password |

Set PAT and password variables to **Masked** and disable variable expansion.
If they are **Protected**, the pipeline branch must also be protected. Never
commit their values. A personal access token with `read_repository` works for
the PoC; a read-only Group Deploy Token is preferred for production because it
is not tied to a person.

## Pipeline behavior

The template creates four sequential jobs:

```text
build_artifact → publish_tst → publish_stg → publish_prd
```

`build_artifact` reads `build/repo-config.yaml`, clones every configured branch,
removes `.git`, and creates `_output/drop.tar.gz`. Publish jobs upload the same
artifact to environment-specific prefixes, update `LATEST`, and retain the
newest `MINIO_REVS_TO_KEEP` archives.

The revision filename uses the pipeline ID so repeated syncs of an unchanged
consumer commit still create distinct revisions:

```text
<CI_PIPELINE_ID>-<CI_COMMIT_SHORT_SHA>.tar.gz
```

For this local PoC, all environments use the same endpoint, bucket, and MinIO
credential but different prefixes:

```text
config-packages/builds-gitlab-test/minio-sync-example-repo/
config-packages/builds-gitlab-staging/minio-sync-example-repo/
config-packages/builds-gitlab-prod/minio-sync-example-repo/
```

Each prefix should contain `LATEST` and up to three `.tar.gz` revisions.

## Runner and tools

The template defaults to Runner tag `docker` and image `ubuntu:24.04`. Override
`MINIO_SYNC_RUNNER_TAG` when deploying to runners with different tags.

The first job downloads pinned yq and MinIO Client binaries into the GitLab
Runner cache. Later jobs reuse that cache. Current versions are defined in the
template as `YQ_VERSION` and `MC_RELEASE`. A prebuilt, pinned CI tools image is
recommended for production to remove runtime downloads and reduce startup time.

## Fixes included in this version

- Nested `artifacts` under `build_artifact`; a top-level `artifacts` key was
  incorrectly interpreted by GitLab as a job without `script`.
- Corrected `MINIO_REVS_TO_KEEP`, production spelling, repository URLs, and the
  B/C repository names and branches.
- Added explicit Ubuntu image, matching Runner tag, and pinned tools.
- Passes the Git PAT through an HTTP authorization header instead of embedding
  it in the clone URL.
- Validates required variables and repository configuration, excludes `.git`,
  uses unique revision names, and correctly removes revisions beyond retention.
- Removed `--insecure`; production endpoints should use trusted HTTPS.

## Validation and test

The local merged template and consumer configuration has passed GitLab 17.11
CI Lint, YAML parsing, embedded Bash syntax checking, and whitespace checking.

After updating both GitLab projects, run a new pipeline on `main`. Verify:

1. Pipeline creation succeeds without the `jobs artifacts config` error.
2. All four jobs run on the expected Docker Runner.
3. `build_artifact` clones A/master, B/release, and C/develop.
4. Each publish job uploads its archive and `LATEST` file.
5. MinIO contains the three environment prefixes listed above.

If a job remains pending, compare its tag with `MINIO_SYNC_RUNNER_TAG`. If a
protected variable is missing in the job, verify that `main` is protected and
that the group variable environment scope includes this project.

If the job fails during **Getting source from Git repository** with a URL such
as `http://localhost:8929/...`, the failure happens before this template runs.
The Runner's `/etc/gitlab-runner/config.toml` must contain the internal Docker
network URL in its runner block:

```toml
url = "http://gitlab:8929"
clone_url = "http://gitlab:8929"
```

Run `./scripts/register-runner.sh` from the PoC workspace to apply this setting
idempotently. The public browser URL remains `http://localhost:8929`; only
Runner and job containers use the `gitlab` Docker DNS hostname.
