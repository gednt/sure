<!-- generated-by: gsd-doc-writer -->
# Deployment

Sure is an open-source Rails application you can deploy through one of two supported paths: a turnkey **Docker Compose** self-host on a single VM, or the official **Helm chart** for Kubernetes. Container images for both are published to GitHub Container Registry (GHCR) by the project's release pipeline.

## Deployment targets

| Target | Config in repo | Notes |
| --- | --- | --- |
| Docker Compose (single VM) | `compose.example.yml`, `compose.example.ai.yml`, `docker-compose.yml` | Recommended for self-hosters; web + worker + Postgres + Redis in one stack. |
| Kubernetes (Helm) | `charts/sure/` (Chart.yaml, values.yaml, templates/) | Production-grade; supports web, worker, optional in-cluster Postgres (CloudNativePG) and Redis (redis-operator), HPAs, Ingress, Pipelock, ServiceMonitor, and a `db:migrate` Helm hook Job. |
| GitHub Container Registry (image) | `.github/workflows/publish.yml` | Multi-arch (`linux/amd64`, `linux/arm64`) images published from `Dockerfile`. |

For pre-built, opinionated Hetzner-style VM setup, see [docs/hosting/hetzner.md](../hosting/hetzner.md). For Pipelock (AI agent security proxy) details, see [docs/hosting/pipelock.md](../hosting/pipelock.md). End-to-end Docker self-hosting is documented in [docs/hosting/docker.md](../hosting/docker.md).

### Container image

- Registry: `ghcr.io` (see `.github/workflows/publish.yml` → `env.REGISTRY`)
- Image name: `${{ github.repository }}` → `ghcr.io/we-promise/sure`
- Tags:
  - `main` builds: long SHA tag (`sha-<long-sha>`)
  - Nightly schedule: `nightly`, `nightly-<ddd>` (e.g. `nightly-Mon`)
  - `vX.Y.Z` stable tags: `X.Y.Z` plus `stable`; `vX.Y.Z-alpha|beta|rc.N` tags publish to `latest`
  - Always use an immutable tag (e.g. `v1.2.3`) in production; do **not** use `latest` for stability.

### Dockerfile (summary)

Defined in `Dockerfile` at the repo root:

- Base image: `registry.docker.com/library/ruby:3.4.9-slim` (matches `.ruby-version`)
- Multi-stage build: `build` installs gems, then the runtime stage runs as non-root `rails` (UID 1000)
- `BUNDLE_DEPLOYMENT=1`, `BUNDLE_WITHER="development"` → production-only gems
- Precompiles bootsnap and Rails assets at build time
- Entrypoint: `bin/docker-entrypoint` (preloads `jemalloc` if available and runs `db:prepare` for the `rails server` command)
- Exposed port: `3000`
- Build arg: `BUILD_COMMIT_SHA` (passed by CI)

## Docker Compose deployment

The repo ships two example compose files:

- `compose.example.yml` — minimal, recommended for self-hosting.
- `compose.example.ai.yml` — variant that wires up AI provider env vars.

A dev-focused `docker-compose.yml` is also committed to the repo and builds the image from the local `Dockerfile` (see the comment block at the top of the file for usage).

Services in the minimal stack (`compose.example.yml`):

- `web` — Rails app, host port `${PORT:-3001}:3000`, depends on `db` and `redis`
- `worker` — Sidekiq process, same image as `web`, command `bundle exec sidekiq`
- `db` — `pgvector/pgvector:pg16` with healthcheck
- `redis` — `redis:latest` with healthcheck

Persistent volumes: `app-storage` (Rails storage), `postgres-data`, `redis-data`. All services join the `sure_net` bridge network.

### First-time deploy with Docker Compose

1. Create a working directory and download the example compose file:
   ```bash
   mkdir -p ~/docker-apps/sure && cd ~/docker-apps/sure
   curl -O https://raw.githubusercontent.com/we-promise/sure/main/compose.example.yml
   ```
2. (Optional) Create `.env` next to the compose file with overrides. The compose file wires up `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, `SECRET_KEY_BASE`, and `PORT` from the environment. Override the `SECRET_KEY_BASE` default before exposing the app publicly:
   ```bash
   echo "SECRET_KEY_BASE=$(openssl rand -hex 32)" >> .env
   ```
3. Pull and start the stack:
   ```bash
   docker compose pull
   docker compose up -d
   ```
4. Tail logs and check the web UI:
   ```bash
   docker compose logs -f web
   # Web UI: http://localhost:3001 (or whatever PORT you set)
   ```

### Updating a Docker Compose deployment

```bash
cd ~/docker-apps/sure
docker compose pull
docker compose up -d
# Optional: prune old images
docker image prune -f
```

The image is published with an `oidc` tag referencing a migration hook job for SimpleFIN encryption backfill — running the upgrade in dry-run mode first is recommended for breaking release lines (see Helm notes below; the same Job concept applies in compose via the `simplefin-backfill-job.yaml` chart template).

## Kubernetes (Helm) deployment

The official chart lives in `charts/sure/`. Full reference documentation for the chart (every value, profile, and template) is in [charts/sure/README.md](../../charts/sure/README.md). Key facts:

- **Requirements:** Kubernetes >= 1.25, Helm >= 3.10
- **Subchart repos** (only needed if you use bundled Postgres / Redis):
  ```sh
  helm repo add cloudnative-pg https://cloudnative-pg.github.io/charts
  helm repo add ot-helm https://ot-container-kit.github.io/helm-charts
  helm repo update
  ```
- **Install (minimal, external Postgres/Redis):**
  ```sh
  kubectl create ns sure || true
  helm upgrade --install sure charts/sure \
    -n sure \
    --set image.tag=v1.2.3 \
    --set cnpg.enabled=false \
    --set redisOperator.managed.enabled=false \
    --set redisSimple.enabled=false \
    --set rails.extraEnv.DATABASE_URL=postgresql://user:pass@db.example.com:5432/sure \
    --set rails.extraEnv.REDIS_URL=redis://:pass@redis.example.com:6379/0
  ```
- **Install (turnkey with in-cluster Postgres + Redis):**
  ```sh
  helm upgrade --install sure charts/sure \
    -n sure \
    --set image.tag=v1.2.3 \
    --set rails.secret.enabled=true \
    --set rails.secret.values.SECRET_KEY_BASE=$(openssl rand -hex 32)
  ```
- **Expose the app:** configure Ingress in `values.yaml` (see `charts/sure/templates/ingress.yaml`) or `kubectl port-forward svc/sure 8080:80 -n sure`.
- **Migrations:** chart supports either a Helm-hook `Job` (default via `migrate-job.yaml`) or an `initContainer` strategy. `simplefin-backfill-job.yaml` runs as a post-install/upgrade hook (idempotent, dry-run by default).
- **Scaling:** enable HPAs via `hpa-web.enabled` / `hpa-worker.enabled` (templates `hpa-web.yaml`, `hpa-worker.yaml`).
- **Monitoring:** optional ServiceMonitor via `servicemonitor.yaml`.

Always pin `image.tag` to an immutable release tag in production.

## Build pipeline

Defined in `.github/workflows/publish.yml`:

1. **Trigger** — push to `main`, push of a `v*` tag, scheduled cron (nightly), or manual `workflow_dispatch` with `push: true`.
2. **CI** — `jobs.ci` reuses `.github/workflows/ci.yml` (must pass before the image is built).
3. **Build (matrix)** — `linux/amd64` and `linux/arm64` are built in parallel on `ubuntu-24.04` and `ubuntu-24.04-arm`, using Docker Buildx with registry cache (`cache-from` / `cache-to: mode=max`) and `oci-mediatypes=true` for OCI annotations. `BUILD_COMMIT_SHA` is passed as a build arg.
4. **Merge** — the multi-arch index manifest is built from per-platform digests and pushed with the configured tags (long SHA, semver, or schedule pattern). Pushes are retried up to 3 times with exponential backoff.
5. **Helm chart package** — for `v*` tags only, `.github/workflows/helm-publish.yml` packages the chart and updates GH Pages.
6. **Mobile apps** — for `v*` tags only, `.github/workflows/flutter-build.yml` builds Android and iOS artifacts.
7. **GitHub Release** — for `v*` tags, a release is created with attached Helm chart, Android APK, and iOS archive.
8. **Release branch / version bump** — for stable `v*` tags a `vX.Y-release-branch` is updated; for pre-release tags (alpha/beta/rc) the next pre-release iteration is bumped in `.sure-version` and `charts/sure/Chart.yaml`.

### Triggers summary

| Event | Image pushed? | Helm published? | Mobile built? | GitHub Release? |
| --- | --- | --- | --- | --- |
| Push to `main` | yes (SHA tag) | no | no | no |
| Push `vX.Y.Z` | yes (semver + `stable`) | yes | yes | yes |
| Push `vX.Y.Z-alpha.N` | yes (semver + `latest`) | yes | yes | yes (prerelease) |
| Scheduled (nightly) | yes (`nightly`, `nightly-<ddd>`) | no | no | no |
| Manual `workflow_dispatch` (push: true) | yes | no | no | no |

## Environment setup

For the full list of required and optional environment variables, see [Configuration](configuration.md). Highlights for production deploys:

- **Required for first boot:**
  - `SECRET_KEY_BASE` — must be a stable, random value in production. Generated with `openssl rand -hex 32`.
  - `RAILS_ENV=production`
  - `DATABASE_URL` or `DB_HOST` + `DB_PORT` + `DB_USER` + `DB_PASSWORD` pointing to a reachable PostgreSQL (with `pgvector`).
  - `REDIS_URL` pointing to a reachable Redis.
  - `BINDING=0.0.0.0` (default in the bundled compose file) to listen on all interfaces inside the container.
- **TLS / reverse proxy:** `RAILS_FORCE_SSL` and `RAILS_ASSUME_SSL` are exposed in `docker-compose.yml` (default `false`). For public deployments, terminate TLS at a reverse proxy (Traefik, Caddy, nginx, or the Kubernetes Ingress) and set `RAILS_ASSUME_SSL=true`.
- **AI features (optional):** `OPENAI_ACCESS_TOKEN` and friends (see [Configuration](configuration.md) and `docs/hosting/ai.md`).
- **OIDC / SSO (optional):** see [docs/hosting/oidc.md](../hosting/oidc.md).
- **Pipelock (optional, Kubernetes only):** see [docs/hosting/pipelock.md](../hosting/pipelock.md).

In Kubernetes, prefer mounting these via an `existingSecret` (or External Secrets) — the chart does not hardcode any secrets.

## Rollback procedure

### Docker Compose

The compose stack has no built-in rollback; roll back by changing the image tag in your compose file (or pinning to a previous immutable tag like `v1.2.2`) and re-running:

```bash
docker compose pull
docker compose up -d
# If the database migration is destructive, restore postgres-data from your snapshot:
# docker compose down
# (restore the postgres-data volume from backup)
# docker compose up -d
```

Always take a `postgres-data` snapshot before upgrading across a release that includes schema changes.

### Kubernetes (Helm)

Helm keeps a release history. Roll back to the previous revision:

```bash
helm history sure -n sure
helm rollback sure <REVISION> -n sure
```

For chart-only or value-only changes you can also re-render and `helm upgrade --install` with the previous tag/values. For data-corrupting migrations, restore the `cnpg-cluster` backup (CloudNativePG) or your managed Postgres snapshot.

## Monitoring

### Error tracking (Sentry)

Sentry is integrated via `config/initializers/sentry.rb`:

- Activated when `ENV["SENTRY_DSN"]` is present.
- `config.enabled_environments = %w[production]` — only loads in production.
- `config.traces_sample_rate = 0.25` and `config.profiles_sample_rate = 0.25` (adjust to taste).
- `config.release` is read from `.sure-version` (set automatically by the release pipeline).
- `config.profiler_class = Sentry::Vernier::Profiler`.
- Per-request user context is set in `app/controllers/concerns/authentication.rb#set_sentry_user`.
- Sentry is also used in the mobile app via `sentry_flutter` (see `mobile/pubspec.yaml`).

Set `SENTRY_DSN` in the production environment to enable.

### Logs

Structured logs flow to `stdout`/`stderr` from the Rails and Sidekiq processes. In Kubernetes, the chart does not ship a log collector — point your platform's log scraper (Loki, Cloud Logging, etc.) at the `sure-web` / `sure-worker` pods. `Sentry.enable_logs = true` forwards Ruby logger output to Sentry when configured.

### Metrics

The chart includes an optional `ServiceMonitor` template (`charts/sure/templates/servicemonitor.yaml`) that scrapes Rails `/metrics` when Prometheus Operator is installed. Enable with `serviceMonitor.enabled=true` in values.

### Pipelock (optional)

For deployments that wire up the Pipelock forward / MCP reverse proxy, the chart ships `pipelock-deployment.yaml`, `pipelock-service.yaml`, `pipelock-ingress.yaml`, `pipelock-servicemonitor.yaml`, and `pipelock-pdb.yaml`. See [docs/hosting/pipelock.md](../hosting/pipelock.md) for observability details.

## CI/CD pipeline reference

| Workflow | File | Purpose |
| --- | --- | --- |
| Publish Docker image | `.github/workflows/publish.yml` | Build, push, and release pipeline (described above). |
| CI | `.github/workflows/ci.yml` | Lint, test, brakeman; gate for `publish.yml`. |
| Pull Request | `.github/workflows/pr.yml` | PR validation. |
| Deploy PR Preview | `.github/workflows/preview-deploy.yml` | Per-PR preview environment (Cloudflare-based; URL pattern `<!-- VERIFY: PR preview URL pattern -->`). |
| Preview cleanup | `.github/workflows/preview-cleanup.yml` | Tear down preview environments. |
| Helm chart CI | `.github/workflows/chart-ci.yml` | Lint and test the chart. |
| Helm publish | `.github/workflows/helm-publish.yml` | Package and publish chart to GH Pages. |
| Chart release | `.github/workflows/chart-release.yml` | Cut a chart release. |
| Pipelock | `.github/workflows/pipelock.yml` | Pipelock-related CI. |
| Mobile CI / build / release | `mobile-ci.yml`, `mobile-build.yml`, `mobile-release.yml`, `ios-testflight.yml`, `google-play-upload.yml` | Mobile release pipeline. |
| Update docs | `.github/workflows/update-docs.yml` | Auto-update generated docs. |
| LLM evals | `.github/workflows/llm-evals.yml` | Regression suite for LLM-backed features. |

## Related guides

- [Getting Started](getting-started.md) — prerequisites and first-run.
- [Configuration](configuration.md) — every environment variable.
- [Architecture](../architecture/overview.md) — how the components fit together.
- [Self-hosting with Docker](../hosting/docker.md) and [Docker quickstart](../hosting/docker-quickstart.md).
- [Helm chart README](../../charts/sure/README.md) — exhaustive chart reference.
