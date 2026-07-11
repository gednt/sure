# Testing Patterns

**Analysis Date:** 2026-07-11

## Test Framework

**Primary: Minitest (Rails default)**
- Runner: `bin/rails test` (`bin/rails test test/models/user_test.rb` for a single file)
- Assertion library: Minitest stdlib (`assert`, `assert_equal`, `assert_difference`, `assert_enqueued_with`, `assert_selector`, `assert_no_difference`, `assert_includes`, `assert_response`)
- Mocking: **Mocha** (`mocha/minitest` is required in `test/test_helper.rb:23`) — uses `Object#expects`, `Object#stubs`, `Mock`; **not** RSpec's `allow`/`expect`
- Stubbing: Mocha for method-level stubs (`Family.any_instance.stubs(:get_link_token).returns("test-link-token")`)
- VCR for HTTP: `vcr` + `webmock` (`test/test_helper.rb:31-56`)
- Capybara + Selenium for system tests (`test/application_system_test_case.rb`)
- AASM has dedicated Minitest integration: `require "aasm/minitest"` (`test/test_helper.rb:24`)

**Secondary: RSpec (docs-only for APIs)**
- Used **only** for OpenAPI generation via `rswag-specs` / `rswag-api` / `rswag-ui` (Gemfile:137-139)
- `.rspec` restricts the runner to `--pattern spec/requests/api/v1/**/*_spec.rb` — the **only** spec files that run
- Specs are documentation, not behavior: no `expect()` / `assert_*` allowed inside them (enforced by `test/support/verify_api_endpoint_consistency.rb` via `--compliance` scan)

**Run commands:**
```bash
bin/rails test                                   # Run all Minitest tests
bin/rails test test/models/account_test.rb       # Run a single file
bin/rails test test/models/account_test.rb:13    # Run a single test by line
COVERAGE=true bin/rails test                     # Enable SimpleCov branch coverage
DISABLE_PARALLELIZATION=true bin/rails test     # Run serially (debugging)
bundle exec rspec                                # Run rswag specs (OpenAPI generation)
RAILS_ENV=test bundle exec rake rswag:specs:swaggerize   # Regenerate docs/api/openapi.yaml
ruby test/support/verify_api_endpoint_consistency.rb --compliance   # Lint API convention
```

## Test File Organization

**Location:** `test/` mirrors `app/` directory structure
- `app/models/account.rb` → `test/models/account_test.rb`
- `app/controllers/accounts_controller.rb` → `test/controllers/accounts_controller_test.rb`
- `app/controllers/api/v1/accounts_controller.rb` → `test/controllers/api/v1/accounts_controller_test.rb`
- `app/jobs/import_job.rb` → `test/jobs/import_job_test.rb`
- `app/components/DS/disclosure.rb` → `test/components/DS/disclosure_test.rb`
- `app/models/up_item/syncer.rb` → `test/models/up_item/syncer_test.rb`

**Naming:** `<source>_test.rb` (no `spec/` prefix in `test/`)
- Directory names mirror plural Rails conventions: `test/controllers/`, `test/models/`, `test/jobs/`, `test/policies/`, `test/mailers/`, `test/helpers/`
- Namespaced models get a namespaced test directory: `test/models/up_item/`, `test/models/akahu_account/`, `test/models/sync_stats/`

**Structure:**
```
test/
├── test_helper.rb                # Global setup, VCR, Mocha, OmniAuth, helpers
├── application_system_test_case.rb  # Capybara base for system tests
├── api_endpoint_consistency_rule_test.rb
├── encryption_verification_test.rb
├── i18n_test.rb
├── architecture/                 # app-architecture invariants
│   └── api_current_usage_test.rb
├── channels/                     # ActionCable channel tests
├── components/                   # ViewComponent tests
│   ├── DS/                       # Design-system primitive tests
│   ├── UI/
│   ├── previews/
│   └── settings/
├── controllers/                  # ActionDispatch::IntegrationTest
│   ├── admin/
│   ├── api/v1/                   # API v1 behavioral tests
│   └── concerns/                 # Controller concern unit tests
├── data_migrations/              # One-off data-migration tests
├── fixtures/                     # YAML fixtures (77 files)
├── helpers/                      # ActionView::TestCase
├── integration/                  # Cross-cutting integration tests
├── interfaces/                   # Shared interface contract test modules
│   ├── syncable_interface_test.rb
│   ├── security_provider_interface_test.rb
│   ├── exchange_rate_provider_interface_test.rb
│   ├── llm_interface_test.rb
│   ├── import_interface_test.rb
│   ├── entryable_resource_interface_test.rb
│   └── accountable_resource_interface_test.rb
├── javascript/                   # Node `node:test` JS unit tests
│   └── parse_locale_float_test.mjs
├── jobs/                         # ActiveJob::TestCase
├── lib/                          # Pure-Ruby utility tests
├── mailers/                      # ActionMailer::TestCase + preview classes
├── migrations/                   # Migration-shape tests
├── models/                       # ActiveSupport::TestCase + concern includes
├── policies/                     # Pundit policy tests
├── services/                     # Plain service-object tests
├── support/                      # Helper modules loaded by test_helper
│   ├── balance_test_helper.rb
│   ├── entries_test_helper.rb
│   ├── ledger_testing_helper.rb
│   ├── provider_adapter_test_interface.rb
│   ├── provider_test_helper.rb
│   ├── securities_test_helper.rb
│   ├── sql_query_capture.rb
│   └── verify_api_endpoint_consistency.rb
├── system/                       # ApplicationSystemTestCase (Capybara)
│   └── settings/
├── vcr_cassettes/                # Recorded HTTP responses, grouped by provider
│   ├── openai/
│   ├── plaid/
│   ├── stripe/
│   └── git_repository_provider/
└── views/                        # ActionView::TestCase (partial/helper rendering)
```

## Test Structure

**Suite organization:**
```ruby
require "test_helper"

class AccountTest < ActiveSupport::TestCase
  include SyncableInterfaceTest, EntriesTestHelper, ActiveJob::TestHelper

  setup do
    @account = @syncable = accounts(:depository)
    @family = families(:dylan_family)
    @admin = users(:family_admin)
  end

  test "can destroy" do
    assert_difference "Account.count", -1 do
      @account.destroy
    end
  end

  test "create_and_sync calls sync_later by default" do
    Account.any_instance.expects(:sync_later).once

    account = Account.create_and_sync({
      family: @family,
      owner: @admin,
      name: "Test Account",
      balance: 100,
      currency: "USD",
      accountable_type: "Depository",
      accountable_attributes: {}
    })

    assert account.persisted?
    assert_equal "USD", account.currency
  end
end
```

**Patterns:**
- Use `test "..." do ... end` (Minitest spec-style), not `def test_...` (the codebase uses both but `test "..."` is more common in newer files)
- `setup do ... end` block for per-test state; `teardown do ... end` is rare (DB rollback handles it)
- **Fixtures, not FactoryBot:** `test/fixtures/*.yml` loaded via `fixtures :all` in `test_helper.rb:80`; accessed as `accounts(:depository)`, `users(:family_admin)`, `families(:dylan_family)`
- `Setting.clear_cache` runs in a `setup` block to prevent `rails-settings-cached` cache leaks between tests (`test/test_helper.rb:87`)
- **Shared interface modules** included into the class: `include SyncableInterfaceTest, EntriesTestHelper, ActiveJob::TestHelper` — these mix in additional `test "..."` blocks that exercise the interface contract

**Controller test pattern:**
```ruby
require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  setup do
    sign_in @user = users(:family_admin)
    @account = accounts(:depository)
  end

  test "should get index" do
    get accounts_url
    assert_response :success
    assert_select "p.ml-auto.privacy-sensitive"
  end

  test "show lazily loads statement tab data unless statements tab is active" do
    AccountStatement::Coverage.expects(:for_year).never
    AccountStatement.expects(:reconciliation_statuses_for).never

    get account_url(@account)

    assert_response :success
    assert_select "turbo-frame[src='#{statements_path}']"
  end
end
```

**Job test pattern (very small):**
```ruby
require "test_helper"

class ImportJobTest < ActiveJob::TestCase
  test "import is published" do
    import = imports(:transaction)
    import.expects(:publish).once

    ImportJob.perform_now(import)
  end
end
```

**Policy test pattern:**
```ruby
class UserPolicyTest < ActiveSupport::TestCase
  def setup
    @super_admin = users(:family_admin)
    @super_admin.update!(role: :super_admin)
    @regular_user = users(:family_member)
  end

  test "super admin can view index" do
    assert UserPolicy.new(@super_admin, User).index?
  end

  test "scope returns all users for super admin" do
    scope = UserPolicy::Scope.new(@super_admin, User).resolve
    assert_equal User.count, scope.count
  end
end
```

**ViewComponent test pattern:**
```ruby
require "test_helper"

class DS::DisclosureTest < ViewComponent::TestCase
  test "body wrapper defaults to an mt-2 margin" do
    render_inline(DS::Disclosure.new(title: "More", open: true)) { "body text" }
    assert_selector "details > div.mt-2", text: "body text"
  end

  test "forwards data attributes and a summary_class override" do
    render_inline(DS::Disclosure.new(
      summary_class: "custom-summary",
      data: { controller: "color-icon-picker", action: "mousedown->color-icon-picker#handleOutsideClick" }
    )) do |disclosure|
      disclosure.with_summary_content { "trigger" }
    end
    assert_selector "summary.custom-summary", text: "trigger"
  end
end
```

**System test pattern (Capybara):**
```ruby
require "application_system_test_case"

class AccountsTest < ApplicationSystemTestCase
  setup do
    sign_in @user = users(:family_admin)
    Family.any_instance.stubs(:get_link_token).returns("test-link-token")

    visit root_url
    open_new_account_modal
  end

  test "can create depository account" do
    assert_account_created("Depository")
  end

  test "can create property account" do
    click_link "Property"
    fill_in "Name*", with: "[system test] Property Account"
    select "Single Family Home", from: "Property type*"
    click_button "Next"
    assert_text "Value"
    fill_in "account[balance]", with: 500000
    click_button "Next"
    assert_text "Address"
    click_button "Save"
    assert_text "[system test] Property Account"
  end
end
```

System tests use `sign_in(user)` from `test/application_system_test_case.rb:86` which fills the email/password form and waits for the "Welcome back, ..." heading before returning.

## Mocking

**Framework: Mocha** (`mocha/minitest` required globally in `test/test_helper.rb:23`)

**Patterns:**
```ruby
# Mock an instance method call
Account.any_instance.expects(:sync_later).once

# Stub a method to return a value
Family.any_instance.stubs(:get_link_token).returns("test-link-token")

# Verify a method is NEVER called
AccountStatement::Coverage.expects(:for_year).never
AccountStatement.expects(:reconciliation_statuses_for).never

# Use a bare Mock object
mock_sync = mock
@syncable.class.any_instance.expects(:perform_sync).with(mock_sync).once
@syncable.perform_sync(mock_sync)

# Stub env vars / settings in a block
with_env_overrides(SIMPLEFIN_DEBUG_RAW: "1") { ... }   # ClimateControl-backed helper
```

**What to Mock:**
- External HTTP calls (VCR is preferred for recorded responses, but `WebMock.disable_net_connect!` is enabled by default — see `test/test_helper.rb:25` `require "webmock/minitest"`)
- Job enqueueing: `assert_enqueued_with(job: SyncJob) { ... }`, `ActiveJob::Base.queue_adapter = :test` (`spec/rails_helper.rb:71` sets this for RSpec; Minitest picks it up via `ActiveJob::TestHelper`)
- Instance methods on the SUT via `Klass.any_instance.stubs(:method)`
- Provider adapters: `Provider::Snaptrade::AuthenticationError` etc. raised from fixtures

**What NOT to Mock:**
- The ActiveRecord persistence layer — use real DB writes inside the transaction wrapper
- Time: use `travel_to Date.new(2026, 5, 6) do ... end` (ActiveSupport::Testing::TimeHelpers) instead of stubbing `Time.current`
- `Current.user` / `Current.family` — set them in `setup` via `sign_in`

## Fixtures and Factories

**Fixtures (primary data source):**
- **YAML files** in `test/fixtures/` (77 files: `users.yml`, `accounts.yml`, `categories.yml`, `api_keys.yml`, etc.)
- ERB-evaluated YAML (`<%= 3.days.ago %>`) for dynamic timestamps
- Password digests pre-computed with `BCrypt::Engine::MIN_COST` to keep `sign_in` fast (`test/fixtures/users.yml:1-3`)
- Accessed as `users(:family_admin)`, `accounts(:depository)`, `categories(:food_and_drink)`, etc.
- `fixtures :all` is called in `test_helper.rb:80`, so every fixture is loaded for every test

**Built-in test factories (for relationships built up per-test):**
```ruby
# Helper from test/support/entries_test_helper.rb
create_balance_history(@depository, [
  { date: 5.days.ago, cash_balance: 1000, balance: 1000 },
  { date: 4.days.ago, cash_balance: 1100, balance: 1100 }
])

# Inline factory in test setup
account = Account.create!(
  family: @user.family,
  owner: @user,
  name: "Historical Checking",
  balance: 0,
  currency: "USD",
  accountable: Depository.new
)
```

**Helper modules (in `test/support/`):**
- `EntriesTestHelper` — creates balance histories, valuations, transactions
- `BalanceTestHelper` — assertions on migrated `Balance` records
- `LedgerTestingHelper` — ledger invariants
- `ProviderTestHelper` — provider-item fixtures
- `SecuritiesTestHelper` — security/price data
- `ProviderAdapterTestInterface` — base for provider tests
- `SqlQueryCapture` — `capture_sql_queries { ... }` for N+1 detection

**No FactoryBot / Fabrication.** The codebase intentionally uses fixtures only.

## Coverage

**Requirements:** None enforced in CI, but `SimpleCov` is wired and ready.

**View coverage:**
```bash
COVERAGE=true bin/rails test
```
This enables `SimpleCov.start "rails"` with `enable_coverage :branch` (`test/test_helper.rb:1-6`). Parallel workers write separate `resultset-*.json` files, so `parallelize_teardown` calls `SimpleCov.result` on each worker to merge.

Tests also run in parallel by default — `parallelize(workers: :number_of_processors)` in `test_helper.rb:66` — with `DISABLE_PARALLELIZATION=true` to opt out (used by some debugging flows).

## Test Types

**Unit Tests (`ActiveSupport::TestCase`):**
- Model validations, scopes, instance methods
- Service objects (`ApiRateLimiter`, `NoopApiRateLimiter`)
- Mailers, jobs, policies, lib utilities
- All use fixtures, no HTTP

**Controller Tests (`ActionDispatch::IntegrationTest`):**
- Full request/response cycle without a browser
- `get`, `post`, `patch`, `delete` against the real router
- `assert_response`, `assert_select` for HTML inspection
- Sign in via `sign_in(user)` helper (`test/test_helper.rb:92-94`)
- API v1 controllers use `api_headers(api_key)` helper for `X-Api-Key` auth (`test/test_helper.rb:111-113`)

**Integration Tests (`test/integration/`):**
- Cross-cutting flows that span multiple controllers, sessions, OmniAuth
- Examples: `active_storage_authorization_test.rb`, `cors_test.rb`, `layout_accessibility_test.rb`, `oauth_basic_test.rb`, `oauth_mobile_test.rb`, `rack_attack_test.rb`

**Interface Contract Tests (`test/interfaces/`):**
- **Shared modules** with `test "..."` blocks that every implementer of a contract must pass
- Pattern: `module XInterfaceTest; extend ActiveSupport::Testing::Declarative; ...; end`
- Mixed into concrete tests via `include XInterfaceTest` (see `test/models/account_test.rb:4`)
- The SUT is exposed as `@subject` (security/LLM/exchange-rate) or `@syncable` (syncable interface) — the module's tests reference these ivars

**Component Tests (`ViewComponent::TestCase`):**
- Render DS primitives in isolation: `render_inline(DS::Disclosure.new(title: "More", open: true)) { "body text" }`
- Use `assert_selector`, `assert_no_selector`, `assert_text` against rendered HTML

**System Tests (`ApplicationSystemTestCase`):**
- Capybara + Selenium (Chrome / Firefox / `:headless_chrome` / `:headless_firefox`)
- Viewport: 1400×1400 (`test/application_system_test_case.rb:5-6`)
- Local driver when `SELENIUM_REMOTE_URL` is blank; remote driver otherwise
- Helper `within_testid(testid) { ... }` scopes queries to `data-testid`
- Helper `select_ds(label_text, record)` interacts with `DS::Select` custom dropdowns (renders as button+listbox, not native `<select>`)

**View Tests (`ActionView::TestCase`):**
- Render a partial in isolation: `render(partial: "categories/category_list_group", locals: { title: "Categories", categories: [ category ] })`
- Assert against HTML strings: `assert_includes html, new_category_deletion_path(category)`

**JS Tests (`test/javascript/`):**
- Run with `node:test` (Node's built-in test runner)
- Example: `test/javascript/parse_locale_float_test.mjs` inlines the function under test to avoid bundler config
- Use `import { describe, it } from "node:test"` and `import assert from "node:assert/strict"`

**Mailer Tests (`ActionMailer::TestCase`):**
- `test/mailers/*_test.rb` — standard pattern: `assert_emails`, `assert_enqueued_email_with`
- Preview classes in `test/mailers/previews/` for browser-based preview

**Helper Tests (`ActionView::TestCase`):**
- `test/helpers/*_helper_test.rb` — exercise Rails helpers directly

## Common Patterns

**Async Testing:**
```ruby
test "can sync later" do
  assert_difference "@syncable.syncs.count", 1 do
    assert_enqueued_with job: SyncJob do
      @syncable.sync_later(window_start_date: 2.days.ago.to_date)
    end
  end
end

test "sync_later does not enqueue SyncJob while a surrounding transaction is still open" do
  job_enqueued_mid_transaction = false

  ActiveRecord::Base.transaction do
    @syncable.sync_later
    job_enqueued_mid_transaction = queue_adapter.enqueued_jobs.any? { |j| j[:job] == SyncJob }
  end

  assert_not job_enqueued_mid_transaction, "SyncJob was enqueued inside an open transaction (GlobalID race)"
  assert_enqueued_with(job: SyncJob)
end
```

**Error Testing:**
```ruby
test "should require authentication" do
  get "/api/v1/accounts"
  assert_response :unauthorized
  response_body = JSON.parse(response.body)
  assert_equal "unauthorized", response_body["error"]
end

test "should require read_accounts scope" do
  api_key_without_read = ApiKey.new(
    user: @user, name: "No Read Key", scopes: [], source: "web",
    display_key: "no_read_#{SecureRandom.hex(8)}"
  ).tap { |k| k.save!(validate: false) }  # bypass validations to exercise the runtime guard

  get "/api/v1/accounts", params: {}, headers: api_headers(api_key_without_read)

  assert_response :forbidden
  response_body = JSON.parse(response.body)
  assert_equal "insufficient_scope", response_body["error"]
ensure
  api_key_without_read&.destroy
end
```

**HTTP Stubbing (VCR + WebMock):**
- Cassettes under `test/vcr_cassettes/{provider}/`
- Sensitive headers / tokens scrubbed: `test/test_helper.rb:50-55` filters `OPENAI_ACCESS_TOKEN`, `STRIPE_SECRET_KEY`, `PLAID_SECRET`, etc.
- ERB mode enabled (`config.default_cassette_options = { erb: true }`) so cassettes can interpolate env at replay
- Interface tests build cassette name from `vcr_key_prefix` (defined in the implementer)

**SQL Capture / N+1 detection:**
```ruby
include SqlQueryCapture

queries = capture_sql_queries do
  # exercise code under test
end
assert queries.size <= 1, "Expected single query, got #{queries.size}"
```

**Env override helper:**
```ruby
with_env_overrides(SIMPLEFIN_DEBUG_RAW: "1") do
  # exercise code that reads ENV
end
```
Backed by `ClimateControl.modify` (`test/test_helper.rb:102-104`).

**Self-hosting helper:**
```ruby
with_self_hosting do
  # ApiRateLimiter.limit(...) now returns NoopApiRateLimiter
end
```
(`test/test_helper.rb:106-109` stubs `Rails.configuration.app_mode` to `"self_hosted".inquiry` for the block.)

## Linting the Test Suite Itself

- `test/api_endpoint_consistency_rule_test.rb` — runs a minimal pure-Ruby verification that the `.cursor/rules/api-endpoint-consistency.mdc` rule + AGENTS.md reference the required elements (Minitest location, rswag docs-only, `X-Api-Key`, etc.). Not dependent on Rails boot.
- `test/support/verify_api_endpoint_consistency.rb` — extended checker with `--compliance` mode that scans:
  - `spec/requests/api/v1/*_spec.rb` for forbidden `expect(` / `assert_*` (rswag must stay docs-only)
  - `spec/requests/api/v1/*_spec.rb` for `Doorkeeper` / `Bearer` / `access_token` (must use API key)
  - `app/controllers/api/v1/*_controller.rb` for a matching `test/controllers/api/v1/<name>_test.rb` (Minitest coverage)

## Test Data Conventions

- **Always fixture-based.** No FactoryBot. Inline `.create!(...)` only when the test specifically needs a one-off record.
- **Use pre-baked fixtures for cross-test stability:** `accounts(:depository)`, `users(:family_admin)`, `families(:dylan_family)`, `categories(:food_and_drink)`, `securities(:aapl)`.
- **ERB-evaluated YAML** for time-relative values: `<%= 3.days.ago %>`, `<%= Time.current %>`.
- **Cleanup:** DB transaction wraps every test (Rails default), so no explicit teardown needed. Setting cache cleared explicitly in `setup` to prevent `rails-settings-cached` leaks.
- **Display keys for API keys:** randomized at runtime via `SecureRandom.hex(8)` to avoid collisions:
  ```ruby
  display_key: "test_read_#{SecureRandom.hex(8)}"
  ```

---

*Testing analysis: 2026-07-11*
