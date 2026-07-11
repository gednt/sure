<!-- generated-by: gsd-doc-writer -->
# Configuration

This document describes all configuration options available for Sure, including environment variables, config files, and per-environment settings.

## Environment Variables

Sure uses environment variables for configuration. Copy `.env.local.example` to `.env.local` for development or configure these directly in your deployment environment.

### Core Application Settings

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `SELF_HOSTED` | Optional | `false` | Enable self-hosting features. Set to `true` for self-hosted deployments. |
| `PORT` | Optional | `3000` | Port for the Puma web server to listen on. |
| `RAILS_ENV` | Optional | `development` | Rails environment (`development`, `test`, `production`). |
| `RAILS_MAX_THREADS` | Optional | `3` | Maximum number of threads for Puma. |
| `WEB_CONCURRENCY` | Optional | `1` | Number of Puma worker processes. |
| `SECRET_KEY_BASE` | Required | (none) | Secret key base for Rails session encryption. Must be set in production. |
| `RAILS_MASTER_KEY` | Optional | (none) | Master key for decrypting credentials.yml.enc. |

### Database Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DB_HOST` | Optional | `127.0.0.1` | PostgreSQL database host. |
| `DB_PORT` | Optional | `5432` | PostgreSQL database port. |
| `POSTGRES_USER` | Optional | (none) | PostgreSQL database username. |
| `POSTGRES_PASSWORD` | Optional | (none) | PostgreSQL database password. |
| `POSTGRES_DB` | Optional | `sure_development` | PostgreSQL database name (varies by environment). |

### Cache and Job Queue

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `REDIS_URL` | Optional | `redis://localhost:6379/0` | Redis URL for cache store and Sidekiq. |
| `REDIS_PASSWORD` | Optional | (none) | Redis password for authentication. |
| `REDIS_SENTINEL_HOSTS` | Optional | (none) | Comma-separated list of Redis sentinel hosts (`host1:port1,host2:port2`). |
| `REDIS_SENTINEL_MASTER` | Optional | `mymaster` | Redis sentinel master name. |
| `REDIS_SENTINEL_USERNAME` | Optional | `default` | Redis sentinel username. |

### SSL/TLS Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `SSL_CA_FILE` | Optional | (none) | Path to custom CA certificate file (PEM format) for self-signed certificates. |
| `SSL_VERIFY` | Optional | `true` | Enable/disable SSL certificate verification. Set to `false` only for development/testing. |
| `SSL_DEBUG` | Optional | `false` | Enable verbose SSL logging for troubleshooting certificate issues. |
| `SSL_CERT_FILE` | Optional | (none) | Path to SSL certificate file (auto-configured by SSL initializer). |

### Email Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `SMTP_ADDRESS` | Required for email | (none) | SMTP server address. |
| `SMTP_PORT` | Required for email | (none) | SMTP server port. |
| `SMTP_USERNAME` | Required for email | (none) | SMTP authentication username. |
| `SMTP_PASSWORD` | Required for email | (none) | SMTP authentication password. |
| `SMTP_TLS_ENABLED` | Optional | `false` | Enable TLS for SMTP connections. |
| `SMTP_TLS_SKIP_VERIFY` | Optional | `false` | Skip TLS verification (not recommended). |

### Authentication and Authorization

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `OIDC_ISSUER` | Optional | (none) | OpenID Connect issuer URL. |
| `OIDC_CLIENT_ID` | Optional | (none) | OpenID Connect client ID. |
| `OIDC_CLIENT_SECRET` | Optional | (none) | OpenID Connect client secret. |
| `OIDC_REDIRECT_URI` | Optional | `http://localhost:3000/auth/openid_connect/callback` | OpenID Connect redirect URI. |
| `GOOGLE_OAUTH_CLIENT_ID` | Optional | (none) | Google OAuth client ID. |
| `GOOGLE_OAUTH_CLIENT_SECRET` | Optional | (none) | Google OAuth client secret. |
| `GITHUB_CLIENT_ID` | Optional | (none) | GitHub OAuth client ID. |
| `GITHUB_CLIENT_SECRET` | Optional | (none) | GitHub OAuth client secret. |
| `WEBAUTHN_RP_ID` | Optional | `localhost` | WebAuthn relying party ID (must match domain). |
| `WEBAUTHN_ALLOWED_ORIGINS` | Optional | `http://localhost:3000` | WebAuthn allowed origins (comma-separated). |

### AI/LLM Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `OPENAI_ACCESS_TOKEN` | Optional | (none) | OpenAI-compatible API access token. |
| `OPENAI_URI_BASE` | Optional | (none) | OpenAI-compatible API endpoint base URL. |
| `OPENAI_MODEL` | Optional | (none) | Model name for OpenAI-compatible API. |
| `OPENAI_REQUEST_TIMEOUT` | Optional | `60` | HTTP timeout in seconds for OpenAI requests. |
| `OPENAI_SUPPORTS_PDF_PROCESSING` | Optional | `true` | Whether the endpoint supports vision/PDF processing. |
| `OPENAI_SUPPORTS_RESPONSES_ENDPOINT` | Optional | (none) | Force Responses API for custom providers. |
| `LLM_CONTEXT_WINDOW` | Optional | `2048` | Total tokens the model will accept. |
| `LLM_MAX_RESPONSE_TOKENS` | Optional | `512` | Reserved tokens for the model's reply. |
| `LLM_SYSTEM_PROMPT_RESERVE` | Optional | `256` | Tokens reserved for the system prompt. |
| `LLM_MAX_ITEMS_PER_CALL` | Optional | `25` | Upper bound on auto-categorize/merchant batches. |
| `LLM_JSON_MODE` | Optional | `auto` | JSON mode: `auto`, `strict`, `json_object`, or `none`. |
| `AI_DEBUG_MODE` | Optional | (none) | Set to `true` to render error messages in `/chats` UI. |

### External Assistant

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `EXTERNAL_ASSISTANT_ALLOWED_EMAILS` | Optional | (none) | Comma-separated list of emails allowed to use external assistant. |
| `EXTERNAL_ASSISTANT_URL` | Optional | (none) | External assistant API URL. |
| `EXTERNAL_ASSISTANT_TOKEN` | Optional | (none) | External assistant API token. |
| `EXTERNAL_ASSISTANT_AGENT_ID` | Optional | `main` | External assistant agent ID. |

### Data Providers

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `TWELVE_DATA_API_KEY` | Optional | (none) | API key for Twelve Data market data provider. |
| `TWELVE_DATA_URL` | Optional | `https://api.twelvedata.com` | Twelve Data API endpoint URL. |
| `YAHOO_FINANCE_URL` | Optional | `https://query1.finance.yahoo.com` | Yahoo Finance API endpoint URL. |
| `TIINGO_URL` | Optional | `https://api.tiingo.com` | Tiingo API endpoint URL. |
| `MFAPI_URL` | Optional | `https://api.mfapi.in` | MFAPI (Indian mutual funds) endpoint URL. |
| `EODHD_URL` | Optional | `https://eodhd.com` | EODHD API endpoint URL. |
| `BINANCE_PUBLIC_URL` | Optional | `https://data-api.binance.vision` | Binance public data API URL. |
| `ALPHA_VANTAGE_URL` | Optional | `https://www.alphavantage.co` | Alpha Vantage API endpoint URL. |
| `SNAPTRADE_OAUTH_CLIENT_ID` | Optional | (none) | SnapTrade OAuth device flow client ID. |

### Provider-Specific Settings

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `SIMPLEFIN_DEBUG_RAW` | Optional | `false` | Log raw SimpleFIN payloads (debug-only, noisy). |
| `SIMPLEFIN_INCLUDE_PENDING` | Optional | `false` | Force `pending=1` on SimpleFIN fetches when caller doesn't specify. |
| `PLAID_ENV` | Optional | `sandbox` | Plaid API environment (`sandbox`, `development`, `production`). |
| `PLAID_INCLUDE_PENDING` | Optional | `false` | Include pending transactions in Plaid imports. |
| `PLAID_EU_ENV` | Optional | `sandbox` | Plaid EU API environment. |
| `LUNCHFLOW_DEBUG_RAW` | Optional | `false` | Log raw Lunchflow payloads (debug-only, noisy). |
| `LUNCHFLOW_INCLUDE_PENDING` | Optional | `false` | Add `include_pending=true` to Lunchflow transaction fetches. |
| `UP_DEBUG_RAW` | Optional | `false` | Log raw Up bank payloads (debug-only). |

### Monitoring and Analytics

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `SENTRY_DSN` | Optional | (none) | Sentry DSN for error tracking. |
| `POSTHOG_KEY` | Optional | (none) | PostHog API key for analytics. |
| `POSTHOG_HOST` | Optional | `https://us.i.posthog.com` | PostHog host URL. |
| `LANGFUSE_PUBLIC_KEY` | Optional | (none) | Langfuse public key for LLM observability. |
| `LANGFUSE_SECRET_KEY` | Optional | (none) | Langfuse secret key for LLM observability. |
| `LANGFUSE_HOST` | Optional | `https://cloud.langfuse.com` | Langfuse host URL. |
| `LANGFUSE_REGION` | Optional | (none) | Langfuse region (`us`, `eu`, etc.). |
| `SKYLIGHT_AUTHENTICATION` | Optional | (none) | Skylight authentication token. |
| `SKYLIGHT_ENABLED` | Optional | `false` | Enable Skylight performance monitoring. |
| `LOGTAIL_API_KEY` | Optional | (none) | Logtail API key for logging. |
| `LOGTAIL_INGESTING_HOST` | Optional | (none) | Logtail ingesting host URL. |

### Storage Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `ACTIVE_STORAGE_SERVICE` | Optional | `local` | Active Storage service (`local`, `google`, etc.). |
| `GCS_PROJECT` | Optional | (none) | Google Cloud Storage project ID. |
| `GCS_BUCKET` | Optional | (none) | Google Cloud Storage bucket name. |
| `GCS_KEYFILE_JSON` | Optional | (none) | Google Cloud Storage keyfile JSON content. |
| `GCS_KEYFILE` | Optional | (none) | Google Cloud Storage keyfile path. |

### Application Behavior

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `ONBOARDING_STATE` | Optional | `open` | Controls onboarding flow (`open`, `closed`, `invite_only`). |
| `PRODUCT_NAME` | Optional | `Sure` | Product name displayed in the UI. |
| `BRAND_NAME` | Optional | `FOSS` | Brand name displayed in the UI. |
| `DEFAULT_UI_LAYOUT` | Optional | `dashboard` | Default UI layout (`dashboard`, `intro`). |
| `DEBUG_LOG_RETENTION_DAYS` | Optional | `90` | Number of days to retain debug log entries. |
| `APP_DOMAIN` | Optional | (none) | Application domain for URL generation. |
| `APP_URL` | Optional | (none) | Full application URL. |
| `RAILS_FORCE_SSL` | Optional | `true` | Force SSL in production. |
| `RAILS_ASSUME_SSL` | Optional | `true` | Assume SSL in production (behind reverse proxy). |
| `RAILS_LOG_LEVEL` | Optional | `info` | Rails log level (`debug`, `info`, `warn`, `error`, `fatal`). |

### Sidekiq Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `SIDEKIQ_WEB_USERNAME` | Optional | `sure` | Sidekiq web UI username (hashed). |
| `SIDEKIQ_WEB_PASSWORD` | Optional | `sure` | Sidekiq web UI password (hashed). |

### Testing Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `COVERAGE` | Optional | `false` | Enable SimpleCov test coverage reports. |
| `DISABLE_PARALLELIZATION` | Optional | `false` | Run test suite serially instead of in parallel. |
| `CI` | Optional | (none) | Set to indicate running in CI environment. |
| `EMAIL_SENDER` | Optional | `hello@example.com` | Default email sender for tests. |

### Legal Links

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `LEGAL_PRIVACY_URL` | Optional | (none) | URL for privacy policy page. |
| `LEGAL_TERMS_URL` | Optional | (none) | URL for terms of service page. |

### Misc Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `PIDFILE` | Optional | (none) | Path to Puma PID file. |
| `CODESPACES` | Optional | (none) | Set to `true` when running in GitHub Codespaces. |
| `GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN` | Optional | (none) | Codespaces port forwarding domain. |
| `NO_PROXY` | Optional | (none) | Comma-separated list of proxy bypass hosts. |

## Config File Format

### Database Configuration (`config/database.yml`)

The database configuration uses standard Rails database.yml format with environment variable support:

```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 3 } %>
  host: <%= ENV.fetch("DB_HOST") { "127.0.0.1" } %>
  port: <%= ENV.fetch("DB_PORT") { "5432" } %>
  user: <%= ENV.fetch("POSTGRES_USER") { nil } %>
  password: <%= ENV.fetch("POSTGRES_PASSWORD") { nil } %>

development:
  <<: *default
  database: <%= ENV.fetch("POSTGRES_DB") { "sure_development" } %>

test:
  <<: *default
  database: <%= ENV.fetch("POSTGRES_DB") { "sure_test" } %>

production:
  <<: *default
  database: <%= ENV.fetch("POSTGRES_DB") { "sure_production" } %>
```

### Rails Credentials (`config/credentials.yml.enc`)

Sensitive configuration can be stored in encrypted Rails credentials. Use `rails credentials:edit` to edit:

```bash
EDITOR=vim rails credentials:edit
```

Credentials support the following structure:

```yaml
active_record_encryption:
  primary_key: "your-32-byte-primary-key"
  deterministic_key: "your-32-byte-deterministic-key"
  key_derivation_salt: "your-32-byte-salt"
```

### Other Config Files

- `config/storage.yml` - Active Storage service configurations
- `config/sidekiq.yml` - Sidekiq job processing configuration
- `config/schedule.yml` - Sidekiq Cron scheduled jobs
- `config/auth.yml` - Authentication provider settings
- `config/currencies.yml` - Currency exchange rate configuration

## Required vs Optional Settings

### Production Startup Requirements

The following settings will cause application startup to fail if missing in production:

- `SECRET_KEY_BASE` - Required for session encryption
- `DB_HOST`, `POSTGRES_USER`, `POSTGRES_PASSWORD` - Required for database connectivity
- `REDIS_URL` - Required for cache and job queue functionality

### Encryption Keys

Active Record encryption keys are configured with this priority:

1. **Environment variables** (works for both managed and self-hosted):
   - `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`
   - `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY`
   - `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT`

2. **Auto-generation** (self-hosted only): If `SELF_HOSTED=true` and no credentials or env vars present, keys are auto-generated from `SECRET_KEY_BASE`

3. **Rails credentials** (fallback): Use `rails credentials:edit` to set `active_record_encryption` keys

**Partial configuration is not allowed** - if any encryption env var is set, all three must be set.

## Defaults

### Application Defaults

| Setting | Default Value | Location |
|---------|---------------|----------|
| `PORT` | `3000` | `config/puma.rb` |
| `RAILS_MAX_THREADS` | `3` | `config/puma.rb`, `config/database.yml` |
| `WEB_CONCURRENCY` | `1` | `config/puma.rb` |
| `REDIS_URL` | `redis://localhost:6379/0` | `config/initializers/sidekiq.rb` |
| `PRODUCT_NAME` | `Sure` | `config/initializers/brand.rb` |
| `BRAND_NAME` | `FOSS` | `config/initializers/brand.rb` |
| `DEBUG_LOG_RETENTION_DAYS` | `90` | `config/application.rb` |
| `DEFAULT_UI_LAYOUT` | `dashboard` | `config/application.rb` |
| `POSTHOG_HOST` | `https://us.i.posthog.com` | `config/initializers/posthog.rb` |
| `ACTIVE_STORAGE_SERVICE` | `local` | `config/environments/*.rb` |

### Provider Defaults

| Setting | Default Value | Location |
|---------|---------------|----------|
| `TWELVE_DATA_URL` | `https://api.twelvedata.com` | `app/models/provider/twelve_data.rb` |
| `YAHOO_FINANCE_URL` | `https://query1.finance.yahoo.com` | `app/models/provider/yahoo_finance.rb` |
| `TIINGO_URL` | `https://api.tiingo.com` | `app/models/provider/tiingo.rb` |
| `MFAPI_URL` | `https://api.mfapi.in` | `app/models/provider/mfapi.rb` |
| `EODHD_URL` | `https://eodhd.com` | `app/models/provider/eodhd.rb` |
| `BINANCE_PUBLIC_URL` | `https://data-api.binance.vision` | `app/models/provider/binance_public.rb` |
| `ALPHA_VANTAGE_URL` | `https://www.alphavantage.co` | `app/models/provider/alpha_vantage.rb` |
| `PLAID_ENV` | `sandbox` | `app/models/provider/plaid_adapter.rb` |
| `PLAID_EU_ENV` | `sandbox` | `app/models/provider/plaid_eu_adapter.rb` |
| `EXTERNAL_ASSISTANT_AGENT_ID` | `main` | `app/models/assistant/external.rb` |

## Per-Environment Overrides

### Development

Development configuration is loaded from `.env.local`. Key overrides:

- `RAILS_ENV=development`
- `ACTIVE_STORAGE_SERVICE=local` (default, can be overridden)
- Detailed logging enabled
- Debug toolbars available

### Test

Test configuration uses `.env.test.example`. Key differences:

- `SELF_HOSTED=false` (forced)
- `EMAIL_SENDER=hello@example.com` (forced)
- Parallel test execution enabled (can be disabled with `DISABLE_PARALLELIZATION=true`)
- Coverage reports available when `COVERAGE=true`
- Test-specific database: `sure_test`

### Production

Production configuration is typically provided via environment variables or secrets management. Key overrides:

- `RAILS_FORCE_SSL=true` (default, can be overridden)
- `RAILS_ASSUME_SSL=true` (default, can be overridden)
- `ACTIVE_STORAGE_SERVICE=local` (default, should be overridden to cloud storage)
- `RAILS_LOG_LEVEL=info` (default)
- Redis cache store enabled when `REDIS_URL` is present

## Configuration Validation

### SSL Certificate Validation

When `SSL_CA_FILE` is set, the application validates that:
- The file exists and is readable
- The file contains valid PEM-formatted certificates
- Certificates can be loaded by OpenSSL

Set `SSL_DEBUG=true` to enable detailed SSL connection logging for troubleshooting.

### Encryption Key Validation

The application validates encryption key configuration at startup:
- All three env vars must be set if any are set
- Keys must be at least 32 bytes for primary and deterministic keys
- Salt must be at least 32 bytes
- Invalid configuration raises `ActiveRecordEncryptionConfig::PartialEnvError`

### WebAuthn Configuration Validation

WebAuthn validates that:
- `WEBAUTHN_RP_ID` matches the current domain
- `WEBAUTHN_ALLOWED_ORIGINS` includes the current origin
- Falls back to `APP_DOMAIN` if `WEBAUTHN_RP_ID` is not set