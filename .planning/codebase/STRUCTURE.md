# Codebase Structure

**Analysis Date:** 2026-07-11

## Directory Layout

```
<project-root>/
├── app/                                  # Rails application code (MVC + service-layer namespaces)
│   ├── assets/                           # CSS/fonts/images (compiled to public/assets by Propshaft)
│   │   ├── tailwind/
│   │   │   ├── sure-design-system.css    # DS tokens (functional utility classes)
│   │   │   └── application.css           # Tailwind entrypoint
│   │   ├── fonts/                        # Geist / Geist Mono font files
│   │   └── images/                       # Logos, icons
│   ├── channels/                         # ActionCable
│   │   └── application_cable/            # ApplicationCable::Channel, ApplicationCable::Connection
│   ├── components/                       # ViewComponents
│   │   ├── DS/                           # Design-system primitives (Alert, Button, Dialog, …)
│   │   ├── UI/                           # Higher-level UI components built on DS/*
│   │   ├── goals/                        # Goal-specific components
│   │   ├── settings/                     # Settings-page components
│   │   ├── application_component.rb      # Base class (includes Turbo helpers)
│   │   └── design_system_component.rb    # Base for DS/* with token helpers
│   ├── controllers/                      # HTTP layer
│   │   ├── application_controller.rb     # Root controller, includes 14+ concerns
│   │   ├── concerns/                     # Cross-cutting controller modules (Authentication, …)
│   │   ├── api/v1/                       # JSON:API (Doorkeeper + X-Api-Key)
│   │   ├── admin/                        # Super-admin namespace
│   │   ├── settings/                     # /settings/* namespace
│   │   ├── transactions/                 # Bulk operations, categorize
│   │   ├── import/                       # /imports/* sub-flows (upload, config, clean, confirm, qif)
│   │   ├── brex_items/                   # Brex multi-step controller split
│   │   ├── category/                     # /category/dropdown
│   │   ├── tag/                          # /tags/:id/deletions
│   │   └── webhooks_controller.rb        # Plaid US/EU, Stripe
│   ├── data_migrations/                  # One-off production data backfills
│   ├── helpers/                          # View helpers (and api/* helpers)
│   ├── javascript/                       # Stimulus + Turbo client code
│   │   ├── application.js                # Turbo boot, HwCombobox fix, service worker
│   │   ├── controllers/                  # ~80 Stimulus controllers
│   │   ├── controllers/application.js    # Stimulus boot
│   │   ├── services/                     # JS service objects (e.g. currencies_service.js)
│   │   ├── shims/                        # JS shims
│   │   └── utils/                        # Pure JS utilities
│   ├── jobs/                             # Sidekiq jobs (sync, import, AI, cleanup)
│   ├── mailers/                          # ApplicationMailer + 5 transactional mailers
│   ├── middleware/                       # Rack middleware (OmniAuth error handler)
│   ├── models/                           # Domain layer (AR + PORO services + concerns)
│   │   ├── concerns/                     # Accountable, Entryable, Syncable, Monetizable, …
│   │   ├── provider/                     # All third-party adapters (Base, Factory, Registry, *)
│   │   ├── rule/                         # Rule engine (registry, condition_filter, action_executor)
│   │   ├── assistant/                    # AI assistant (base, builtin, external, function/*)
│   │   ├── import/                       # Import staging (row, mapping, account_mapping, …)
│   │   ├── recurring_transaction/        # Recurring transaction logic
│   │   ├── simplefin/                    # SimpleFin-specific helpers
│   │   ├── category/                     # Category merger
│   │   └── <every AR model>.rb           # Account, User, Family, Entry, Transaction, …
│   ├── policies/                         # Pundit policies (Account, Application, SsoProvider, User)
│   ├── services/                         # True cross-cutting infrastructure services
│   │   ├── api_rate_limiter.rb
│   │   ├── auto_sync_scheduler.rb
│   │   ├── noop_api_rate_limiter.rb
│   │   └── provider_loader.rb
│   └── views/                            # ERB templates
│       ├── DS/tag_select/                # DS tag-select partial
│       ├── api/v1/                       # JSON views (rarely used; most API returns are inline JSON)
│       ├── layouts/                      # application, auth, mailer
│       └── <resource>/                   # Per-resource ERB partials
├── bin/                                  # Executable scripts
│   ├── dev                               # Foreman launcher (web + css + worker)
│   ├── setup                             # Initial app setup
│   ├── docker-entrypoint
│   ├── brakeman / rubocop / rspec / rake / rails
│   └── update_structure.sh
├── charts/                               # Helm chart for production deployment
├── config/                               # Rails configuration
│   ├── application.rb
│   ├── routes.rb                         # 762 lines; full route table
│   ├── database.yml / storage.yml / cable.yml / sidekiq.yml
│   ├── auth.yml                          # Default SSO providers (when not loaded from DB)
│   ├── currencies.yml / exchanges.yml    # Currency & exchange metadata
│   ├── environments/                     # development.rb, production.rb, test.rb
│   ├── initializers/                     # 30+ initializers (Doorkeeper, Sidekiq, Plaid, …)
│   ├── locales/                          # i18n YAML files
│   └── schedule.yml                      # sidekiq-cron entries
├── db/
│   ├── migrate/                          # Rails migrations
│   ├── schema.rb                         # Authoritative schema
│   ├── seeds.rb / seeds/                 # Seed data
│   └── eval_data/                        # AI eval fixtures
├── design/                               # Design artifacts (logos, mockups)
├── docs/                                 # User-facing documentation (append-only)
│   ├── api/openapi.yaml                  # Generated OpenAPI 3 spec
│   └── llm-guides/                       # LLM-facing how-tos (e.g. adding-a-securities-provider.md)
├── gsd-core/                             # GSD workflow scripts (internal)
├── gsd-file-manifest.json / gsd-install-state.json / .gsd-profile  # GSD install metadata
├── lib/                                  # Non-Rails-tied Ruby
│   ├── money.rb / money/                 # Custom money helpers
│   ├── feature_flags.rb                  # DB SSO + intro UI flags
│   ├── uuid_format.rb                    # UUID validation
│   ├── active_record_encryption_config.rb
│   ├── semver.rb
│   ├── assets/ / tasks/ / simplefin/ / generators/
├── log/                                  # Rails log output
├── mobile/                               # Mobile client (likely React Native or similar)
├── openspec/                             # OpenSpec proposals/changes
├── perf.rake                             # Performance profiling rake tasks
├── pipelock.example.yaml                 # Pipelock secret-allowlist example
├── Procfile.dev                          # web + css + worker
├── public/                               # Static files (compiled assets, PWA icons, robots.txt)
├── scripts/                              # One-off scripts
├── spec/                                 # RSpec (rswag + API request docs)
│   ├── rails_helper.rb / spec_helper.rb / swagger_helper.rb
│   └── requests/api/v1/                  # Rswag docs-only specs (one per API endpoint)
├── storage/                              # ActiveStorage local-disk root
├── test/                                 # Minitest (the actual test framework)
│   ├── controllers/                      # HTTP behavior tests (Minitest)
│   │   └── api/v1/                       # API behavior tests
│   ├── models/                           # Unit tests per model
│   ├── components/                       # ViewComponent tests
│   ├── policies/                         # Pundit policy tests
│   ├── jobs/                             # Sidekiq job tests
│   ├── services/                         # Service unit tests
│   ├── mailers/                          # Mailer tests
│   ├── system/                           # Capybara system tests
│   ├── integration/                      # Cross-controller integration tests
│   ├── fixtures/                         # YAML test fixtures
│   ├── support/                          # Shared test helpers
│   ├── vcr_cassettes/                    # Recorded HTTP responses
│   ├── javascript/                       # JS test stubs
│   ├── architecture/                     # Architecture-drift detector (e.g. api_current_usage_test.rb)
│   └── test_helper.rb
├── tmp/                                  # Cache, pid, sessions
├── vendor/                               # Vendor assets
└── workers/                              # Legacy/deprecated worker scripts
    └── preview/
```

## Directory Purposes

**`app/controllers/`:**
- Purpose: All HTTP entry points
- Contains: HTML controllers (Turbo-friendly), API controllers, webhooks, admin, settings
- Key files: `application_controller.rb`, `api/v1/base_controller.rb`, `webhooks_controller.rb`, `concerns/authentication.rb`, `concerns/entryable_resource.rb`

**`app/controllers/api/v1/`:**
- Purpose: Versioned JSON:API surface
- Contains: One controller per public resource; 30+ controllers
- Key files: `base_controller.rb` (auth + rate limit + scope + JSON envelope), `auth_controller.rb` (signup/login/refresh/sso), `transactions_controller.rb`, `chats_controller.rb`, `provider_connections_controller.rb`

**`app/controllers/concerns/`:**
- Purpose: Cross-cutting controller modules
- Contains: 20+ concerns. Notable: `authentication.rb`, `entryable_resource.rb`, `accountable_resource.rb`, `safe_pagination.rb`, `feature_guardable.rb`, `localize.rb`, `auto_sync.rb`, `impersonatable.rb`, `self_hostable.rb`
- Key files: `authentication.rb`, `entryable_resource.rb`, `api/v1/`

**`app/models/`:**
- Purpose: Domain layer (ActiveRecord + PORO services + concerns)
- Contains: 130+ top-level model files; polymorphic types `Accountable` / `Entryable`; namespaces `provider/`, `rule/`, `assistant/`, `import/`, `recurring_transaction/`, `category/`, `simplefin/`, `oidc/`
- Key files: `family.rb`, `user.rb`, `account.rb`, `entry.rb`, `transaction.rb`, `current.rb`, `setting.rb`, `sync.rb`

**`app/models/provider/`:**
- Purpose: Every third-party integration lives here
- Contains: `base.rb`, `factory.rb` (auto-discovery), `registry.rb` (concept-keyed), `configurable.rb`, `rate_limitable.rb`, `syncable.rb`, `security_concept.rb`, `llm_concept.rb`, `exchange_rate_concept.rb`, `institution_metadata.rb`. Then one file per provider (e.g. `plaid.rb`, `plaid_adapter.rb`, `simplefin.rb`, `simplefin_adapter.rb`, `openai.rb`, `anthropic.rb`, `twelve_data.rb`, `tiingo.rb`, `eodhd.rb`, `alpha_vantage.rb`, `binance_public.rb`, `moex_public.rb`, `mfapi.rb`, `tinkoff_invest.rb`, `yahoo_finance.rb`, `github.rb`, `coinbase.rb`, `kraken.rb`, `mercury.rb`, `snaptrade.rb`, `sophtron.rb`, `enable_banking.rb`, `indexa_capital.rb`, `brex.rb`, `coinstats.rb`, `up.rb`, `akahu.rb`, `ibkr_flex.rb`, `questrade.rb`, `lunchflow.rb`, `stripe.rb`).
- Key files: `base.rb`, `factory.rb`, `registry.rb`, `configurable.rb`

**`app/models/rule/`:**
- Purpose: Rule engine
- Contains: `registry.rb` (base), `registry/transaction_resource.rb`, `condition_filter.rb` + `condition_filter/transaction_*.rb` (8 filters), `action_executor.rb` + `action_executor/*.rb` (9 executors), `condition.rb`, `action.rb`
- Key files: `app/models/rule.rb`, `app/models/rule/registry/transaction_resource.rb`

**`app/models/assistant/`:**
- Purpose: AI assistant
- Contains: `base.rb`, `builtin.rb` (OpenAI/Anthropic), `external.rb` (proxied remote), `configurable.rb` (system prompt), `responder.rb` (streaming), `function_tool_caller.rb`, `token_estimator.rb`, `history_trimmer.rb`, `provided.rb`, plus `function/*.rb` (one file per LLM-callable tool) and `external/client.rb`
- Key files: `builtin.rb`, `function/`

**`app/models/import/`:**
- Purpose: Import staging
- Contains: `mapping.rb` (base), `account_mapping.rb`, `account_type_mapping.rb`, `category_mapping.rb`, `tag_mapping.rb`, `row.rb`, `preflight.rb`
- Key files: `app/models/import.rb` (top-level model), `app/models/import/row.rb`, `app/models/import/mapping.rb`

**`app/jobs/`:**
- Purpose: Sidekiq background work
- Contains: `application_job.rb`, sync jobs (`sync_job.rb`, `sync_all_job.rb`, `sync_all_providers_job.rb`, `sync_hourly_job.rb`, `sync_cleaner_job.rb`), import jobs (`import_job.rb`, `import_session_job.rb`, `process_pdf_job.rb`, `revert_import_job.rb`), AI jobs (`assistant_response_job.rb`, `auto_categorize_job.rb`, `auto_detect_merchants_job.rb`, `enhance_provider_merchants_job.rb`, `clear_ai_cache_job.rb`, `apply_all_rules_job.rb`), provider-specific fetch jobs (`questrade_activities_fetch_job.rb`, `indexa_capital_activities_fetch_job.rb`, `snaptrade_activities_fetch_job.rb`, `sophtron_initial_load_job.rb`, `sophtron_refresh_poll_job.rb`, `simplefin_connection_update_job.rb`, `simplefin_holdings_apply_job.rb`, `lunchflow_*.rb`), cleanup jobs (`data_cleaner_job.rb`, `debug_log_cleanup_job.rb`, `inactive_family_cleaner_job.rb`, `sweep_expired_goal_pledges_job.rb`, `security_health_check_job.rb`), household jobs (`family_data_export_job.rb`, `family_reset_job.rb`, `demo_family_refresh_job.rb`, `user_purge_job.rb`), `stripe_event_handler_job.rb`, `identify_recurring_transactions_job.rb`
- Key files: `application_job.rb`, `sync_job.rb`, `import_job.rb`, `assistant_response_job.rb`

**`app/components/DS/`:**
- Purpose: Design-system primitives
- Contains: Alert, Button (and buttonish), Dialog, Disclosure, EmptyState, FilledIcon, Link, Menu (with menu_controller.js), MenuItem, Pill, Popover (with popover_controller.js), ProgressRing, SearchInput, SegmentedControl, Tag, Tooltip. Each is `name.rb` + `name.html.erb` (and sometimes a paired JS controller).
- Key files: `DS/button.rb`, `DS/dialog.rb`, `DS/menu.rb`

**`app/components/UI/`:**
- Purpose: Higher-level UI components built on DS/*
- Contains: Compositions of DS primitives for repeated use
- Key files: varies

**`app/javascript/controllers/`:**
- Purpose: Stimulus controllers
- Contains: ~80 controllers, one per behavior (`chat_controller.js`, `bulk_select_controller.js`, `categorize_controller.js`, `account_type_selector_controller.js`, `bank_search_controller.js`, `budget_form_controller.js`, `attachment_upload_controller.js`, `cashflow_expand_controller.js`, `sankey_controller.js`, `transactions_filter_url.mjs`, `webauthn.js`, …)
- Key files: `application.js` (Stimulus boot), `chat_controller.js`, `transactions_filter_url.mjs`

**`app/mailers/`:**
- Purpose: ActionMailer
- Contains: `application_mailer.rb`, `email_confirmation_mailer.rb`, `password_mailer.rb`, `invitation_mailer.rb`, `pdf_import_mailer.rb`, `demo_family_refresh_mailer.rb`
- Key files: `application_mailer.rb`

**`app/middleware/omniauth_error_handler.rb`:**
- Purpose: Rack middleware catching OmniAuth/OIDC errors

**`app/policies/`:**
- Purpose: Pundit authorization policies
- Contains: `application_policy.rb`, `account_policy.rb`, `user_policy.rb`, `sso_provider_policy.rb`
- Key files: `application_policy.rb`

**`app/services/`:**
- Purpose: Cross-cutting infrastructure (deliberately small)
- Contains: `api_rate_limiter.rb`, `noop_api_rate_limiter.rb`, `auto_sync_scheduler.rb`, `provider_loader.rb` (SSO config DB-or-YAML loader)
- Key files: `auto_sync_scheduler.rb`, `provider_loader.rb`

**`app/data_migrations/`:**
- Purpose: One-off production data backfills
- Contains: `balance_component_migrator.rb`
- Run via `lib/tasks/data_migration.rake`

**`config/initializers/`:**
- Purpose: Boot-time Rails configuration
- Contains: 30+ initializers. Notable: `doorkeeper.rb`, `doorkeeper_csrf_protection.rb`, `doorkeeper_layout.rb`, `sidekiq.rb`, `omniauth.rb`, `auth.rb`, `plaid_config.rb`, `simplefin.rb`, `snaptrade.rb`, `lunchflow.rb`, `up.rb`, `rswag.rb`, `sentry.rb`, `langfuse.rb`, `posthog.rb`, `pagy.rb`, `rack_attack.rb`, `mini_profiler.rb`, `active_record_encryption.rb`, `encryption_warning.rb`, `cors.rb`, `content_security_policy.rb`, `permissions_policy.rb`, `active_storage_authorization.rb`, `assets.rb`, `inflections.rb`, `mime_types.rb`, `dialog_defaults.rb`, `brand.rb`, `codespaces.rb`, `00_ssl.rb`, `enable_yjit.rb`, `filter_parameter_logging.rb`, `generator.rb`, `version.rb`
- Key files: `doorkeeper.rb`, `sidekiq.rb`, `omniauth.rb`, `auth.rb`, `plaid_config.rb`, `rswag.rb`

**`config/locales/`:**
- Purpose: i18n translations
- Contains: One YAML per locale, plus per-namespace subdirs (`accounts.*`, `transactions.*`, `providers.*`, `ds.*`, `settings.*`)

**`config/`:**
- Purpose: Rails configuration
- Contains: `application.rb`, `boot.rb`, `environment.rb`, `routes.rb` (762 lines), `database.yml`, `storage.yml`, `cable.yml`, `sidekiq.yml`, `puma.rb`, `currencies.yml`, `exchanges.yml`, `auth.yml` (default SSO providers), `demo.yml` (demo hostnames), `schedule.yml` (sidekiq-cron), `i18n-tasks.yml`, `skylight.yml`, `brakeman.ignore`, `importmap.rb`, `credentials.yml.enc`

**`db/migrate/`:**
- Purpose: Rails migrations (one file per migration; never edit a merged migration)
- Each migration should be one concern and committed in the same commit as the model that uses it

**`db/seeds.rb` + `db/seeds/`:**
- Purpose: Seed data (incl. demo family)

**`spec/`:**
- Purpose: RSpec for rswag API docs
- Contains: `rails_helper.rb`, `spec_helper.rb`, `swagger_helper.rb`, `requests/api/v1/*_spec.rb`
- Rule: **rswag is docs-only.** No `expect`/`assert_*` in these specs. Behavioral coverage is in `test/controllers/api/v1/`.

**`test/`:**
- Purpose: Minitest — the actual test framework
- Contains: `test_helper.rb`, `application_system_test_case.rb`, `architecture/` (architecture-drift detectors), `channels/`, `components/`, `controllers/`, `controllers/api/v1/`, `data_migrations/`, `fixtures/`, `helpers/`, `i18n_test.rb`, `integration/`, `interfaces/`, `javascript/`, `jobs/`, `lib/`, `mailers/`, `migrations/`, `models/`, `policies/`, `services/`, `support/`, `system/`, `vcr_cassettes/`, `views/`
- Key files: `test_helper.rb`, `application_system_test_case.rb`, `architecture/api_current_usage_test.rb`

**`docs/`:**
- Purpose: User-facing, append-only documentation
- Contains: `api/openapi.yaml` (generated), `llm-guides/adding-a-securities-provider.md`, and other promoted phase artifacts
- Rule: **Never edit `docs/` directly.** All edits happen in `.planning/`; promotion is a one-way copy.

**`lib/`:**
- Purpose: Non-Rails-tied Ruby
- Contains: `money.rb` + `money/`, `feature_flags.rb`, `uuid_format.rb`, `active_record_encryption_config.rb`, `semver.rb`, `assets/`, `tasks/` (custom rake), `simplefin/`, `generators/`

**`public/`:**
- Purpose: Static files served as-is (PWA icons, robots.txt, favicon)

**`storage/`:**
- Purpose: ActiveStorage local-disk root (gitignored)

**`bin/`:**
- Purpose: Executable entrypoints
- Contains: `setup`, `dev`, `rails`, `rake`, `rubocop`, `brakeman`, `rspec`, `docker-entrypoint`, `importmap`, `update_structure.sh`, `render-build.sh`, `tokens.mjs`, `preview_deploy_security_check.rb`, `codex-env`

**`charts/`:**
- Purpose: Helm chart for production deployment

**`mobile/`:**
- Purpose: Mobile client (separate from web)

**`openspec/`:**
- Purpose: OpenSpec change proposals and designs

**`pipelock.example.yaml`:**
- Purpose: Pipelock (Git secret scanner) allowlist template

## Key File Locations

**Entry Points:**
- `config/routes.rb`: All HTTP routes (762 lines)
- `config/application.rb`: Rails app module + middleware stack
- `bin/dev`: Dev launcher (Foreman)
- `Procfile.dev`: web + css + worker
- `bin/setup`: Initial setup

**Configuration:**
- `config/database.yml`, `config/storage.yml`: persistence
- `config/cable.yml`: ActionCable adapter
- `config/sidekiq.yml`: Sidekiq queues
- `config/schedule.yml`: sidekiq-cron jobs
- `config/auth.yml`: Default SSO providers (overridable by `SsoProvider` model when `FeatureFlags.db_sso_providers?`)
- `config/currencies.yml`, `config/exchanges.yml`: Currency/exchange metadata
- `config/initializers/*.rb`: All cross-cutting config (Doorkeeper, OmniAuth, Plaid, SimpleFin, …)
- `.env.local.example`, `.env.test.example`, `.env.example`: Environment templates (secrets gitignored)

**Core Logic:**
- `app/models/family.rb`: Multi-tenant root
- `app/models/user.rb`: User model with encryption
- `app/models/account.rb`: Account aggregate
- `app/models/entry.rb`: Entry + delegated_type entryable
- `app/models/transaction.rb`: The most feature-rich entryable
- `app/models/concerns/accountable.rb`: Polymorphic account types
- `app/models/concerns/entryable.rb`: Polymorphic entry types
- `app/models/concerns/syncable.rb`: Sync orchestration
- `app/models/provider/base.rb`: Adapter contract
- `app/models/provider/factory.rb`: Adapter auto-discovery
- `app/models/provider/registry.rb`: Concept-keyed provider lookup
- `app/models/rule.rb` + `app/models/rule/registry/`: Rule engine
- `app/models/assistant/builtin.rb`: LLM assistant
- `app/models/current.rb`: Per-request global
- `app/models/setting.rb`: Dynamic per-instance config
- `app/controllers/application_controller.rb`: Root controller
- `app/controllers/api/v1/base_controller.rb`: API auth + envelope

**Testing:**
- `test/test_helper.rb`: Minitest setup
- `test/application_system_test_case.rb`: Capybara setup
- `test/fixtures/`: YAML fixtures
- `test/system/`: System tests
- `test/vcr_cassettes/`: Recorded HTTP
- `spec/swagger_helper.rb`: Rswag config
- `spec/requests/api/v1/`: Rswag docs-only specs
- `test/architecture/`: Architecture-drift detectors

**Build / Deploy:**
- `Dockerfile`, `Dockerfile.preview`: Multi-arch container builds
- `docker-compose.yml`, `compose.example.yml`, `compose.example.ai.yml`: Local dev
- `charts/`: Helm chart
- `bin/render-build.sh`: Render.com build hook
- `pipelock.example.yaml`: Secret-allowlist template

## Naming Conventions

**Files (Ruby):**
- Snake_case: `account.rb`, `current.rb`, `auto_sync_scheduler.rb`
- Namespaces use subdirectories: `app/models/provider/plaid.rb`, `app/models/rule/condition_filter/transaction_amount.rb`
- Concerns: `app/models/concerns/<feature>.rb` (e.g. `accountable.rb`, `syncable.rb`)
- Controller concerns: `app/controllers/concerns/<feature>.rb` (e.g. `authentication.rb`, `entryable_resource.rb`)
- ViewComponent: `app/components/<namespace>/<name>.rb` + `app/components/<namespace>/<name>.html.erb`

**Files (JS):**
- Snake_case: `chat_controller.js`, `transactions_filter_url.mjs`
- Stimulus controllers end in `_controller.js` (e.g. `bulk_select_controller.js`)

**Files (CSS):**
- Snake_case: `sure-design-system.css`, `date-picker-dark-mode.css`

**Directories:**
- Plural for resource collections: `app/controllers/api/v1/`, `app/models/`, `app/views/`
- Singular for concern namespaces: `app/controllers/concerns/`, `app/models/concerns/`, `app/services/`
- Lowercase for DSL namespaces: `app/components/DS/`, `app/components/UI/`

**Classes:**
- `CamelCase` for class/module names
- Models: singular noun (`Account`, `Transaction`, `Entry`, `Rule`)
- Controllers: plural resource + `Controller` (`AccountsController`, `TransactionsController`, `Api::V1::TransactionsController`)
- Jobs: `<Verb><Thing>Job` (`SyncJob`, `ImportJob`, `AssistantResponseJob`)
- Concerns: `<Adjective>` or `<Noun>` (e.g. `Syncable`, `Accountable`, `Monetizable`, `Reconcileable`, `AutoSync`, `SafePagination`)
- Services: `<Noun><Role>` (`AutoSyncScheduler`, `ProviderLoader`, `ApiRateLimiter`)

**Variables / Methods:**
- `snake_case` for instance methods, variables, file paths
- Predicate methods end in `?` (`syncable?`, `active?`, `pending?`)
- Dangerous methods end in `!` (`destroy!`, `save!`, `assign_default_owner!`)

**Polymorphic types:**
- `Account#accountable_type` stores the class name (`Depository`, `Investment`, `Crypto`, `Property`, `Vehicle`, `OtherAsset`, `CreditCard`, `Loan`, `OtherLiability`)
- `Entry#entryable_type` stores one of `Transaction`, `Valuation`, `Trade`

**Routes:**
- Resourceful: `resources :accounts, only: %i[index new show destroy], shallow: true do … end`
- Custom: `post :sync` (member) / `get :preload_accounts` (collection) / `direct :entry` for polymorphic paths

**Tests:**
- Minitest: `test/models/<model>_test.rb`, `test/controllers/<controller>_test.rb`, `test/system/<feature>_test.rb`, `test/jobs/<job>_test.rb`, `test/components/<component>_test.rb`
- RSpec (rswag only): `spec/requests/api/v1/<resource>_spec.rb`
- Architecture-drift detector: `test/architecture/<topic>_test.rb`

**Provider adapters:**
- Provider class: `Provider::<Name>` (e.g. `Provider::Plaid`, `Provider::Openai`, `Provider::TwelveData`, `Provider::Stripe`)
- Adapter class: `Provider::<Name>Adapter` (e.g. `Provider::PlaidAdapter`, `Provider::SimplefinAdapter`, `Provider::LunchflowAdapter`) — wraps a single provider account
- Local provider-account model: `<Name>Account` (e.g. `PlaidAccount`, `SimplefinAccount`, `LunchflowAccount`)
- Local provider-item model: `<Name>Item` (e.g. `PlaidItem`, `SimplefinItem`, `LunchflowItem`, `CoinbaseItem`, `SnaptradeItem`, `MercuryItem`, `BrexItem`, `SophtronItem`, `IndexaCapitalItem`, `QuestradeItem`, `AkahuItem`, `UpItem`, `CoinstatsItem`, `BinanceItem`, `KrakenItem`, `IbkrItem`, `EnableBankingItem`)

## Where to Add New Code

**New feature (user-facing):**
- Primary code: domain goes in `app/models/<thing>.rb` (or a `app/models/<thing>/` namespace if multi-file). Behavior mixing uses concerns in `app/models/concerns/`. Controllers in `app/controllers/<resources>_controller.rb` (HTML) or `app/controllers/api/v1/<resources>_controller.rb` (API). Use existing concerns (`Authentication`, `Pundit::Authorization`, `AccountAuthorizable`, `EntryableResource`, `AccountableResource`, `SafePagination`, `Onboardable`, `Localize`, `SelfHostable`, `Impersonatable`, `FeatureGuardable`, `Notifiable`, `PreviewGateable`, `RestoreLayoutPreferences`, `Invitable`, `Breadcrumbable`, `AutoSync`).
- Tests: Minitest in `test/models/<thing>_test.rb` + `test/controllers/<resources>_controller_test.rb` (+ API in `test/controllers/api/v1/<resources>_controller_test.rb` and `spec/requests/api/v1/<resources>_spec.rb` for OpenAPI). System tests in `test/system/<feature>_test.rb`. Architecture-drift check in `test/architecture/<topic>_test.rb` if cross-cutting.

**New account type (e.g. brokerage, HSA, prepaid card):**
- `app/models/<new_accountable>.rb` — inherit from `ApplicationRecord`, `include Accountable`, define `classification`, `icon`, `color`, optionally `SUBTYPES`.
- Add the class name to `Accountable::TYPES` in `app/models/concerns/accountable.rb`.
- Add `resources :<new_accountable_plural>` in `config/routes.rb` (typically just `new/create/edit/update`).
- Add a partial in `app/views/<new_accountable_plural>/`.
- Add `app/models/<new_accountable>.rb` translations in `config/locales/en.yml` under `accounts.types.<new_accountable>` and `accounts.types_plural.<new_accountable>`.

**New entryable type (rare; only if a new kind of finance event is needed):**
- `app/models/<new_entryable>.rb` — `include Entryable`, set `Entryable::TYPES << "<NewEntryable>"` (or in a concern), add a controller and views.
- Most new finance events are better modeled as a `Transaction` (use `extra` JSONB + a new `Tag`/`Category`/subclass) than a new entryable.

**New bank/brokerage/crypto provider:**
- `app/models/provider/<key>.rb` (API client) and `app/models/provider/<key>_adapter.rb` (single-account adapter that includes `Provider::Syncable` and/or `Provider::InstitutionMetadata` and calls `Provider::Factory.register("<Key>Account", self)` in the class body).
- `app/models/<key>_account.rb` (provider-side account) and `app/models/<key>_item.rb` (provider-side item, belongs to family, has_many accounts).
- `app/models/family/<key>_connectable.rb` (concern adding `has_many :<key>_items` and a `connect_<key>(…)` method). Include this concern in `app/models/family.rb`.
- `app/controllers/<key>_items_controller.rb` and a multi-step sub-namespace if needed (e.g. `app/controllers/brex_items/{account_flows,account_setups}_controller.rb`).
- `app/jobs/<key>_activities_fetch_job.rb` if polling is required.
- `config/initializers/<key>.rb` for runtime toggles.
- `app/components/DS/...` if a new UI shape emerges (e.g. device-flow dialog).
- Walkthrough: `docs/llm-guides/adding-a-securities-provider.md`.

**New LLM provider (or other concept-based provider):**
- `app/models/provider/<key>.rb` — inherit from `Provider::Base` (or use `Provider::Openai`/`Provider::Anthropic` for OpenAI-compatible APIs). Include `Provider::LlmConcept` and/or `Provider::SecurityConcept` / `Provider::ExchangeRateConcept` as appropriate.
- Add a private class method in `app/models/provider/registry.rb` (e.g. `def openai; …; end`) and add the symbol to `available_providers` for the matching concept.
- i18n: add provider display name to locales.

**New rule condition filter:**
- `app/models/rule/condition_filter/<resource>_<field>.rb` — implement the filter class.
- List it in `app/models/rule/registry/transaction_resource.rb#condition_filters`.

**New rule action executor:**
- `app/models/rule/action_executor/<verb>_<target>.rb` — implement the executor class.
- List it in `app/models/rule/registry/transaction_resource.rb#action_executors`.

**New LLM-callable function (assistant tool):**
- `app/models/assistant/function/<verb>_<target>.rb` — implement the function class.
- List it in `Assistant.function_classes` (or whichever registry `Assistant::Configurable.default_functions` consumes).

**New API endpoint:**
- Add to `config/routes.rb` under `namespace :api { namespace :v1 { … } }`.
- Add the controller at `app/controllers/api/v1/<resources>_controller.rb` (inherit from `Api::V1::BaseController`).
- Add Minitest behavioral coverage in `test/controllers/api/v1/<resources>_controller_test.rb`.
- Add rswag docs-only spec in `spec/requests/api/v1/<resources>_spec.rb`.
- Run `RAILS_ENV=test bundle exec rake rswag:specs:swaggerize` to regenerate `docs/api/openapi.yaml`.

**New scheduled job:**
- Add the job class in `app/jobs/<thing>_job.rb`.
- Add an entry to `config/schedule.yml`.

**New design-system primitive:**
- `app/components/DS/<name>.rb` + `app/components/DS/<name>.html.erb` (+ optional paired JS controller at `app/components/DS/<name>_controller.js`).
- Add functional tokens to `app/assets/tailwind/sure-design-system.css` (no raw Tailwind palette).
- Document in `app/components/DS/...` index.

**Utilities / shared Ruby:**
- Cross-cutting infrastructure: `app/services/<name>.rb` (use sparingly — current contents are `api_rate_limiter.rb`, `auto_sync_scheduler.rb`, `noop_api_rate_limiter.rb`, `provider_loader.rb`).
- Domain logic: a concern in `app/models/concerns/` or a module under `app/models/<namespace>/`.
- Generic helpers used outside Rails: `lib/<name>.rb` (e.g. `lib/uuid_format.rb`, `lib/feature_flags.rb`).

**Debug log entries (operator-facing):**
- Use `DebugLogEntry.capture(category:, level:, message:, source:, provider_key:, metadata:, family:, account_provider:)`. Surface at `/settings/debug`.

## Special Directories

**`docs/`:**
- Purpose: User-facing, append-only documentation
- Generated: Partially (`docs/api/openapi.yaml` is generated by `rswag:specs:swaggerize`)
- Committed: Yes
- Rule: Never edit directly. All edits happen in `.planning/`; promotion is a one-way copy.

**`openspec/`:**
- Purpose: OpenSpec change proposals and designs
- Generated: No
- Committed: Yes

**`mobile/`:**
- Purpose: Mobile client (separate from web)
- Generated: No
- Committed: Yes

**`gsd-core/`:**
- Purpose: GSD workflow scripts (internal tooling)
- Generated: No
- Committed: Yes

**`.planning/`:**
- Purpose: Project context (read-only from worktrees); planning artifacts that get promoted to `docs/`
- Generated: No
- Committed: Yes (`commit_docs: true`)

**`.worktrees/`:**
- Purpose: All GSD worktrees live here (one per phase/plan)
- Generated: No
- Committed: **No** — gitignored

**`storage/`:**
- Purpose: ActiveStorage local-disk root in development
- Generated: Yes
- Committed: No (gitignored)

**`tmp/`:**
- Purpose: Cache, pid, sessions
- Generated: Yes
- Committed: No (gitignored)

**`log/`:**
- Purpose: Rails log output
- Generated: Yes
- Committed: No (gitignored)

**`vendor/`:**
- Purpose: Vendor assets
- Generated: No
- Committed: Yes

**`public/`:**
- Purpose: Static files (PWA icons, robots.txt, compiled assets when used)
- Generated: Partially
- Committed: Yes

**`charts/`:**
- Purpose: Helm chart for production deployment
- Generated: No
- Committed: Yes

---

*Structure analysis: 2026-07-11*
