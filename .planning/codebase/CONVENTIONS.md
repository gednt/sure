# Coding Conventions

**Analysis Date:** 2026-07-11

## Naming Patterns

**Files (Ruby):**
- snake_case for everything: `account_import_test.rb`, `simplefin_item/syncer.rb`
- Plural directory names for collections of models: `app/models/akahu_account/`, `app/controllers/admin/`
- Namespaced by directory, **not** by filename: `app/models/akahu_item/importer.rb` defines `AkahuItem::Importer`
- Singletons / single-instance services drop the suffix: `app/services/provider_loader.rb` → `ProviderLoader`
- Test files mirror source names with `_test` suffix: `app/models/account.rb` → `test/models/account_test.rb`

**Files (JavaScript):**
- snake_case for filenames, even though Hotwire/Stimulus allows kebab-case: `app/javascript/controllers/auto_open_controller.js` → `data-controller="auto-open"`
- `*_controller.js` suffix is mandatory — the eager loader (`eagerLoadControllersFrom` in `app/javascript/controllers/index.js`) glob-matches `controllers/**/*_controller`
- `.mjs` extension for ESM modules that import via `import`: `app/javascript/utils/sankey_zoom.mjs`, `app/javascript/utils/transactions_filter_url.mjs`
- `.js` extension for everything else, including Stimulus controllers that use ESM `import`/`export` (loaded via importmap)

**Functions / Methods:**
- Ruby uses `snake_case`; predicate / boolean methods end with `?` (`account.linked?`, `transaction.pending?`)
- Mutating / bang methods end with `!` (`@transfer.destroy!`, `Setting.clear_cache`)
- Class-level factories end with `_and_sync` / `Creator` / `Builder` (`Account.create_and_sync`, `Transfer::Creator.new(...).create`)

**Variables:**
- snake_case locals and ivars (`@account`, `@family`, `@admin`)
- All-caps for frozen constants: `VISIBLE_STATUSES = %w[draft active].freeze`, `RATE_LIMITS = { ... }.freeze`
- Constants use `freeze` on mutable literals (hashes, arrays, strings) — see `app/models/account.rb:44`, `app/services/api_rate_limiter.rb:3`

**Types / Classes:**
- `CamelCase` for classes and modules, always
- `aasm` state columns are strings, never symbols: `enum :classification, { asset: "asset", liability: "liability" }` (`app/models/account.rb:42`)
- `ActiveModel::Type::Boolean` style flags use question-mark predicates: `include_in_finances?`, `exclude_from_reports?`
- Concerns live under `app/models/concerns/` or `app/controllers/concerns/` and are mixed in via `include` (Ruby module mixin, not Rails STI):
  - `app/models/account.rb:2`: `include AASM, Syncable, Monetizable, Chartable, Linkable, Enrichable, Anchorable, Reconcileable, TaxTreatable`

**Database columns:**
- snake_case; boolean columns end with `?` when read (`account.exclude_from_reports?`)
- `enum` definitions use string values, not integers

## Code Style

**Formatting:**
- Ruby: 2-space indent, LF line endings (enforced by `.gitattributes`: `* text=auto eol=lf` and `.editorconfig`)
- ERB templates: `.erb_lint.yml` enforces double quotes (`Style/StringLiterals` → `EnforcedStyle: double_quotes`)
- JS: Biome (`biome.json`), double quotes (`quoteStyle: "double"`), `useEditorconfig: true`, `organizeImports: enabled`
- RuboCop inherits `rubocop-rails-omakase` (`.rubocop.yml:2`); `Layout/IndentationStyle: spaces`, `Layout/IndentationWidth: 2`

**Linting:**
- Ruby: `bin/rubocop` (rubocop-rails-omakase)
- ERB: `bin/erb_lint` (`.erb_lint.yml`)
- JS/CSS: `npm run lint`, `npm run format` (Biome)
- Security: `bin/brakeman`
- i18n: `i18n-tasks` (currently most `i18n_test.rb` cases are `skip`ped — see `test/i18n_test.rb:11,18,25,34`)

**Frozen string literals:**
- `# frozen_string_literal: true` magic comment is used in many but not all Ruby files — use it in new files: `app/services/api_rate_limiter.rb` does **not** have it; `app/components/DS/button.rb` does

## Import Organization

**Ruby — auto-managed by RuboCop:**
- Standard library first, then gems, then application (`require` statements)
- `test_helper` always first in test files: `test/models/account_test.rb:1` → `require "test_helper"`
- RSpec spec files use `require 'swagger_helper'` (single quotes in `spec/requests/api/v1/accounts_spec.rb:3`)

**JavaScript — Biome `organizeImports`:**
- ESM `import` statements at top of file
- Stimulus controllers: `import { Controller } from "@hotwired/stimulus";` first, then the `export default class ... extends Controller`
- `app/javascript/controllers/index.js` eagerly registers all `controllers/**/*_controller` files via `@hotwired/stimulus-loading`'s `eagerLoadControllersFrom`

**Path aliases:**
- Ruby: standard Rails autoloading; no Zeitwerk overrides
- JS: importmap (`config/importmap.rb`) resolves bare specifiers (`@hotwired/stimulus`, `d3-array`, etc.); no bundler, no Node `node_modules` at runtime

## Error Handling

**Strategy: rescue specific exceptions, never broad `StandardError` unless at a top-level boundary.**

Patterns observed in `app/`:
- **Provider / external API errors:** rescue provider-specific error classes first, then `JSON::ParserError`, then `ArgumentError` / `TypeError`, then `StandardError` as a last-resort catchall in sync/import paths
  - `app/models/sophtron_item/importer.rb:180-202`: `rescue Provider::Sophtron::Error`, `rescue JSON::ParserError`, `rescue StandardError => e`
  - `app/models/simplefin_item/importer.rb:684`: `rescue Provider::Simplefin::SimplefinError => e`
  - `app/models/snaptrade_item/provided.rb:86,115,118,163,173,194`: `rescue Provider::Snaptrade::ApiError` / `AuthenticationError`
- **Money / BigDecimal parsing:** `rescue ArgumentError, TypeError` when coercing user-supplied values
  - `app/models/transaction.rb:46`: `rescue ArgumentError, TypeError`
  - `app/models/trade.rb:30`: `rescue ArgumentError, TypeError`
  - `app/models/snaptrade_account/data_helpers.rb:36,54`: `rescue ArgumentError, TypeError => e`
- **Currency conversion:** `rescue Money::ConversionError` at controller boundary, add a meaningful error to the model
  - `app/controllers/transfers_controller.rb:56-65`: rescues `Money::ConversionError` and `ArgumentError`, re-renders `:new` with `status: :unprocessable_entity`
- **Date parsing:** `rescue ArgumentError` on `Date.parse`
  - `app/controllers/transfers_controller.rb:61`: `rescue ArgumentError` → adds `"is invalid"` to `:date`
- **URL parsing:** `rescue URI::InvalidURIError`
  - `app/models/sso_provider.rb:157`, `app/models/simplefin_item.rb:263`
- **Record-level errors:** rescue `ActiveRecord::RecordInvalid` and `ActiveRecord::RecordNotUnique`
  - `app/models/snaptrade_account/data_helpers.rb:85`: `rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e`
  - `app/models/simplefin_item/importer.rb:117,955`: idempotent `find_or_create_by!` patterns
- **HTTP client errors:** `rescue Faraday::TimeoutError`, `Faraday::ConnectionFailed`, `Faraday::Error`
  - `app/models/sso_provider_tester.rb:90,92,94,96,181,183,185`
- **Encryption / signature errors:** `rescue ActiveSupport::MessageVerifier::InvalidSignature`
  - `app/models/setting.rb:113`

**Logging convention:**
- Tag logs with a class prefix in square brackets or with `Rails.logger.tagged`:
  - `Rails.logger.info("[ProviderLoader] Loaded ...")` — `app/services/provider_loader.rb:53`
  - `Rails.logger.tagged("Sync", id, syncable_type, syncable_id) do ... end` — `app/models/sync.rb:117`
- For support-relevant diagnostics on provider sync paths, prefer `DebugLogEntry.capture(...)` over `Rails.logger.*` (defined in `app/models/debug_log_entry.rb`; surfaced at `/settings/debug`). Always include `category`, `level`, `message`, `source`, `provider_key`, and structured `metadata`; attach `family` / `account_provider` when known. See AGENTS.md "Debug Logging for Provider Syncs" section.

**Flash / redirect for user-facing failures:**
- Controllers prefer `redirect_to(..., notice:)` / `alert:` (I18n key) rather than rendering errors inline
  - `app/controllers/accounts_controller.rb:49`: `redirect_to accounts_path, notice: t("accounts.sync_all.syncing")`
  - `app/controllers/recurring_transactions_controller.rb` (and most controllers): `flash[:alert] = t("...")` then `redirect_back_or_to`
- Inline errors use `model.errors.add(:base, "...")` then re-render with `status: :unprocessable_entity`
  - `app/controllers/transfers_controller.rb:58,63`

## Logging

**Framework:** `Rails.logger` (delegates to Logtail per `Gemfile:46` `logtail-rails`)

**Patterns:**
- Tagged with class prefix in `[Brackets]` for grep-ability: `"[ProviderLoader]"`, `"[AutoSyncScheduler]"`
- Tagged blocks for request-scoped context: `Rails.logger.tagged("Sync", id, syncable_type, syncable_id)` (`app/models/sync.rb:117`)
- Severity levels used: `debug`, `info`, `warn`, `error`
  - `error`: catches and re-emits with `e.backtrace.join("\n")` for unexpected exceptions — see `app/models/up_item/importer.rb:60,61,154`
  - `warn`: recoverable / fallback situations (e.g. invalid currency code → fall back to account currency, `app/models/up_account/transactions/processor.rb:215`)
  - `info`: lifecycle events (start/finish of import, sync, job)
- Reserved for noise: simple request/response cycle events; anything operators may need → `DebugLogEntry.capture`

**Sentry / PostHog / Skylight:**
- `sentry-ruby`, `sentry-rails`, `sentry-sidekiq` (Gemfile:42-44) — exception capture is automatic
- `posthog-ruby` (Gemfile:45) — product analytics
- `skylight` (Gemfile:48,50) — performance monitoring in production (skipped if `SKYLIGHT_ENABLED != "true"`)
- `vernier` + `rack-mini-profiler` (Gemfile:40-41) — local profiling

## Comments

**When to Comment:**
- Comment non-obvious *why*, not *what*. Examples in `app/models/account.rb:111-116` (commented explanation of mass-assignment ordering) and `app/models/account.rb:34-38` (FK cascade rationale).
- Multi-line block comments above non-trivial methods to document ordering dependencies, race conditions, or surprising behavior.
- ERB comments are rare; use HTML/ERB `<!-- ... -->` only when HTML-rendered.

**JSDoc/TSDoc:**
- JavaScript files use `//` block-style header comments describing purpose and DOM contract for Stimulus controllers
  - `app/javascript/controllers/auto_open_controller.js:3-5`:
    ```js
    // Connects to data-controller="auto-open"
    // Auto-opens a <details> element based on URL param
    // Use data-auto-open-param-value="paramName" to open when ?paramName=1 is in URL
    ```
- Ruby: no formal YARD/RDoc. Use plain `#` comments for rationale, with multi-line blocks for tricky logic.

**TODO markers:**
- `TODO`, `FIXME`, `HACK`, `XXX` allowed; tracked in `app/` and `config/`
- Gemfile pins with rationale: `Gemfile:34` `# pin to 2.x; 3.0 breaks sidekiq 8.x`, `Gemfile:28-29` `# TODO: Remove max version constraint when fixed`

## Function Design

**Size:**
- Methods are kept small and single-purpose; long methods are extracted into service objects (`Transfer::Creator`, `BalanceComponentMigrator`) or concerns
- Controllers delegate to `app/services/` and `app/models/{thing}/{action}.rb` for anything non-trivial

**Parameters:**
- Strong parameters at the controller boundary: `def transfer_params; params.require(:transfer).permit(:from_account_id, :to_account_id, ...); end`
- Service objects take a keyword-argument hash or named constructor: `Transfer::Creator.new(family: ..., source_account_id: ..., date: ...).create`
- Predicates / queries take the resource as the first arg: `Account.writable_by(user)`, `Account.accessible_by(user)`, `AccountStatement.reconciliation_statuses_for(statements, account: account)`

**Return Values:**
- Service objects return the persisted/built domain object: `Transfer::Creator#create` returns a `Transfer` (or `nil` on failure)
- `RateLimiter`-style helpers return primitive Hashes: `ApiRateLimiter#usage_info` returns `{ current_count:, rate_limit:, remaining:, reset_time:, tier: }`
- Boolean methods end in `?`. Avoid returning `nil` to mean `false`.

**Bang vs. non-bang:**
- `!` raises on failure (`destroy!`, `find_or_create_by!`, `save!`)
- Non-bang returns `false`/`nil` (e.g. `update`, `save`)
- New code should follow this convention; the codebase is consistent on it.

## Module Design

**Exports:**
- Service objects expose `call` / domain-named methods (`.create`, `.run`, `.limit`); no `call`-only convention
- Helpers in `app/helpers/` and module-level class methods used for query entry points: `ApiRateLimiter.usage_for(api_key)`, `ApiRateLimiter.limit(api_key)` (`app/services/api_rate_limiter.rb:69,73`)

**Barrel Files:**
- Stimulus `app/javascript/controllers/index.js` acts as the barrel for all controllers via `eagerLoadControllersFrom`
- No Ruby-side barrel files (no `app/models.rb` aggregating requires); autoloading handles it

**Concerns vs. Service Objects vs. PORO Domain Models:**
- Cross-cutting behavior on a model → `app/models/concerns/`: `Monetizable`, `Syncable`, `Chartable`, `Linkable`, `Enrichable`, `Anchorable`, `Reconcileable`, `TaxTreatable`
- Cross-cutting controller behavior → `app/controllers/concerns/`: `AccountAuthorizable`, `Pagy::Backend`, `Pundit::Authorization`
- Domain logic with a clear entry point → namespaced class in a folder: `app/models/up_item/importer.rb` → `UpItem::Importer`
- Standalone business actions → `app/services/`: `ApiRateLimiter`, `AutoSyncScheduler`, `ProviderLoader`, `NoopApiRateLimiter`
- Long-running / async work → `app/jobs/` (Sidekiq): `ImportJob`, `SyncJob`, `DebugLogCleanupJob`

**Interface contracts:**
- The `test/interfaces/` directory holds **shared test modules** that every implementer of a contract must pass. Example: `test/interfaces/syncable_interface_test.rb` is included by any test that exercises a `Syncable` model (`test/models/account_test.rb:4` does `include SyncableInterfaceTest, EntriesTestHelper, ActiveJob::TestHelper`).
- Module name pattern: `<Concept>InterfaceTest`, extended with `ActiveSupport::Testing::Declarative` so `test "..."` blocks work inside modules.

## Lint Discipline

- New Ruby code should run `bin/rubocop -A` (auto-correct safe cops) before commit
- New ERB must respect the `DeprecatedClasses` linter in `.erb_lint.yml`:
  - No raw `text-gray-*`, `bg-gray-*`, `border-gray-*`, `text-white`, `bg-white`, `border-white` classes
  - Use semantic tokens from `app/assets/tailwind/sure-design-system.css` (`text-primary`, `bg-container`, `border-subdued`, `text-destructive`)
  - Do not combine custom `@utility` tokens with Tailwind opacity modifiers (`text-primary/70` silently compiles to nothing — see `.erb_lint.yml:45-49` and issue #1653)
- New ViewComponent code should use `DS::*` primitives (`DS::Alert`, `DS::Button`, `DS::Disclosure`, `DS::Dialog`, `DS::Menu`) before writing a hand-rolled equivalent — see AGENTS.md "Design System Hygiene"
- New API endpoints **must** be paired with both:
  - Minitest behavioral coverage in `test/controllers/api/v1/{resource}_controller_test.rb` (no behavioral asserts in rswag)
  - rswag OpenAPI spec in `spec/requests/api/v1/{resource}_spec.rb` (docs-only — no `expect`/`assert_*`)
  - Auth uses `X-Api-Key` header (not OAuth/Bearer) — see `app/controllers/concerns/api/` and AGENTS.md "API Development Guidelines"

---

*Convention analysis: 2026-07-11*
