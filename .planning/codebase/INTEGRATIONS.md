# External Integrations

**Analysis Date:** 2026-07-11

## APIs & External Services

**Bank / Brokerage Account Aggregators (provider adapters in `app/models/provider/*_adapter.rb`, registered via `app/models/provider/factory.rb`):**
- **Plaid** — `plaid` 41.0.0 (US + EU regions, separate clients per region)
  - SDK/Client: `Plaid::PlaidApi.new` (`app/models/provider/plaid.rb`)
  - Auth: `PLAID_CLIENT_ID`, `PLAID_SECRET` (per-region `*_EU_*` variants); also DB-stored via `Setting`/`AuthConfig`
  - Webhook signature: `Plaid-Verification` header (`app/controllers/webhooks_controller.rb:7`)
- **SimpleFIN** — HTTP, no SDK
  - Auth: `Setting.simplefin_access_url` (per-user enrollment tokens)
  - Runtime flags: `SIMPLEFIN_INCLUDE_PENDING`, `SIMPLEFIN_DEBUG_RAW` (`config/initializers/simplefin.rb`)
- **Lunchflow** — HTTP, no SDK
  - Auth: per-user `Setting.lunchflow_api_key`
  - Runtime flags: `LUNCHFLOW_INCLUDE_PENDING`, `LUNCHFLOW_DEBUG_RAW` (`config/initializers/lunchflow.rb`)
- **SnapTrade** — `snaptrade` 2.0.156
  - Auth: `SNAPTRADE_OAUTH_CLIENT_ID` + `Rails.application.credentials.dig(:snaptrade, ...)` (`config/initializers/snaptrade.rb`); consumer key/secret via DB-stored `AuthConfig` per family
  - OAuth device flow: `SNAPTRADE_OAUTH_CLIENT_ID` public
- **Enable Banking** — `app/models/provider/enable_banking.rb` / `enable_banking_adapter.rb`
- **Akahu** (NZ) — `akahu_account`, `akahu_item`, `akahu_entry`
- **Binance** (crypto exchange) — `binance_account`, `binance_item`; `binance_public.rb` for public market data
- **Coinbase** (crypto) — `coinbase_account`, `coinbase_item`
- **CoinStats** (crypto) — `coinstats_account`, `coinstats_item`
- **Brex** — `brex_account`, `brex_item`
- **Mercury** — `mercury_account`, `mercury_item`
- **Indexa Capital** — `indexa_capital_account`, `indexa_capital_item`
- **Interactive Brokers (IBKR)** — `ibkr_account`, `ibkr_item`; `ibkr_flex.rb` pulls Flex Queries
- **Kraken** (crypto) — `kraken_account`, `kraken_item`
- **Questrade** (Canadian brokerage) — `questrade_account`, `questrade_item`
- **Sophtron** — `sophtron_account`, `sophtron_item`
- **Up** (Australian bank) — `up_account`, `up_item`

**Market Data / Securities Pricing Providers (`app/models/provider/`):**
- **Twelve Data** — `twelve_data.rb`
  - Auth: `TWELVE_DATA_API_KEY` (also stored in `Setting.twelve_data_api_key`)
  - Base URL: `TWELVE_DATA_URL` (default `https://api.twelvedata.com`)
  - Rate limit env: `TWELVE_DATA_MIN_REQUEST_INTERVAL`, `TWELVE_DATA_MAX_REQUESTS_PER_MINUTE`
- **Yahoo Finance** — `yahoo_finance.rb` (default in `.env.example`)
- **Alpha Vantage** — `alpha_vantage.rb`
- **Tiingo** — `tiingo.rb`
- **EOD Historical Data (EODHD)** — `eodhd.rb`
- **MOEX Public** (Moscow Exchange) — `moex_public.rb`
- **mfapi** (mutual funds) — `mfapi.rb`
- **Tinkoff Invest** — `tinkoff_invest.rb`
- Selection: `EXCHANGE_RATE_PROVIDER` and `SECURITIES_PROVIDER` env vars (`twelve_data` | `yahoo_finance`)

**LLM / AI Providers:**
- **OpenAI (or OpenAI-compatible)** — `app/models/provider/openai.rb`
  - SDK: `::OpenAI::Client.new` (gem `ruby-openai`)
  - Auth: `OPENAI_ACCESS_TOKEN`; optional `OPENAI_URI_BASE` (override endpoint, e.g., LM Studio, Ollama, LocalAI), `OPENAI_MODEL`
  - Capability flags: `OPENAI_REQUEST_TIMEOUT`, `OPENAI_SUPPORTS_PDF_PROCESSING`, `OPENAI_SUPPORTS_RESPONSES_ENDPOINT`, `LLM_JSON_MODE`
- **Anthropic** — `app/models/provider/anthropic.rb`
  - SDK: `::Anthropic::Client.new` (gem `anthropic` 1.43.0)
  - Auth: `ANTHROPIC_API_KEY` (via `Setting` or ENV); optional `ANTHROPIC_BASE_URL` for compatible endpoints
- **External AI Assistant** (delegate to remote agent) — `EXTERNAL_ASSISTANT_URL`, `EXTERNAL_ASSISTANT_TOKEN`, `EXTERNAL_ASSISTANT_AGENT_ID`, `EXTERNAL_ASSISTANT_SESSION_KEY`, `EXTERNAL_ASSISTANT_ALLOWED_EMAILS`
- **Langfuse** (LLM observability) — `langfuse-ruby` 0.1.4
  - Auth: `LANGFUSE_PUBLIC_KEY`, `LANGFUSE_SECRET_KEY`; host: `LANGFUSE_HOST` (default `https://cloud.langfuse.com`)

**Brand Logos / Merchant Enrichment:**
- **Brandfetch** — `BRAND_FETCH_CLIENT_ID`
  - Used via CDN URLs: `https://cdn.brandfetch.io/{domain}/icon/fallback/lettermark/...` (`app/models/account.rb`, `app/models/family_merchant.rb`, `app/models/provider_merchant.rb`, `app/models/provider_merchant/enhancer.rb`, `app/models/provider/binance_public.rb`)

**Git / Code:**
- **GitHub** — `octokit` 10.0.0
  - Used for repo metadata / community features (see `app/models/provider/github.rb`)

**Generic HTTP / Web Fetching:**
- `httparty` 0.24.0 (SimpleFIN, etc.)
- `faraday` 2.14.3 + `faraday-retry` + `faraday-multipart` (provider adapters)

## Data Storage

**Primary Database:**
- **PostgreSQL 16** with `pgvector` extension
  - Docker image: `pgvector/pgvector:pg16` (`docker-compose.yml:88`, `compose.example.ai.yml`)
  - Connection: `DB_HOST`, `DB_PORT` (default `5432`), `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` (`config/database.yml`)
  - ORM: ActiveRecord (Rails 8.1.3)
  - Migrations: 379 files in `db/migrate/`
  - Vector storage: `vector(N)` columns on `vector_store_chunks`; default 1024 dims (`EMBEDDING_DIMENSIONS` env, `db/migrate/20260601120000_ensure_vector_store_chunks_for_default_pgvector.rb`)

**File / Object Storage (Active Storage — `config/storage.yml`):**
- **Local Disk** — default; `storage/` and `tmp/storage/` (test)
- **Amazon S3** — `aws-sdk-s3` 1.208.0; vars: `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`, `S3_REGION` (default `us-east-1`), `S3_BUCKET`; selected via `ACTIVE_STORAGE_SERVICE=amazon`
- **Cloudflare R2** — S3-compatible; vars: `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_ACCESS_KEY_ID`, `CLOUDFLARE_SECRET_ACCESS_KEY`, `CLOUDFLARE_BUCKET`; selected via `ACTIVE_STORAGE_SERVICE=cloudflare`
- **Generic S3** (e.g., MinIO, Backblaze B2) — `GENERIC_S3_*` + `GENERIC_S3_ENDPOINT`, `GENERIC_S3_FORCE_PATH_STYLE`; selected via `ACTIVE_STORAGE_SERVICE=generic_s3`
- **Google Cloud Storage** — `google-cloud-storage` 1.59.0; vars: `GCS_PROJECT`, `GUCKET`, `GCS_KEYFILE_JSON` (preferred) or `GCS_KEYFILE`; selected via `ACTIVE_STORAGE_SERVICE=google`

**Cache:**
- **Redis** — `redis` 5.4 gem
  - Production: `cache_store = :redis_cache_store, { url: ENV["REDIS_URL"] }` (`config/environments/production.rb`)
  - Development: `:memory_store`; Test: `:null_store`
  - Also used as Sidekiq broker and ActionCable adapter

**Vector Store Registry (`app/models/vector_store/`):**
- `VectorStore::Pgvector` (default for Anthropic installs; see migration)
- `VectorStore::Qdrant` — Qdrant vector DB
- `VectorStore::Openai` — OpenAI embeddings API (no separate store)
- `VectorStore::Base`, `VectorStore::Embeddable`, `VectorStore::Registry`

**Local Mobile Storage (Flutter):**
- `sqflite` 2.4.2 (offline SQLite cache)
- `shared_preferences` 2.2.2 (key-value)
- `flutter_secure_storage` 10.0.0 (secrets/credentials)

## Authentication & Identity

**Session / Password:**
- Custom cookie-based session: `cookies.signed[:session_token]` → `Session.find_by(id:)` (referenced in `config/initializers/doorkeeper.rb:12-24`)
- `bcrypt` 3.1.22 for password hashing

**OAuth 2.0 (server, via Doorkeeper):**
- `doorkeeper` 5.8.2
  - Mounted under `/oauth` (config in `config/initializers/doorkeeper.rb`); grants `X-Api-Key` access tokens consumed by `app/controllers/api/v1/`
  - Resource owner authenticator pulls from the app's `Session` cookie (so the API uses the same auth as the web app)
  - Client registration endpoint: `app/controllers/oauth_registration_controller.rb`
  - OpenAPI specs: `spec/requests/api/v1/*` (rswag, docs only)

**MFA (multi-factor):**
- **TOTP** — `rotp` 6.3.0 + `rqrcode` 3.1.0 (`app/models/mfa.rb`-style flow, `/mfa` routes)
- **WebAuthn / Passkeys** — `webauthn` 3.4.3
  - Config: `WEBAUTHN_RP_ID`, `WEBAUTHN_ALLOWED_ORIGINS` (`config/initializers/webauthn.rb`)

**SSO / Federated Identity (OmniAuth — `config/initializers/omniauth.rb`):**
- **OpenID Connect (OIDC)** — `omniauth_openid_connect` 0.8.0
  - Generic OIDC: `OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET`, `OIDC_ISSUER`, `OIDC_REDIRECT_URI`; multi-provider via `ProviderLoader` + DB-stored `AuthConfig`
- **Google OAuth 2.0** — `omniauth-google-oauth2` 1.2.1
  - `GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET`
- **GitHub OAuth** — `omniauth-github` 2.0.1
  - `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET`
- **SAML 2.0** — `omniauth-saml` 2.2.4 + `ruby-saml` 1.18.1
  - IdP metadata URL or manual IdP SSO URL + certificate/fingerprint (configured per provider in `auth.yml` or `AuthConfig`)

**API Authentication:**
- OAuth 2.0 Bearer tokens via Doorkeeper (clients obtain tokens through standard flows)
- API key: `X-Api-Key` header pattern (per `AGENTS.md` "API Development Guidelines")

**CSRF / Throttling:**
- `omniauth-rails_csrf_protection` 2.0.1
- `rack-attack` 6.7.0 (production/staging only): throttles `/oauth/token`, `/register`, `/mfa/webauthn_options` + `/mfa/verify_webauthn`, `/admin/*` (`config/initializers/rack_attack.rb`)

## Email / SMTP

- Standard SMTP via `ActionMailer` (Rails)
  - Configured through env vars: `SMTP_ADDRESS`, `SMTP_PORT` (default `465`), `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_TLS_ENABLED` (default `true`), `SMTP_TLS_SKIP_VERIFY`, `EMAIL_SENDER`
  - Dev preview: `letter_opener`
  - Not used in tests by default; transactional emails are stubbed in Minitest

## Monitoring & Observability

**Error Tracking:**
- **Sentry** — `sentry-ruby` + `sentry-rails` + `sentry-sidekiq` 5.26.0
  - DSN: `SENTRY_DSN` (only initializes when set; `config/initializers/sentry.rb`)
  - Environment: `RAILS_ENV`; enabled only in `production`
  - Traces sample rate: `0.25`; profiles: `0.25`
  - Profiler: `Sentry::Vernier::Profiler` (uses `vernier` 1.8.0)
  - Release: `Rails.root.join(".sure-version").read.strip` (e.g., `0.7.3-alpha.2`)

**Product Analytics:**
- **PostHog** — `posthog-ruby` 3.3.3
  - API key: `POSTHOG_KEY`; host: `POSTHOG_HOST` (default `https://us.i.posthog.com`)
  - Client initialized in `config/initializers/posthog.rb`

**APM:**
- **Skylight** — `skylight` 6.0.4
  - `SKYLIGHT_AUTHENTICATION`, `SKYLIGHT_ENABLED`; production by default, dev-only when `SKYLIGHT_ENABLED=true` (see `Gemfile:47-51`)

**Logs:**
- **Logtail** (Better Stack) — `logtail-rails` / `logtail` 0.1.17
- **Rails logger** + `active_support_logger` and `http_logger` breadcrumbs feed into Sentry
- `rack-mini-profiler` for dev request profiling

**LLM Observability:**
- **Langfuse** — see LLM providers above

**Internal:**
- `DebugLogEntry` model — structured diagnostic log surfaced in super-admin `/settings/debug` UI (referenced in `AGENTS.md`)

## CI/CD & Deployment

**Hosting:**
- Self-hostable Rails monolith (no managed-hosting SaaS in repo)
- Docker images published to `ghcr.io/we-promise/sure:stable` (`compose.example.yml`)
- Helm chart for Kubernetes: `charts/sure` (v0.7.3-alpha.2, `appVersion: 0.7.3-alpha.2`); optional subcharts `cloudnative-pg ~0.27`, `redis-operator ~0.23`

**CI Pipeline:**
- `.github/` directory present (assumed GitHub Actions — no explicit inspection of workflows here, but `ghcr.io` + `we-promise/sure` image name matches GitHub Actions pattern in the compose examples)
- `pipelock.example.yaml` — egress proxy config used in `compose.example.ai.yml` (pipelock: `ghcr.io/luckypipewrench/pipelock:2.8.0`)

**Sidekiq UI:**
- `/sidekiq` mounted in production; HTTP Basic auth via `SIDEKIQ_WEB_USERNAME` / `SIDEKIQ_WEB_PASSWORD` (SHA-256 + secure compare; `config/initializers/sidekiq.rb:4-11`)

**Cron / Scheduled Jobs (`config/schedule.yml` + sidekiq-cron):**
- `ImportMarketDataJob` (weekdays 17:00 EST)
- `SyncCleanerJob` (hourly)
- `SecurityHealthCheckJob` (weekdays 02:00 EST)
- `SyncHourlyJob` (hourly)
- `DataCleanerJob` (03:00 daily)
- `DebugLogCleanupJob` (03:30 daily, 90-day retention)
- `InactiveFamilyCleanerJob` (04:00 daily)
- `DemoFamilyRefreshJob` (05:00 UTC daily)
- `SweepExpiredGoalPledgesJob` (every 15 min)
- Sidekiq-cron grace period: 10 minutes (`config/initializers/sidekiq.rb:76-77`)

## Environment Configuration

**Required env vars (minimum viable):**
- `SECRET_KEY_BASE`
- `POSTGRES_USER`, `POSTGRES_PASSWORD`, `DB_HOST` (or Docker Compose defaults)
- `REDIS_URL`
- `SELF_HOSTED` (true/false)
- `APP_DOMAIN` (used for WebAuthn RP ID fallback and email links)

**Provider API keys (each is optional; functionality gated by presence):**
- `PLAID_CLIENT_ID`, `PLAID_SECRET` (+ `_EU_` variants)
- `TWELVE_DATA_API_KEY`
- `BRAND_FETCH_CLIENT_ID`
- `SNAPTRADE_OAUTH_CLIENT_ID` + DB-stored consumer key/secret
- `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `STRIPE_MONTHLY_PRICE_ID`, `STRIPE_ANNUAL_PRICE_ID`
- `OPENAI_ACCESS_TOKEN` (+ optional `OPENAI_URI_BASE`, `OPENAI_MODEL`)
- `ANTHROPIC_API_KEY`
- `LANGFUSE_PUBLIC_KEY`, `LANGFUSE_SECRET_KEY`, `LANGFUSE_HOST`
- `POSTHOG_KEY`, `POSTHOG_HOST`
- `SENTRY_DSN`
- `SKYLIGHT_AUTHENTICATION`
- `SMTP_*`, `EMAIL_SENDER`
- Active Storage: `ACTIVE_STORAGE_SERVICE` + provider-specific keys
- SSO: `GOOGLE_OAUTH_*`, `GITHUB_*`, `OIDC_*`; SAML via `ProviderLoader`/DB

**Secrets location:**
- `.env.local` (gitignored) — local dev
- `.env.test` (gitignored) — test
- `Rails.application.credentials` (`config/credentials.yml.enc`, encrypted) — production defaults
- WebAuthn / SnapTrade may be set via `Rails.application.credentials.dig(:webauthn, …)` / `(:snaptrade, …)`
- All example env vars are listed in `.env.example` and `.env.local.example`

## Webhooks & Callbacks

**Incoming (config/routes.rb:716-720, `app/controllers/webhooks_controller.rb`):**
- `POST /webhooks/plaid` — Plaid US webhooks (`Plaid-Verification` header)
- `POST /webhooks/plaid_eu` — Plaid EU webhooks
- `POST /webhooks/stripe` — Stripe webhooks (`HTTP_STRIPE_SIGNATURE` header → `Stripe::SignatureVerificationError` rescue)
- `POST /mcp` — Model Context Protocol JSON-RPC 2.0 endpoint for external AI assistants (`app/controllers/mcp_controller.rb`), bearer-token auth via `MCP_API_TOKEN` + `MCP_USER_EMAIL`

**Outgoing (provider adapter calls — initiated by the app, no callback beyond HTTP responses):**
- Bank sync initiation: `POST /s/provider_connections/:key/sync` family
- Provider OAuth callbacks: `/auth/{provider}/callback` (OmniAuth strategies: openid_connect, google_oauth2, github, saml)
- SnapTrade device flow: client returns redirect/URI for the user to authorize at SnapTrade

---

*Integration audit: 2026-07-11*
