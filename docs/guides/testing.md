<!-- generated-by: gsd-doc-writer -->
# Testing

This document describes Sure's testing framework, how to run the test suite, and conventions for writing new tests.

## Test Framework and Setup

Sure uses **Minitest** (the default Rails test framework) with several supporting libraries:

- **Minitest** (`minitest`, `minitest/autorun`, `minitest/mock`) — core test framework
- **Mocha** (`mocha/minitest`) — mocking and stubbing
- **AASM Minitest** (`aasm/minitest`) — assertions for the AASM state machine
- **WebMock** (`webmock/minitest`) — HTTP request stubbing
- **VCR** — records and replays HTTP interactions via WebMock
- **Rack::Test** — used for request specs
- **OmniAuth test mode** — enabled for OIDC auth callback tests
- **SimpleCov** — code coverage (only loaded when `COVERAGE=true`)

Test configuration lives in `test/test_helper.rb`. It:

- Forces `RAILS_ENV=test` and `PLAID_ENV=sandbox`
- Configures VCR with `test/vcr_cassettes` and filters sensitive env vars
- Loads all files in `test/interfaces/**/*.rb` automatically
- Loads support helpers from `test/support/`
- Enables parallel test execution by default (one worker per processor). Set `DISABLE_PARALLELIZATION=true` to disable.
- Resets the `Setting` cache before each test to avoid order-dependent failures from the `rails-settings-cached` in-memory cache
- Loads YAML fixtures from `test/fixtures/*.yml` alphabetically for every test

### One-time setup

```bash
bin/setup
cp .env.test.example .env.test  # if present in your checkout
```

`bin/setup` creates the database, loads the schema, and seeds it.

## Running Tests

The full suite is invoked through Rails' Minitest runner:

```bash
# Full suite (unit + integration; runs in parallel by default)
bin/rails test

# System tests (browser-driven via Selenium + Chrome)
bin/rails test:system

# A single test file
bin/rails test TEST=test/models/user_test.rb

# A single test by line number / name
bin/rails test test/models/user_test.rb:42

# Disable parallelization (useful when debugging or for system tests)
DISABLE_PARALLELIZATION=true bin/rails test
```

### JavaScript tests

Pure JavaScript unit tests live under `test/javascript/` and are written as Node test files (`.mjs` / `.cjs`). They are not part of the default `bin/rails test` run — invoke them directly with Node or via the npm scripts defined in `package.json` (style:check / lint / format). See `package.json` for the exact scripts available in your version.

### Coverage

To collect a SimpleCov coverage report:

```bash
COVERAGE=true bin/rails test
```

No coverage threshold is configured — SimpleCov is used as a reporting tool, not as a CI gate.

## Writing New Tests

### File and directory layout

Tests live under `test/` and **mirror the `app/` structure**:

| App path | Test path |
|----------|-----------|
| `app/models/user.rb` | `test/models/user_test.rb` |
| `app/controllers/api/v1/accounts_controller.rb` | `test/controllers/api/v1/accounts_controller_test.rb` |
| `app/services/import.rb` | `test/services/import_test.rb` |
| `app/javascript/utils/foo.js` | `test/javascript/utils/foo_test.mjs` |

Naming convention:

- Ruby: `*_test.rb` (e.g., `account_test.rb`)
- JavaScript: `*_test.mjs` or `*_test.cjs`
- Subdirectory namespaces (e.g., `test/models/account/`, `test/services/akahu_item/`) are used for closely related groups of tests

### Available test types

| Type | Directory | Purpose |
|------|-----------|---------|
| Model | `test/models/` | Unit tests for ActiveRecord models, validations, scopes, state machines |
| Controller | `test/controllers/` | Request/response behavior for Rails controllers |
| System | `test/system/` | Full-stack browser tests (Selenium + Chrome). Requires `bin/rails test:system`. |
| Integration | `test/integration/` | Cross-cutting concerns (OAuth, CORS, Rack::Attack, Active Storage auth) |
| Service | `test/services/` | Plain Ruby service objects and providers |
| Job | `test/jobs/` | ActiveJob / Sidekiq jobs |
| Helper | `test/helpers/` | View and controller helpers |
| Mailer | `test/mailers/` | ActionMailer previews and delivery |
| Component | `test/components/` | ViewComponent unit tests and previews |
| Interface (conformance) | `test/interfaces/` | Shared test interfaces that providers / syncable resources must satisfy |
| JavaScript | `test/javascript/` | Node-level unit tests for pure JS modules |

### Shared helpers

The `test/support/` directory provides shared helpers used across multiple test files:

- `test/support/entries_test_helper.rb` — entry and transaction test data builders
- `test/support/balance_test_helper.rb` — balance assertions
- `test/support/ledger_testing_helper.rb` — ledger / double-entry accounting assertions
- `test/support/securities_test_helper.rb` — security / holding test builders
- `test/support/provider_test_helper.rb` and `provider_adapter_test_interface.rb` — provider test utilities
- `test/support/sql_query_capture.rb` — capture and assert against SQL queries issued during a test
- `test/support/verify_api_endpoint_consistency.rb` — enforces the API endpoint consistency rules described in `AGENTS.md`

`ApplicationSystemTestCase` (in `test/application_system_test_case.rb`) is the base class for `test/system/**` tests. `ActiveSupport::TestCase` is the base for everything else.

### Common patterns

**Signing in a user:**

```ruby
sign_in(users(:family_admin))
```

**Setting environment variables per test:**

```ruby
with_env_overrides(OPENAI_ACCESS_TOKEN: "test-token") do
  # test code
end
```

**Asserting against issued SQL:**

```ruby
assert_queries_count(1) do
  User.where(family: family).count
end
```

**HTTP fixtures (VCR cassettes):**

Cassettes are stored under `test/vcr_cassettes/<provider>/<scenario>.yml`. Use them for any external HTTP call (Plaid, Stripe, OpenAI, SimpleFIN, GitHub, etc.) so tests are deterministic and offline-friendly. WebMock blocks all other outbound HTTP by default; a request without a matching cassette will fail.

**Uploading a file in a request test:**

```ruby
post import_path, params: {
  file: uploaded_file(filename: "transactions.csv", content_type: "text/csv")
}
```

### API endpoint tests

API tests follow two parallel tracks, both **required** for any change under `app/controllers/api/v1/`:

1. **Minitest** behavioral coverage in `test/controllers/api/v1/{resource}_controller_test.rb`. This is where `assert_*` calls live.
2. **rswag** OpenAPI documentation in `spec/requests/api/v1/{resource}_spec.rb`. **rswag is documentation-only** — do not add behavioral `expect` / `assert_*` calls there.

Authentication for API tests uses the `X-Api-Key` header (see the `api_headers(api_key)` helper in `test_helper.rb`).

The full post-commit consistency checklist is in `AGENTS.md` and the rule file it references: `.cursor/rules/api-endpoint-consistency.mdc`.

## Coverage Requirements

No coverage threshold is configured. SimpleCov runs only when `COVERAGE=true` is exported, and CI does not fail on coverage. Use the coverage report locally when working on larger changes if you want to spot untested branches.

## CI Integration

Tests run in GitHub Actions via `.github/workflows/ci.yml`, which is invoked as a reusable workflow (`workflow_call`).

The CI pipeline has the following test-related jobs:

| Job | Trigger | Command | Notes |
|-----|---------|---------|-------|
| `test_unit` | `workflow_call` | `bin/rails test` | Spins up Postgres and Redis services. Loads schema, runs seeds, then runs the full Minitest suite. |
| `test_system` | `workflow_call` | `DISABLE_PARALLELIZATION=true bin/rails test:system` | Same DB/Redis services. Runs browser-driven system tests with headless Chrome. On failure, uploads `tmp/screenshots` as an artifact named `screenshots`. |

Both jobs install `google-chrome-stable`, `libvips`, `libpq-dev`, and the Postgres client. Ruby is installed via `ruby/setup-ruby` pinned to `.ruby-version`; the bundler cache is enabled.

The workflow is wired into the broader `pr.yml` / release pipelines, so tests run automatically on every pull request and before any deployment.
