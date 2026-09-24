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

### Recommended variable settings

| Variables | Type | Visibility | Protect variable | Expand variable reference |
|---|---|---|---|---|
| `_MINIOSYNC_CONF_MINIO_SYNC_PAT` | Variable | Masked and hidden | Yes | No |
| `*_MINIO_*_PASSWORD` | Variable | Masked and hidden | Yes | No |
| `*_MINIO_*_USERNAME` | Variable | Visible (or Masked if required by policy) | Yes | No |

Apply these settings as follows:

- Use **Masked and hidden** for the Git credential and passwords. Masking
  replaces an exact secret value in job logs with `[MASKED]`; hiding also
  prevents the saved value from being revealed again in the GitLab UI.
- Existing variables cannot be changed from Masked to Hidden. Delete and
  recreate them with **Masked and hidden** if hiding is required. Copy the
  value from its authoritative password manager first because GitLab cannot
  reveal a hidden value after it is saved.
- A masked value must meet GitLab's requirements, including being a single
  line with no spaces and at least eight characters long.
- Usernames are normally identifiers rather than secrets, so keeping them
  Visible makes connection diagnostics easier. Select Masked instead if local
  policy considers account names sensitive. The template intentionally never
  prints tokens or passwords.
- Enable **Protect variable** only after protecting the consumer branch at
  **Settings > Repository > Protected branches**. In this example `main` is the
  test, staging, and production branch, so it must be protected. A trigger or
  manually started pipeline does not bypass this rule. If the ref is not
  protected, protected variables are absent and the job fails its required
  variable check.
- Disable **Expand variable reference** for every credential. Secrets are
  literal strings and do not need `$OTHER_VARIABLE` expansion; disabling it
  also prevents a `$` in a password or token from being interpreted as a
  reference. GitLab does not allow reference expansion for Masked or Masked
  and hidden variables in this version.
- Keep Environment scope as `*` for this example. The jobs do not currently
  declare GitLab `environment:` names, so environment-scoped credentials would
  require corresponding pipeline changes.

`Masked`, `Hidden`, and `Protected` reduce accidental exposure but do not stop
malicious CI code from sending a credential elsewhere. Review all template and
consumer CI changes before running them, and do not enable debug tracing while
handling secrets.

Never commit credential values. A personal access token with only
`read_repository` works for the PoC, but a read-only Group Deploy Token is
preferred for production because it is not tied to a person. Use separate
MinIO credentials for test, staging, and production outside this local PoC.

Group variables are inherited by eligible projects below the group. Keep them
at the `EPS` group only when all those projects are trusted and need the same
credentials. If only `minio-sync-example-repo` needs them, project-level
variables provide a smaller exposure scope.

For the exact behavior and current restrictions, see GitLab's documentation
for [CI/CD variables](https://docs.gitlab.com/ci/variables/) and
[token security](https://docs.gitlab.com/security/tokens/).

## Pipeline behavior

The template creates four sequential jobs:

```text
build_artifact → publish_tst → publish_stg → publish_prd
```

`build_artifact` is added only when the current branch matches at least one of
`TEST_BRANCH`, `STAGING_BRANCH`, or `PROD_BRANCH` whose corresponding MinIO
bucket is configured. Pipelines for unrelated branches therefore do not clone
repositories or create an unused archive. If multiple environments use the
same branch, the artifact is built once and reused by all matching publish
jobs.

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
