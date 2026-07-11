<!-- refreshed: 2026-07-11 -->
# Architecture

**Analysis Date:** 2026-07-11

## System Overview

Sure ("Sure Finances") is a multi-tenant personal-finance application built on **Rails 7.2 + Hotwire (Turbo + Stimulus)** with a JSON:API at `app/controllers/api/v1/`. The architecture is layered around three core domain primitives — **Family → Account → Entry/Entryable** — and a **Provider Adapter pattern** for every third-party data source (banks, brokerages, crypto exchanges, market data, LLMs).

```text
┌─────────────────────────────────────────────────────────────────────────┐
│                       Client (Browser / Mobile / API)                    │
│  Rails Views (ERB + Hotwire) │ JSON:API (api/v1) │ MCP (mcp_controller) │
└────────────────────────┬───────────────────────┬────────────────────────┘
                         │                       │
┌────────────────────────▼───────────────────────▼────────────────────────┐
│                            Controllers                                   │
│  application_controller.rb (concerns: Authentication, Pundit, AutoSync) │
│  ├── ui/* (Turbo Streams + ERB views)                                   │
│  ├── api/v1/base_controller.rb (Doorkeeper + API key, rate limit)        │
│  ├── admin/* (super_admin)                                               │
│  ├── settings/* (user self-service)                                      │
│  └── webhooks/* (plaid, plaid_eu, stripe)                                │
└────────────────────────┬────────────────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────────────────┐
│                  Domain Models (ActiveRecord)                            │
│  Family ─< User                                                          │
│  Family ─< Account (polymorphic accountable)                             │
│  Account ─< Entry (delegated_type entryable)                             │
│         └── Entryable ∈ {Transaction, Valuation, Trade}                  │
│  Family ─< Rule >─ Condition + Action (registry pattern)                 │
│  Family ─< Sync (state machine, polymorphic syncable)                   │
│  Family ─< Chat ─< Message (Assistant::Base)                             │
│  Family ─< Import / ImportSession / Import::Row / Import::Mapping        │
└────────────────────────┬────────────────────────────────────────────────┘
                         │
┌────────────┬───────────┴────────────┬──────────────────────────────────┐
│ Providers  │  Provider Adapters     │  Sidekiq Jobs (app/jobs/*)       │
│ (registry) │  (Plaid, SimpleFin,    │  SyncJob, ImportJob,             │
│            │   Lunchflow, SnapTrade │  AssistantResponseJob,           │
│            │   Coinbase, Kraken,    │  ImportMarketDataJob,            │
│            │   TwelveData, OpenAI,  │  ApplyAllRulesJob                │
│            │   Anthropic, …)        │                                  │
└────────────┴────────────────────────┴──────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| `Family` | Multi-tenant root; aggregates users, accounts, rules, imports, goals, budgets, chats, exports. Includes provider connectables. | `app/models/family.rb` |
| `User` | Belongs to family; owns accounts, sessions, api_keys, webauthn_credentials, mobile_devices, chats, sso identities, profile image. | `app/models/user.rb` |
| `Account` | Polymorphic parent of entries; includes `Syncable`, `Monetizable`, `Chartable`, `Linkable`, `Enrichable`, `Anchorable`, `Reconcileable`, `TaxTreatable`. | `app/models/account.rb` |
| `Entry` | One row per finance event; `delegated_type :entryable` polymorphically maps to `Transaction`, `Valuation`, or `Trade`. | `app/models/entry.rb` |
| `Transaction` | Includes `Entryable`, `Transferable`, `Ruleable`, `Splittable`. The most feature-rich entryable. | `app/models/transaction.rb` |
| `Provider::Base` | Abstract adapter contract for all third-party data integrations. | `app/models/provider/base.rb` |
| `Provider::Factory` | Auto-discovers `*_adapter.rb` files via Rails autoloading, self-registers them keyed by provider account class name (e.g. `PlaidAccount` → `Provider::PlaidAdapter`). | `app/models/provider/factory.rb` |
| `Provider::Registry` | Concept-keyed lookup (`exchange_rates`, `securities`, `llm`) and LLM provider preference resolution. | `app/models/provider/registry.rb` |
| `Sync` | AASM state machine (`pending → syncing → completed / failed / stale`) recording the result of one provider sync. | `app/models/sync.rb` |
| `Syncable` (concern) | Adds `sync_later`, `perform_sync`, `sync_broadcaster` to Account and family-scoped resources; deduplicates in-flight syncs. | `app/models/concerns/syncable.rb` |
| `Rule` | User-defined automation: `resource_type: "transaction"` dispatches to `Rule::Registry::TransactionResource` for the right condition filters and action executors. | `app/models/rule.rb` |
| `Assistant::Base` | Abstract assistant; subclasses `Assistant::Builtin` (uses OpenAI/Anthropic via `Provider::Registry`) and `Assistant::External` (proxies a remote assistant URL). | `app/models/assistant/base.rb` |
| `Assistant::Function` | Tool classes (`get_transactions`, `get_balance_sheet`, `create_goal`, …) that expose family data to the LLM. | `app/models/assistant/function/*.rb` |
| `Setting` | `RailsSettings::Base` dynamic per-instance config (LLM keys, provider selection, auto-sync, brand fetch, …). | `app/models/setting.rb` |
| `Current` | `ActiveSupport::CurrentAttributes` carrying `user_agent`, `ip_address`, and `session` for the request; resolves `Current.user` honoring impersonation. | `app/models/current.rb` |
| `Api::V1::BaseController` | API auth (OAuth via Doorkeeper + `X-Api-Key` API key), per-key rate limiting, scope checks (`read`/`read_write`), JSON error envelope. | `app/controllers/api/v1/base_controller.rb` |
| `ApplicationController` | Includes `Authentication`, `Pundit::Authorization`, `Pagy::Backend`, `Onboardable`, `Localize`, `AutoSync`, `SelfHostable`, `Impersonatable`, `FeatureGuardable`, `AccountAuthorizable`, `Notifiable`, `SafePagination`, `PreviewGateable`, `RestoreLayoutPreferences`, `Invitable`, `Breadcrumbable`. | `app/controllers/application_controller.rb` |
| `OmniauthErrorHandler` | Rack middleware rescuing `OpenIDConnect::Discovery::DiscoveryFailed` and `OmniAuth::Error` and redirecting to `/auth/failure?message=…`. | `app/middleware/omniauth_error_handler.rb` |

## Pattern Overview

**Overall:** Layered Rails MVC + Provider Adapter + Delegated Type + Registry of Concern Modules.

**Key Characteristics:**

- **Polymorphic `accountable` + `delegated_type` `entryable`.** An `Account` is `has_one :account, as: :accountable, touch: true` (see `app/models/concerns/accountable.rb`). An `Entry` uses Rails' `delegated_type :entryable, types: Entryable::TYPES` (`Transaction` | `Valuation` | `Trade`) so the same entry can represent any finance event. This is the central data-modeling pattern in the app.
- **Provider Adapter pattern with auto-registration.** Every third-party integration inherits `Provider::Base` and self-registers in `Provider::Factory` via a class-body `register` call. `Factory.create_adapter(provider_account)` is the single entry point that resolves a provider account to the right adapter — no per-provider branching in business code.
- **Concept-based provider registry.** `Provider::Registry.for_concept(:llm)` (or `:securities`, `:exchange_rates`) returns the list of enabled providers for that concept; LLM selection honors `Setting.llm_provider` with a graceful fallback (`Provider::Registry.preferred_llm_provider`).
- **Concern-as-feature module.** `Account` and `Family` opt into behavior via `include` (`Syncable`, `Monetizable`, `PlaidConnectable`, `SimplefinConnectable`, `LunchflowConnectable`, …). Each `*Connectable` concern is the only place that wires a model to a specific provider (e.g. `app/models/family/plaid_connectable.rb` adds `has_many :plaid_items` and `connect_plaid(...)`).
- **Rule engine as Registry of Condition Filters + Action Executors.** `Rule::Registry::TransactionResource` is a fixed composition of filters and executors. New ones are added by adding a file under `app/models/rule/condition_filter/` or `app/models/rule/action_executor/` and listing it in the registry.
- **AASM-backed `Sync` state machine.** The visual sync indicator in the UI is `syncs.visible.any?` (`Sync::VISIBLE_FOR = 5.minutes`). Stale syncs are GC'd at `STALE_AFTER = 24.hours`.
- **ApplicationController is built from a stack of 14+ concerns.** Anything that affects "every controller" is a concern in `app/controllers/concerns/`. Sub-controllers override behavior with `skip_authentication`, `skip_before_action`, or `helper_method`.
- **JS via Importmap + Stimulus + Turbo.** No bundler; controllers in `app/javascript/controllers/` are loaded by importmap (`config/importmap.rb`); `app/javascript/application.js` boots Turbo and the HwCombobox fix.

## Layers

**Models (domain layer):**
- Purpose: All domain logic and persistence
- Location: `app/models/`
- Contains: ActiveRecord models, PORO services (e.g. `app/models/provider/*.rb`, `app/models/rule/condition_filter/*.rb`), ActiveModel form objects, polymorphic type modules (`Entryable`, `Accountable`)
- Depends on: ActiveRecord, `lib/money.rb`, `lib/feature_flags.rb`, `lib/uuid_format.rb`
- Used by: Controllers, Jobs, Views, API serializers

**Controllers (HTTP layer):**
- Purpose: Request handling, auth, parameter coercion, response rendering
- Location: `app/controllers/` (namespaced `api/v1/`, `admin/`, `settings/`, `transactions/`, `import/`, `brex_items/`, `webhooks/`, `snaptrade_items/`, …)
- Contains: ERB-rendering HTML controllers, JSON API controllers, webhook receivers
- Depends on: Models, controller concerns, Pundit, Pagy, Pundit
- Used by: The HTTP boundary and Sidekiq jobs that need to broadcast Turbo Streams

**Views (presentation):**
- Purpose: ERB templates + ViewComponent (`app/components/`)
- Location: `app/views/`, `app/components/` (`DS/*` is the design-system primitive set)
- Contains: ERB partials, ViewComponent classes, Tailwind CSS, custom Stimulus controllers
- Depends on: Models (read-only), helpers (`app/helpers/`), I18n
- Used by: Controllers (HTML format)

**Jobs (background processing):**
- Purpose: Sidekiq jobs for sync, import, AI, scheduled cleanup
- Location: `app/jobs/`
- Contains: ApplicationJob subclasses, per-provider pollers (`IndexaCapitalActivitiesFetchJob`, `SnaptradeActivitiesFetchJob`, `QuestradeActivitiesFetchJob`, `SophtronInitialLoadJob`, `SimplefinConnectionUpdateJob`)
- Depends on: Models, Providers, Providers registry
- Used by: `Syncable#sync_later`, `config/schedule.yml` (sidekiq-cron), `AssistantResponseJob` for async LLM turns

**JavaScript (client):**
- Purpose: Stimulus controllers, Turbo Stream handling, PWA service worker registration
- Location: `app/javascript/{controllers,services,utils,shims}/`
- Contains: Stimulus controllers (e.g. `chat_controller.js`, `bulk_select_controller.js`, `categorize_controller.js`), hotwire_combobox race-condition fix, service-worker registration
- Depends on: `@hotwired/turbo-rails`, `@hotwired/stimulus`, `hotwire_combobox`
- Used by: Mounted via `app/javascript/application.js`; `app/javascript/controllers/application.js` boots Stimulus

**Middleware:**
- Purpose: Rack middleware
- Location: `app/middleware/omniauth_error_handler.rb`
- Contains: OmniAuth error rescue → 302 to `/auth/failure`
- Depends on: `omniauth` stack
- Used by: Mounted in `config/application.rb`

**Mailers:**
- Purpose: Transactional email
- Location: `app/mailers/`
- Contains: `ApplicationMailer`, `DemoFamilyRefreshMailer`, `EmailConfirmationMailer`, `InvitationMailer`, `PasswordMailer`, `PdfImportMailer`
- Depends on: ActionMailer
- Used by: Controllers (invitation, password reset, email confirmation, PDF import completion)

**Data Migrations:**
- Purpose: One-off production data backfills (separate from schema migrations)
- Location: `app/data_migrations/balance_component_migrator.rb` (single file; pattern lives in `lib/tasks/data_migration.rake`)

**Channels:**
- Purpose: ActionCable channel scaffolding
- Location: `app/channels/application_cable/{channel,connection}.rb`
- Contains: `ApplicationCable::Channel`, `ApplicationCable::Connection` (both currently minimal)

## Data Flow

### Primary Request Path (web UI)

1. **Entry point:** `config/routes.rb` matches the URL. Most app routes are mounted at root or under shallow namespaces. The root route is `root "pages#dashboard"` (line 761).
2. **Authentication:** `ApplicationController` includes `Authentication` (`app/controllers/concerns/authentication.rb`), which runs `before_action :authenticate_user!` → `find_session_by_cookie` → sets `Current.session = session_record`. `Current.user` resolves to the impersonated user when an impersonation session is active (`app/models/current.rb`).
3. **Pundit authorization:** `pundit_user` returns `Current.user`. Policy classes live in `app/policies/`.
4. **Business logic:** Controllers call models directly. Complex work (sync, import, AI) enqueues Sidekiq jobs.
5. **Response:** For Turbo-enabled forms, controllers render Turbo Streams (`app/controllers/concerns/stream_extensions.rb`, `app/javascript/application.js` extends `Turbo.StreamActions` with a `redirect` action). For full-page loads, ERB views in `app/views/` render.

### API Request Path (`/api/v1/*`)

1. **Entry point:** `config/routes.rb` lines 533–604 mount `namespace :api { namespace :v1 { … } }`.
2. **Auth:** `Api::V1::BaseController` (`app/controllers/api/v1/base_controller.rb`) overrides `skip_authentication`, skips CSRF, forces JSON, then runs `authenticate_request!`:
   - First tries **OAuth** via `Doorkeeper::AccessToken.by_token` (header `Authorization: Bearer …`).
   - Then tries **API key** via `X-Api-Key` header → `ApiKey.find_by_value` → records `api_key.update_last_used!`.
3. **Rate limiting:** `check_api_key_rate_limit` delegates to `app/services/api_rate_limiter.rb` (a no-op for OAuth tokens). Rate-limit headers (`X-RateLimit-Limit`, `-Remaining`, `-Reset`, `Retry-After`) are set on every response.
4. **Scope check:** Controllers call `ensure_read_scope` / `authorize_scope!(:write)` for hierarchical scope resolution (`read_write` ⊇ `read`).
5. **Family access control:** `ensure_current_family_access(resource)` rejects cross-family access.
6. **Response:** All endpoints return JSON via `render_json(data, status:)`. Error envelope: `{ error: "code", message: "...", details?: {...} }`.

### Bank Sync Flow

1. User triggers sync (button on a provider item page → e.g. `POST /plaid_items/:id/sync`).
2. `PlaidItemsController#sync` calls `current_family.plaid_items.find(params[:id]).sync_later`.
3. `PlaidItem` (which includes the provider connectable concern on `Family`) responds via `Syncable#sync_later` (`app/models/concerns/syncable.rb`):
   - Acquires `with_lock`.
   - Reuses a `Sync` in `visible` state (created in the last 5 min) by expanding its window, or creates a new one.
   - Enqueues `SyncJob.perform_later(sync)`.
4. `SyncJob` calls `sync.syncable.perform_sync(sync)`. The `syncable` is the provider item (e.g. `PlaidItem`).
5. The provider item's adapter (resolved via `Provider::Factory.create_adapter`) calls the upstream API, normalizes the payload to internal `Account`/`Entry`/`Transaction` models, and records a `Sync` per child item.
6. `SyncCleanerJob` (cron, hourly — `config/schedule.yml`) marks any sync older than `STALE_AFTER = 24.hours` as `stale`.

### AI Chat Flow

1. User posts a message: `POST /chats/:chat_id/messages` (web) or `POST /api/v1/chats/:chat_id/messages`.
2. `MessagesController#create` creates a `UserMessage` and enqueues `AssistantResponseJob`.
3. `AssistantResponseJob` resolves the assistant: `Assistant::Builtin.for_chat(chat)` (if `family.assistant_type == "builtin"`) or `Assistant::External.new(chat, …)`.
4. `Assistant::Builtin#respond_to` (`app/models/assistant/builtin.rb`):
   - Calls `Provider::Registry.preferred_llm_provider` → `Provider::Openai` or `Provider::Anthropic`.
   - Constructs `Assistant::Responder` and `Assistant::FunctionToolCaller` from `functions.map { |fn| fn.new(chat.user) }`.
   - Streams `output_text` events into an `AssistantMessage` (persisted as content is appended).
   - Handles function-tool calls by invoking the matching `Assistant::Function` (e.g. `get_transactions`, `create_goal`) and re-issuing the request with tool results.
5. The web UI uses `chat_controller.js` to subscribe to Turbo Streams that broadcast message updates.

### Import Flow (CSV / PDF / QIF / Mint / YNAB / Sure / Transaction Import)

1. User uploads a file via `ImportsController` (file rendered at `app/views/imports/`).
2. `ImportJob` parses the file (`MintImport`, `YnabImport`, `QifImport`, `SureImport`, `PdfImport`, or generic `TransactionImport`).
3. For PDFs, `ProcessPdfJob` runs the LLM over the document via `Provider::Registry.preferred_llm_provider`.
4. The import is staged in `ImportSession` + `Import::Row` + `Import::Mapping` (`account_mapping`, `category_mapping`, `tag_mapping`).
5. User reviews on the `confirm` page and clicks `publish`, which materializes `Account`/`Entry`/`Transaction` rows and revs `Family#last_synced_at`.

### Webhook Flow

- `POST /webhooks/plaid` → `Plaid::WebhookHandler` (Plaid US)
- `POST /webhooks/plaid_eu` → Plaid EU
- `POST /webhooks/stripe` → `StripeEventHandlerJob` enqueues async processing
- All webhook controllers are in `app/controllers/webhooks_controller.rb` and dispatch to per-provider handlers.

**State Management:**

- Server-side: per-request state lives in `Current` (`app/models/current.rb`); impersonation state lives on the `Session` model; multi-tenant isolation is by `family_id` on every domain model.
- Client-side: minimal — Stimulus controllers use element data attributes; no Redux/store pattern. The closest thing to a "store" is `Current.user.last_viewed_chat` (`User#last_viewed_chat`) which drives the default chat shown on the dashboard.

## Key Abstractions

**`Accountable` (concern, polymorphic):**
- Purpose: Marks a model as a type of financial account (Depository, Investment, Crypto, Property, Vehicle, OtherAsset, CreditCard, Loan, OtherLiability). See `TYPES` in `app/models/concerns/accountable.rb`.
- Examples: `app/models/depository.rb`, `app/models/investment.rb`, `app/models/credit_card.rb`, `app/models/loan.rb`, `app/models/crypto.rb`, `app/models/property.rb`, `app/models/vehicle.rb`, `app/models/other_asset.rb`, `app/models/other_liability.rb`
- Pattern: `Account has_one :account, as: :accountable, touch: true`. Each accountable subclass defines `classification` ("asset"/"liability"), `icon`, `color`, and (optionally) `SUBTYPES`. Use this for any new "type of account" you add — do NOT special-case the type in controllers; route via `Account.accountable_name` → `route_for "#{accountable_name.pluralize}"` (see `direct :edit_account` in `config/routes.rb` line 503).

**`Entryable` (concern, polymorphic):**
- Purpose: Marks a model as a kind of entry that lives inside `Entry`. Types: `Transaction`, `Valuation`, `Trade`.
- Examples: `app/models/transaction.rb`, `app/models/valuation.rb`, `app/models/trade.rb`
- Pattern: `Entry has_one :entry, as: :entryable, touch: true, dependent: :destroy` via Rails `delegated_type`. Use this for any new "kind of finance event" so it inherits the standard scopes (`in_period`, `reverse_chronological`, `chronological`, `visible`).

**`Provider::Base` + `Provider::Factory` + `Provider::Registry`:**
- Purpose: One uniform shape for every third-party integration (bank, broker, crypto exchange, market data, LLM, Stripe, GitHub).
- Examples: `app/models/provider/{plaid_adapter,simplefin_adapter,lunchflow_adapter,openai,anthropic,twelve_data,tiingo,stripe}.rb` and many more in `app/models/provider/`.
- Pattern: Inherit `Provider::Base`, implement `provider_name`, `include Provider::Syncable` and/or `Provider::InstitutionMetadata` if applicable, and add `Provider::Factory.register("YourProviderAccount", self)` in the class body. For concept-keyed (LLM/securities/exchange-rate) providers, register in `Provider::Registry` instead. See `docs/llm-guides/adding-a-securities-provider.md` for the walkthrough.

**`*Connectable` concerns on `Family`:**
- Purpose: Glue a `Family` to a specific provider's local models and connection flow.
- Examples: `app/models/family/plaid_connectable.rb`, `simplefin_connectable.rb`, `lunchflow_connectable.rb`, `akahu_connectable.rb`, `enable_banking_connectable.rb`, `coinbase_connectable.rb`, `binance_connectable.rb`, `kraken_connectable.rb`, `coinstats_connectable.rb`, `snaptrade_connectable.rb`, `mercury_connectable.rb`, `brex_connectable.rb`, `sophtron_connectable.rb`, `indexa_capital_connectable.rb`, `ibkr_connectable.rb`, `up_connectable.rb`, `questrade_connectable.rb`
- Pattern: Each adds `has_many :<provider>_items`, `<provider>_items` association helpers, and a `connect_<provider>(...)` instance method that builds the link between the family and the upstream item. The web controller for that provider item (`app/controllers/<provider>_items_controller.rb`) handles the OAuth/credential collection flow.

**`Rule::Registry::TransactionResource`:**
- Purpose: Single composition object that exposes the right `condition_filters` and `action_executors` for a transaction-scoped `Rule`.
- Examples: `app/models/rule/registry/transaction_resource.rb`. Underlying primitives in `app/models/rule/condition_filter/transaction_*.rb` and `app/models/rule/action_executor/*.rb`.
- Pattern: Add a new filter or executor by adding the file and listing it in the registry's `condition_filters` / `action_executors` array.

**`Assistant::Function` (tool classes):**
- Purpose: One LLM-callable function per capability. `Assistant::Builtin` instantiates them with `chat.user` so the function only sees data the user is allowed to see.
- Examples: `app/models/assistant/function/get_balance_sheet.rb`, `get_transactions.rb`, `create_goal.rb`, `create_category.rb`, `create_tag.rb`, `import_bank_statement.rb`, `search_family_files.rb`, …
- Pattern: Add a new function by adding a class that responds to the LLM tool-calling contract and listing it in `Assistant.function_classes` (the source consumed by `Assistant::Configurable.default_functions`).

**`DS::*` ViewComponents:**
- Purpose: Design-system primitives (Alert, Button, Dialog, Disclosure, Menu, Pill, Popover, ProgressRing, SegmentedControl, SearchInput, Tag, Tooltip, …). See `app/components/DS/`.
- Pattern: ALWAYS use `DS::*` instead of hand-rolled HTML for these shapes. The repo's `AGENTS.md` "Design System Hygiene" section makes this a reviewer-enforced rule.

## Entry Points

**Web entry point:**
- Location: `config/routes.rb` → `root "pages#dashboard"` and the `Rails.application.routes.draw do` block in `config/routes.rb`.
- Triggers: HTTP request → Rack → Rails router → `ApplicationController#before_action` chain (`detect_os`, `set_default_chat`, `set_active_storage_url_options`, then `Authentication#authenticate_user!`).
- Responsibilities: Route matching, authentication, Pundit authorization, controller action, response.

**API entry point:**
- Location: `app/controllers/api/v1/base_controller.rb` (mounted at `/api/v1/`).
- Triggers: HTTP request with `Authorization: Bearer` (OAuth) or `X-Api-Key` header.
- Responsibilities: Auth, rate limit, scope check, family access check, JSON response with consistent error envelope.

**Webhooks:**
- `app/controllers/webhooks_controller.rb` → `POST /webhooks/plaid`, `POST /webhooks/plaid_eu`, `POST /webhooks/stripe`.

**MCP (Model Context Protocol):**
- `POST /mcp` → `McpController#handle` (`app/controllers/mcp_controller.rb`). JSON-RPC 2.0 endpoint for external AI assistants. Auth via `X-Api-Key` or session.

**OAuth / OIDC:**
- `GET /auth/mobile/:provider` → `SessionsController#mobile_sso_start`
- `GET|POST /auth/:provider/callback` → `SessionsController#openid_connect`
- `GET /auth/failure` → `SessionsController#failure`
- `GET .well-known/oauth-protected-resource` and `GET .well-known/oauth-authorization-server` → `OauthMetadataController`
- `POST /register` → `OauthRegistrationController#create`
- `use_doorkeeper` at root — Doorkeeper issues the access tokens consumed by the JSON API

**Sidekiq scheduler entry points:**
- `config/schedule.yml` — sidekiq-cron entries (`ImportMarketDataJob`, `SyncCleanerJob`, `SyncHourlyJob`, `SecurityHealthCheckJob`, `DataCleanerJob`, `DebugLogCleanupJob`, `InactiveFamilyCleanerJob`, `DemoFamilyRefreshJob`, `SweepExpiredGoalPledgesJob`).
- `AutoSyncScheduler` (`app/services/auto_sync_scheduler.rb`) — manages a separate user-configurable daily `SyncAllJob` cron based on `Setting.auto_sync_time` and `Setting.auto_sync_timezone`.

**Sidekiq web UI:**
- `mount Sidekiq::Web => "/sidekiq" unless Rails.env.production?` (basic auth via `config/initializers/sidekiq.rb`).

**Rswag / API docs (dev only):**
- `mount Rswag::Api::Engine` and `mount Rswag::Ui::Engine` at `/api-docs` in `Rails.env.development?`. Rswag specs in `spec/requests/api/v1/*_spec.rb`. Generated output at `docs/api/openapi.yaml`. **rswag is docs-only** — behavioral coverage lives in `test/controllers/api/v1/*_controller_test.rb` (Minitest).

**Design system:**
- `mount Lookbook::Engine, at: "/design-system" unless Rails.env.production?` for browsing `DS::*` components.

**PWA:**
- `GET /service-worker` and `GET /manifest` → `PwaController`.

**Health check:**
- `GET /up` → `Rails::HealthController#show`.

## Architectural Constraints

- **Threading:** Single-threaded Puma worker model (default Rails). Background work is dispatched to Sidekiq, not threaded inline. ActionCable channels exist in `app/channels/application_cable/` but no real-time channel is currently shipped — Turbo Streams carry the real-time UX instead.
- **Global state:** `Current` (ActiveSupport::CurrentAttributes) is the only per-request global. `Setting` is a RailsSettings-backed singleton (cached at `v1` prefix). Sidekiq-cron job state lives in Redis (`Sidekiq::Cron::Job`).
- **Authorization is family-scoped, not user-scoped.** Almost every resource carries `family_id` directly, and `ensure_current_family_access(resource)` is the API equivalent. UI scoping uses `Current.family` (a delegate on `Current.user`).
- **Polymorphic indirection in the data model.** Two parallel polymorphic patterns are central: `Account#accountable` (Depository, Investment, …) and `Entry#entryable` (Transaction, Valuation, Trade). New code that adds a new "kind of account" or "kind of entry" MUST follow the pattern (concern + `delegate`/`delegated_type` + view-component icons + i18n) — do not special-case in controllers.
- **Provider integration is mandatory to register in `Provider::Factory`.** A new provider adapter that does not call `Provider::Factory.register("XxxAccount", self)` will not be discovered.
- **Provider configuration lives in two places:** ENV (highest priority) and `Setting.*` (user-overridable from `/settings/hosting`). Resolution happens at read time in `Provider::*` constructors.
- **Authentication for the web app is cookie-based** (`Session` model, `cookies.signed[:session_token]`). The API uses Doorkeeper OAuth or `X-Api-Key` headers. There is no shared "Bearer" code path between web and API.
- **Impersonation is a first-class concept** (`app/models/impersonation_session.rb`, `ImpersonationSessionLog`, `Current.impersonated_user`). SSO audit logs are at `SsoAuditLog`.
- **Currency handling is per-family, per-account.** `Monetizable` concern (`app/models/concerns/monetizable.rb`) handles conversion. `Family#currency` is the display/aggregation currency; foreign-currency goals are filtered out of `savings_inflow_velocity` (see comment in `app/models/family.rb:54-67`).
- **i18n:** All user-facing strings use `t()`. The locales directory lives at `config/locales/`. There's an `i18n-tasks` config at `config/i18n-tasks.yml`.

## Anti-Patterns

### `savings_inflow_velocity` re-queried on every KPI tile

**What happens:** `Family#savings_inflow_velocity` runs an `Entry` join with `INNER JOIN transactions` and a `sum(:amount)`. The KPI tile reads it for both the current 30-day window and the prior 30-day window, so the underlying `goal_linked_account_ids` query ran twice per request.
**Why it's wrong:** Wasted query, slower page load.
**Do this instead:** Use `Family#savings_inflow_windows(window_days:, now:)` (defined right next to it in `app/models/family.rb:86-92`) which memoizes the account-id lookup and computes both windows in one shot. New family-aggregating methods should follow the same "single helper, two windows" pattern.

### Hand-rolled UI shape instead of `DS::*`

**What happens:** A view ships a custom-styled button/alert/menu in raw Tailwind.
**Why it's wrong:** Breaks visual consistency; bloats the diff; forces the next two PRs to do the same. `AGENTS.md` "Design System Hygiene" rule (1)–(4) makes this a reviewer-reject.
**Do this instead:** Reach for `app/components/DS/{alert,button,dialog,disclosure,menu,pill,popover,progress_ring,segmented_control,search_input,tag,tooltip}.rb` first. If the shape doesn't exist, add a new `DS::*` primitive before the second copy lands.

### Using `params[:page].to_i` directly

**What happens:** Pagy-style direct `params[:page]` use in a controller.
**Why it's wrong:** Doesn't bound the page or per-page, can DOS the DB.
**Do this instead:** Use the `SafePagination` concern (`app/controllers/concerns/safe_pagination.rb`) and the `safe_page_param` / `safe_per_page_param` helpers from `Api::V1::BaseController`.

### Bypassing `Provider::Factory` / `Provider::Registry`

**What happens:** A new provider adapter is instantiated directly with `Provider::PlaidAdapter.new(...)` in business code, or a new securities provider adds a hard-coded branch in `MarketDataImporter`.
**Why it's wrong:** Defeats the registration pattern; breaks the auto-discovery of new adapters and the concept-based registry lookup.
**Do this instead:** Instantiate via `Provider::Factory.create_adapter(provider_account)` (for account-bound adapters) or `Provider::Registry.for_concept(:llm).get_provider(:openai)` / `Provider::Registry.preferred_llm_provider` (for LLM/utility providers).

### Recording operational diagnostics in `Rails.logger`

**What happens:** A provider sync/import path logs a recoverable error or suspicious partial response via `Rails.logger.warn`.
**Why it's wrong:** Support can't surface it in the `/settings/debug` UI.
**Do this instead:** Use `DebugLogEntry.capture(...)` with `category`, `level`, `message`, `source`, `provider_key`, and structured `metadata` — include `family` and `account_provider` when available. See `AGENTS.md` "Debug Logging for Provider Syncs".

### Service-object sprawl in `app/services/`

**What happens:** New Ruby code goes into `app/services/<name>.rb` as a growing grab-bag of POROs.
**Why it's wrong:** `app/services/` is intentionally sparse in this codebase (currently `api_rate_limiter.rb`, `auto_sync_scheduler.rb`, `noop_api_rate_limiter.rb`, `provider_loader.rb`). Domain logic lives in `app/models/*` and concerns; services are reserved for cross-cutting infrastructure (rate limiting, scheduling, multi-source config loading).
**Do this instead:** Put domain logic in `app/models/<thing>.rb` or a `app/models/<thing>/` namespace (see `app/models/provider/`, `app/models/rule/`, `app/models/assistant/`, `app/models/import/`, `app/models/recurring_transaction/`). Use `app/services/` only for true infrastructure concerns.

## Error Handling

**Strategy:** Mix of `rescue_from` in controllers, `Provider::Error` data class for provider wrappers, AASM-driven state machines for long-running operations, and `DebugLogEntry.capture` for operator-facing diagnostics.

**Patterns:**
- **Web controllers:** `ApplicationController` does not have a global `rescue_from`; controllers raise freely. Pundit raises `Pundit::NotAuthorizedError` which Rails converts to a 403 in production. View layer renders `flash[:alert]` from `t("shared.require_admin")` etc.
- **API controllers:** `Api::V1::BaseController` has `rescue_from` for `ActiveRecord::RecordNotFound`, `Doorkeeper::Errors::DoorkeeperError`, `ActionController::ParameterMissing`, and a local `InvalidFilterError`. All return JSON envelopes via `render_json`.
- **Provider adapters:** Wrap the upstream call in `with_provider_response` (`app/models/provider.rb`); a `Provider::Response` is `Data.define(:success?, :data, :error)`. Errors are transformed by `default_error_transformer` (Faraday errors get the response body; everything else is wrapped in a `Provider::Error` with the original message).
- **Sync state machine:** `Sync` (AASM) moves through `pending → syncing → completed / failed / stale`. The `stale` state is set by `SyncCleanerJob` for any sync older than 24h.
- **Background jobs:** `ApplicationJob` retries with Sidekiq's default. AI job errors land on the `Chat` via `chat.add_error(e)` (`app/models/assistant/builtin.rb:67`); partially-streamed messages are demoted to `status: "failed"` so history rebuilds skip them.
- **Debug log:** `DebugLogEntry.capture(category:, level:, message:, source:, provider_key:, metadata:)` is the operator-facing diagnostic stream. Surfaced at `/settings/debug`. Use this for "support will need to look at this" events.

## Cross-Cutting Concerns

**Logging:**
- `Rails.logger` for low-value local noise.
- `DebugLogEntry.capture` for operator-relevant diagnostics (see `app/models/debug_log_entry.rb`).
- Langfuse for LLM observability (config in `config/initializers/langfuse.rb`).
- Sentry for error tracking (config in `config/initializers/sentry.rb`).
- PostHog for product analytics (config in `config/initializers/posthog.rb`).
- Mini Profiler enabled in dev for query inspection (`config/initializers/mini_profiler.rb`).

**Validation:**
- ActiveRecord validators on every model.
- Strong parameters in every controller.
- `Accountable` adds shared validation patterns for accountable types.
- For the API, `Api::V1::BaseController#render_validation_error` returns a consistent 422 envelope with `error: "validation_failed"` and an `errors` array.
- `UuidFormat.valid?` (`lib/uuid_format.rb`) is the single UUID validator; used by `Api::V1::BaseController.valid_uuid?` and referenced in route param validation.

**Authentication & Authorization:**
- Web: cookie session via `Session` model + `Authentication` concern. MFA via `MfaController` + WebAuthn. SSO via OmniAuth + custom `OmniauthErrorHandler` middleware.
- API: Doorkeeper OAuth + `X-Api-Key` (with `ApiRateLimiter`).
- Authorization: Pundit (`policies/`); family-scoped checks via `Current.family` and `ensure_current_family_access`.
- Impersonation: `ImpersonationSession` model, with explicit approve/reject/complete workflow.
- Super admin: `User#role` enum (`guest`, `member`, `admin`, `super_admin`); `require_admin!` on `ApplicationController`.

**Audit:**
- `SsoAuditLog` for SSO events.
- `ImpersonationSessionLog` for impersonation events.
- `DebugLogEntry` for operator-visible app diagnostics.

**Feature flags:**
- `lib/feature_flags.rb` exposes `FeatureFlags.db_sso_providers?` (drives whether `ProviderLoader` reads `SsoProvider` from DB or YAML) and `FeatureFlags.intro_ui?` (drives the `intro` vs `dashboard` UI layout).
- `FeatureGuardable` concern gates controller actions behind flags.

**Encryption:**
- `ActiveRecord::Encryption` is wired in `config/initializers/active_record_encryption.rb`. `Encryptable` concern (`app/models/concerns/encryptable.rb`) is the standard wrapper. Used for `User#email`, `User#otp_secret`, MFA secrets, etc.
- `config/initializers/encryption_warning.rb` warns at boot if encryption keys are missing.

**Permissions policy:**
- `config/initializers/permissions_policy.rb` for browser feature policy headers.

**CORS:**
- `config/initializers/cors.rb`.

**Content Security Policy:**
- `config/initializers/content_security_policy.rb`.

**Rate limiting:**
- Rack::Attack in `config/initializers/rack_attack.rb`.
- Per-API-key: `ApiRateLimiter` + `NoopApiRateLimiter` (for OAuth) in `app/services/`.

---

*Architecture analysis: 2026-07-11*
