# `.github/workflows/`

Workflow files for CI, release, and ops automation. This folder is the **single source of truth** for what runs in GitHub Actions for this repository.

## Naming convention

Every file follows `<stage>-<surface>.yml`:

- `stage` ∈ `pr | ci | release | ops`
- `surface` ∈ `rails | mobile | charts | preview | docs | security | llm | deps`

If you need a new workflow, decide the stage and surface first; the file name usually follows.

| Stage    | Trigger                                         | Purpose                                                |
| -------- | ----------------------------------------------- | ------------------------------------------------------ |
| `pr`     | `pull_request`                                  | Top-level orchestrator that fans out to `ci-*` and `ops-security` |
| `ci`     | `workflow_call` (reusable)                      | Single-source Rails / Flutter / chart checks           |
| `release`| `push` (tag or branch) / `schedule` / `dispatch`| Build artifacts and push to registries / stores        |
| `ops`    | mixed (`workflow_run`, `schedule`, `pull_request` from Dependabot) | Deployments, docs, security scans, dependency hygiene  |

## File catalog

| File                   | Stage   | Surface   | Triggers                                                                   |
| ---------------------- | ------- | --------- | -------------------------------------------------------------------------- |
| `pr.yml`               | `pr`    | `pr`      | `pull_request`                                                             |
| `ci-rails.yml`         | `ci`    | `rails`   | `workflow_call`                                                            |
| `ci-mobile.yml`        | `ci`    | `mobile`  | `workflow_call`                                                            |
| `ci-charts.yml`        | `ci`    | `charts`  | `workflow_call`                                                            |
| `release-rails.yml`    | `release` | `rails`  | `push` (main, `v*`), schedule, `workflow_dispatch`                         |
| `release-mobile.yml`   | `release` | `mobile` | `push` (`mobile-v*`), `workflow_dispatch`                                 |
| `release-charts.yml`   | `release` | `charts` | `push` (`chart-v*`), `workflow_dispatch`                                  |
| `ops-preview.yml`      | `ops`   | `preview` | `workflow_run` (PR), `schedule` (hourly cleanup)                          |
| `ops-docs.yml`         | `ops`   | `docs`    | `push` (main)                                                              |
| `ops-security.yml`     | `ops`   | `security`| `pull_request` (main)                                                     |
| `ops-deps.yml`         | `ops`   | `deps`    | `pull_request` (Dependabot)                                               |
| `ops-llm-evals.yml`    | `ops`   | `llm`     | `push` (`v*`), `workflow_dispatch`                                         |

## Old → new mapping

The previous (pre-`redo-github-workflows`) workflow set is fully retired. The mapping below is the authoritative reference when reading older issues, PR comments, or docs.

| Old file                       | New file                   | Notes                                                                 |
| ------------------------------ | -------------------------- | --------------------------------------------------------------------- |
| `ci.yml`                       | `ci-rails.yml`             | Reusable, called by `pr.yml` and `release-rails.yml`                  |
| `pr.yml`                       | `pr.yml`                   | Same name, simpler content (no `preview_image` job — that moved to `ops-preview.yml`) |
| `publish.yml`                  | `release-rails.yml`        | Multi-arch GHCR push only; release / version-bump logic retired       |
| `flutter-build.yml`            | `ci-mobile.yml` + `release-mobile.yml` | analyze/test in CI; AAB + unsigned iOS archive in release     |
| `mobile-ci.yml`                | `pr.yml` (path filter) + `ci-mobile.yml` |                                                      |
| `mobile-build.yml`             | `release-mobile.yml`       | Single canonical mobile build orchestrator                            |
| `mobile-release.yml`           | `release-mobile.yml`       |                                                                       |
| `ios-testflight.yml`           | _not re-created_           | No store credentials are configured; build only                      |
| `google-play-upload.yml`       | _not re-created_           | No store credentials are configured; build only                      |
| `chart-ci.yml`                 | `ci-charts.yml`            |                                                                       |
| `chart-release.yml`            | `release-charts.yml`       | OCI + `gh-pages` index on `chart-v*` tags                             |
| `helm-publish.yml`             | _folded into_ `release-charts.yml` |                                                       |
| `preview-deploy.yml`           | `ops-preview.yml`          |                                                                       |
| `preview-cleanup.yml`          | `ops-preview.yml`          | Hourly cleanup is a second `on:` block in the same file               |
| `pipelock.yml`                 | `ops-security.yml`         | Added `zizmor` and a `pipelock:ignore` audit step                     |
| `update-docs.yml`              | `ops-docs.yml`             | Calls the same Mintlify agent kickoff script                          |
| `llm-evals.yml`                | `ops-llm-evals.yml`        |                                                                       |
| _none_                         | `ops-deps.yml`             | New — Dependabot auto-merge                                           |

## Reusable composite action

`.github/actions/build-rails-image/` is the only composite action. It centralizes the multi-arch `docker buildx` invocation used by both `release-rails.yml` and `ops-preview.yml`. See [its README](../actions/build-rails-image/README.md) for the inputs/outputs contract.

## Extension guide

- "I want a new linter." → add a job to `ci-rails.yml`; PR it through `pr.yml`.
- "I want a new store upload." → add a publish job to `release-mobile.yml`; scope the credential to that one job.
- "I want a new scheduled task." → create `ops-<surface>.yml` with a `schedule:` trigger; do not put cron jobs in `release-*.yml`.
- "I want to add a new secret." → update `docs/ci/workflows.md` with the new secret name + which file uses it; never add secrets to PR-triggered workflows.
