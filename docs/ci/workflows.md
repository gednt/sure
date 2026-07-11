# CI workflows

This document is the user-facing catalog of the Sure GitHub Actions workflow set. Use it to find which file is responsible for what, and how to extend it.

For the per-folder conventions and the old→new mapping, see [`.github/workflows/README.md`](../../.github/workflows/README.md).

## Workflow catalog

| File                          | Trigger                                                            | Required secrets / vars                                                                                                                                         | Downstream consumers                                                            |
| ----------------------------- | ------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| `pr.yml`                      | `pull_request` (any non-chart change), `workflow_dispatch`         | —                                                                                                                                                                | calls `ci-rails`, `ci-mobile`, `ops-security`                                   |
| `ci-rails.yml`                | `workflow_call`                                                    | `PLAID_CLIENT_ID`, `PLAID_SECRET` (test fixtures only)                                                                                                          | called by `pr.yml`, `release-rails.yml`                                          |
| `ci-mobile.yml`               | `workflow_call`                                                    | —                                                                                                                                                                | called by `pr.yml`, `release-mobile.yml`                                         |
| `ci-charts.yml`               | `pull_request: paths: [charts/**]`, `push: paths: [charts/**]`, `workflow_call` | —                                                                                                                                                | called by `release-charts.yml`                                                   |
| `release-rails.yml`           | `push: main`/`v*`, `schedule`, `workflow_dispatch`                  | `GITHUB_TOKEN` (built-in, must have `packages: write`)                                                                                                          | builds and pushes multi-arch GHCR image                                          |
| `release-mobile.yml`          | `push: mobile-v*`, `workflow_dispatch`                              | optional: `KEYSTORE_BASE64`, `KEY_STORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS`                                                                                   | builds APK + AAB + unsigned iOS `.app`; uploads as artifacts                    |
| `release-charts.yml`          | `push: chart-v*`, `workflow_dispatch`                              | `GITHUB_TOKEN` (must have `contents: write` for gh-pages + `packages: write` for OCI)                                                                            | publishes OCI chart to GHCR + updates `gh-pages` Helm index                      |
| `ops-preview.yml`             | `workflow_run: [PR]`, `pull_request: closed/labeled`, `schedule` (hourly) | `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_API_TOKEN` or `CLOUDFLARE_PREVIEW_API_TOKEN`, `CLOUDFLARE_WORKERS_SUBDOMAIN`                                       | builds & deploys Cloudflare Container preview; cleanup on PR close / schedule    |
| `ops-docs.yml`                | `push: main`                                                       | `MINTLIFY_API_KEY`, `MINTLIFY_PROJECT_ID`                                                                                                                        | kicks off the Mintlify Agent job                                                |
| `ops-security.yml`            | `pull_request: main`                                               | —                                                                                                                                                                | runs `pipelock`, `brakeman`, `zizmor`, and a `pipelock:ignore` audit             |
| `ops-deps.yml`                | `pull_request` (Dependabot)                                       | —                                                                                                                                                                | enables auto-merge for patch/minor Dependabot PRs                               |
| `ops-llm-evals.yml`           | `push: v*`, `workflow_dispatch`                                    | `OPENAI_ACCESS_TOKEN`                                                                                                                                            | runs the LLM eval suite, posts results to a pinned issue                         |

## Extension guide

"Which file do I add?" — pick a stage, then a surface.

| I want to add…                                | Edit / create                                  |
| --------------------------------------------- | ---------------------------------------------- |
| A new linter or static check                  | Add a job to `ci-rails.yml` / `ci-mobile.yml`  |
| A new store upload (Play, TestFlight)         | Add a job to `release-mobile.yml`; scope the credential to that one job |
| A new chart                                    | Add it under `charts/` — both `ci-charts.yml` and `release-charts.yml` pick it up via their `chart-path` default |
| A new scheduled task                          | Create `ops-<surface>.yml` with a `schedule:` trigger; do not put cron jobs in `release-*.yml` |
| A new secret                                   | Add the secret at the repo or org level; reference it via `secrets.<NAME>` only in the workflow that needs it; document it in the table above |

## `pipelock:ignore` audit

`ops-security.yml` runs a `pipelock_ignore_audit` job that lists every `pipelock:ignore` directive in the repository and diffs it against the PR base. The output is appended to the job summary so reviewers see a clear "what changed" alongside the diff.

To add a new directive:

1. Add `# pipelock:ignore <reason>` to the same line as the false positive.
2. In the PR description, explain why the directive is justified.
3. The `ops-security` workflow will surface your addition in the job summary; the reviewer is responsible for signing off.

To remove a directive:

1. Delete the `# pipelock:ignore` comment.
2. Run the offending job locally to confirm it still passes.
3. Reference the local-run output in the PR description.

## Behavior preserved vs. retired

This change intentionally retires a few behaviors that were previously part of the workflow set. If you need any of these back, file a follow-up change — do not silently re-add them in a workflow file.

### Retired (no longer runs)

- **GitHub Release creation** for `v*` and `chart-v*` tags (previously in `publish.yml` and `chart-release.yml`).
- **Release branch sync** (`vX.Y-release-branch` creation/update on stable tag pushes) (previously in `publish.yml`).
- **Pre-release version bump** after an `alpha`/`beta`/`rc` tag (bumping `.sure-version` and `charts/sure/Chart.yaml`, with direct-push or PR fallback) (previously in `publish.yml`).
- **Hardened Cloudflare deploy hardening** — `wrangler delete --force` retry on stale durable-object state, the ~100-poll `/ _container_status` readiness loop with measured-budget rationale, the `redact_preview_log.sh` log scrubber, the `wrangler.final.toml` source-of-truth render, and the `sparse-checkout` of `workers/preview/` from `main` (previously in `preview-deploy.yml`).
- **Cloudflare preview cleanup script** — the 220-line `preview-cleanup.yml` that queried the Cloudflare API and deleted stale workers. `ops-preview.yml`'s `cleanup` job is a placeholder.
- **Google Play internal track upload** (the `google-play-upload.yml` file existed but the release flow never called it; no Play credentials configured).
- **TestFlight upload** (the `ios-testflight.yml` file existed but the release flow never called it; no Apple credentials configured).

### Preserved

- All CI checks (RuboCop, Biome, brakeman, importmap audit, unit, system, Flutter analyze/test, chart lint + template + version sync, pipelock).
- Multi-arch (linux/amd64 + linux/arm64) GHCR image build on `main` / `v*` / schedule.
- The PR preview image contract (tarball + manifest + checksum) used by the Cloudflare worker.
- OpenAI credential check + LLM eval run on `v*` tags.
- Mintlify agent kickoff on `main` pushes.
