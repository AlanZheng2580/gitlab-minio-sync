# Repository instructions

## Purpose

This repository is a local Docker Compose proof of concept that synchronizes
multiple private GitLab configuration repositories into one MinIO archive by
using a reusable GitLab CI/CD Component.

Read `README.md` before changing the environment or workflow. It documents the
architecture, credentials, manual webhook setup, demo, and known limitations.

## Current scope

- There is one `demo-sync/sync-repo` consumer pipeline.
- All three configured webhooks trigger that same pipeline.
- Every non-superseded run clones A-config/master, B-config/release, and
  C-config/develop, then uploads one object at
  `config-packages/demo/configs.tar.gz`.
- There is one resource group named `config-sync`. Do not infer selectable
  groups, group-specific archives, or dispatch variables unless the user
  explicitly requests a new design.

## Important constraints

- Keep all container image versions pinned and centralized in `.env.example`.
- Never commit `.env`, `.state/`, passwords, access tokens, or trigger tokens.
- The consumer repository must only include the component and provide inputs.
  Clone, archive, MinIO upload, and batching logic belong in
  `repositories/ci-components/templates/config-sync.yml`.
- Config repositories are private. Pipeline cloning must continue to use a
  read-only `demo-configs` Group Deploy Token with `read_repository` scope.
- Pipeline API checks must use the scoped `SYNC_API_TOKEN`; never expose the
  bootstrap root token to CI.
- Keep MinIO CI permissions limited to the `config-packages` bucket.
- Do not automate config repository webhooks. Bootstrap should only print the
  URL and branch-filter instructions.
- Do not invent a GitLab YAML key for resource-group process mode. Bootstrap
  configures `newest_first` through the GitLab API.
- Jobs superseded by a newer trigger may exit successfully only before clone,
  archive, and upload. All real synchronization errors must fail the pipeline.

## Repository map

- `docker-compose.yml`: GitLab CE, Docker Runner, and MinIO services.
- `repositories/ci-components/`: reusable `config-sync` component seed.
- `repositories/{A,B,C}-config/`: private demo config repository seeds.
- `repositories/sync-repo/`: minimal component consumer seed.
- `scripts/bootstrap.sh`: complete idempotent environment bootstrap.
- `scripts/demo.sh`: Demo 1, Demo 2, and batch/debounce integration test.
- `scripts/verify.sh`: verifies the current MinIO archive.
- `.state/`: ignored local credentials and runtime IDs; never print contents.

## Validation

Run static checks after changes:

```bash
for script in scripts/*.sh; do bash -n "$script"; done
docker compose --env-file .env.example config --quiet
git diff --check
```

When Docker is available, run the relevant integration checks:

```bash
make up
make bootstrap
make demo
make verify
```

The full demo is expected to verify versions `1/1/1`, then `2/1/1`, then
`4/2/2`, and find at least one superseded pipeline job that logged a skip.

## Current handoff state

As of 2026-09-14, `develop`, `master`, and their remote-tracking branches point
to the same baseline commit. The worktree was clean at handoff. The earlier
multi-group experiment was fully removed and must not be treated as current
project scope.

Compose validation, bootstrap, all three demos, MinIO archive verification,
private repository cloning, `newest_first`, and superseded-job skip verification
passed in the local integration environment. The webhook endpoint uses Docker
DNS (`http://gitlab:8929`), and webhook URL masking instructions are documented
in `README.md`.

Runtime state is not represented by Git alone. Existing containers, named
volumes, manually configured webhooks, and ignored `.state/` credentials may
still exist. Before making changes, inspect:

```bash
git status --short
docker compose ps
```

Never print or commit the contents of `.env`, `.state/`, webhook URLs containing
real tokens, or GitLab CI/CD secret variables.
