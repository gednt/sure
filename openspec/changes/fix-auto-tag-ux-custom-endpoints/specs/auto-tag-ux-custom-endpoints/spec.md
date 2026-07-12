## ADDED Requirements

### Requirement: AI Prompts page shows the effective model for the active LLM provider
The system SHALL display the model that the active LLM provider will actually use on the AI Prompts page, resolved via `Provider::Registry.preferred_llm_provider`, instead of a hardcoded default model name.

#### Scenario: Custom OpenAI endpoint with a configured model
- **WHEN** `Setting.openai_uri_base` is set to a custom endpoint URL
- **AND** `Setting.openai_model` is set to `llama3.1`
- **AND** `Setting.llm_provider` is `openai` (or unset)
- **AND** an admin visits the AI Prompts settings page
- **THEN** each prompt section SHALL display `[llama3.1]` as the model label
- **AND** the page SHALL NOT display the hardcoded `gpt-4.1` default

#### Scenario: Anthropic provider configured
- **WHEN** `Setting.llm_provider` is `anthropic`
- **AND** `Setting.anthropic_model` is `claude-sonnet-4-5`
- **AND** `Setting.anthropic_access_token` is present
- **AND** an admin visits the AI Prompts settings page
- **THEN** each prompt section SHALL display `[claude-sonnet-4-5]` as the model label

#### Scenario: No provider configured
- **WHEN** `Provider::Registry.preferred_llm_provider` returns `nil`
- **AND** an admin visits the AI Prompts settings page
- **THEN** each prompt section SHALL display the `Provider::Openai::DEFAULT_MODEL` fallback (`gpt-4.1`)

### Requirement: Operator can trigger a manual auto-categorization run from the Self-Hosting page
The system SHALL provide a "Force Auto-Categorize Now" control on the Self-Hosting settings page that enqueues `AutoCategorizeJob` for the current family's uncategorized transactions, scoped to `Current.family`.

#### Scenario: Admin triggers a manual run
- **WHEN** an admin clicks "Force Auto-Categorize Now" on the Self-Hosting page
- **THEN** the system SHALL enqueue `AutoCategorizeJob` for `Current.family`
- **AND** the job SHALL scope to uncategorized, enrichable transactions for `Current.family`
- **AND** the admin SHALL be redirected to the Self-Hosting page with a success flash notice

#### Scenario: Non-admin is blocked
- **WHEN** a non-admin user attempts to POST to the force auto-categorize action
- **THEN** the system SHALL redirect them to the Self-Hosting page
- **AND** the system SHALL NOT enqueue `AutoCategorizeJob`
- **AND** the response SHALL include an authorization error flash

### Requirement: Self-Hosting page warns when a custom OpenAI endpoint is missing a model
The system SHALL display an inline warning on the Self-Hosting page when a custom OpenAI-compatible endpoint is configured (`uri_base` set) but no model is set, so the operator can see why auto-categorization will not run before triggering a run.

#### Scenario: Custom URI base set, model blank
- **WHEN** `Setting.openai_uri_base` (or `ENV["OPENAI_URI_BASE"]`) is present
- **AND** `Setting.openai_model` (or `ENV["OPENAI_MODEL"]`) is blank
- **AND** an admin visits the Self-Hosting page
- **THEN** the OpenAI settings section SHALL display a warning banner explaining that auto-categorize will not run until a model is entered

#### Scenario: Both URI base and model set
- **WHEN** `Setting.openai_uri_base` is present
- **AND** `Setting.openai_model` is present
- **AND** an admin visits the Self-Hosting page
- **THEN** the OpenAI settings section SHALL NOT display the missing-model warning banner

### Requirement: LLM Usage statistics include operations with nil estimated cost
The system SHALL include every operation in the LLM Usage by-operation breakdown, even when `estimated_cost` is nil (as is the case for custom/self-hosted providers with no pricing entry), by computing token and request counts over the full usage scope rather than only the cost-bearing subset.

#### Scenario: Custom provider auto-categorize is visible in stats
- **WHEN** a family has `LlmUsage` rows with `operation = "auto_categorize"` and `estimated_cost` is `nil`
- **AND** an admin visits the LLM Usage page
- **THEN** the by-operation breakdown SHALL include a row for `auto_categorize`
- **AND** the row SHALL display the total token count for that operation
- **AND** the row SHALL display the request count for that operation
- **AND** the row SHALL display "N/A" (or the localized equivalent) for cost

#### Scenario: Cost totals remain accurate
- **WHEN** a family has a mix of cost-bearing and nil-cost `LlmUsage` rows
- **AND** an admin visits the LLM Usage page
- **THEN** the total cost summary SHALL reflect only the cost-bearing rows
- **AND** the total tokens summary SHALL reflect all rows including nil-cost ones

#### Scenario: Operation labels are translatable with fallback
- **WHEN** the LLM Usage page renders an operation name
- **THEN** the system SHALL look up `t(".operations.<operation>")`
- **AND** SHALL fall back to `<operation>.humanize` when no translation key exists

### Requirement: Auto-categorization can be scheduled to run automatically on a configurable cadence
The system SHALL support a scheduled auto-categorization routine, managed via Sidekiq-Cron, that iterates every family and enqueues `AutoCategorizeJob` for each family's uncategorized, enrichable transactions. The operator SHALL control the cadence via an enable toggle, a frequency selector (hourly, every 6h, every 12h, daily), and a time-of-day (HH:MM) used for the daily cadence and as the minute offset for sub-daily cadences. The routine SHALL default to disabled so existing installs do not start spending LLM tokens without an explicit opt-in.

#### Scenario: Scheduled job is created when enabled
- **WHEN** `Setting.auto_categorize_enabled` is set to true
- **AND** `Setting.auto_categorize_frequency` is `daily`
- **AND** `Setting.auto_categorize_time` is `03:33`
- **AND** the Sidekiq server starts (or `AutoCategorizeScheduler.sync!` is invoked)
- **THEN** a Sidekiq-Cron job named `auto_categorize_all` SHALL be created
- **AND** the job's cron expression SHALL correspond to `03:33` in the configured timezone, converted to UTC
- **AND** the job's class SHALL be `AutoCategorizeAllJob`

#### Scenario: Scheduled job is removed when disabled
- **WHEN** `Setting.auto_categorize_enabled` is set to false
- **AND** `AutoCategorizeScheduler.sync!` is invoked
- **THEN** the `auto_categorize_all` Sidekiq-Cron job SHALL be removed if it exists
- **AND** no new job SHALL be created

#### Scenario: Sub-daily frequency uses the minute offset only
- **WHEN** `Setting.auto_categorize_enabled` is true
- **AND** `Setting.auto_categorize_frequency` is `every_6_hours`
- **AND** `Setting.auto_categorize_time` is `03:33`
- **THEN** the cron expression SHALL fire every 6 hours at minute 33 (`*/6` hour field, `33` minute field)

#### Scenario: Daily run is rescheduled when the time changes
- **WHEN** `Setting.auto_categorize_time` is updated from `03:33` to `05:15`
- **AND** `Setting.auto_categorize_frequency` is `daily`
- **AND** `AutoCategorizeScheduler.sync!` is invoked
- **THEN** the `auto_categorize_all` cron job SHALL be recreated with a cron expression corresponding to `05:15` in the configured timezone

#### Scenario: Scheduled run categorizes uncategorized transactions per family
- **WHEN** `AutoCategorizeAllJob#perform` runs
- **THEN** it SHALL iterate every family
- **AND** for each family with at least one uncategorized, enrichable transaction, it SHALL enqueue `AutoCategorizeJob` with that family's uncategorized transaction IDs
- **AND** families with no uncategorized transactions SHALL be skipped (no job enqueued)
- **AND** a per-family error SHALL be logged and SHALL NOT abort the run for other families

#### Scenario: Overlapping scheduled runs are prevented
- **WHEN** `AutoCategorizeAllJob` is already executing
- **AND** a second instance is enqueued
- **THEN** the second instance SHALL be prevented from executing concurrently (lock `:until_executed`, conflict `:log`)

#### Scenario: Default is disabled
- **WHEN** a fresh install has no `AUTO_CATEGORIZE_ENABLED` env var set
- **THEN** `Setting.auto_categorize_enabled` SHALL default to false
- **AND** `AutoCategorizeScheduler.sync!` SHALL NOT create a cron job

#### Scenario: Invalid time falls back to default
- **WHEN** `Setting.auto_categorize_time` is set to an invalid string (not `HH:MM`)
- **AND** `AutoCategorizeScheduler.sync!` is invoked
- **THEN** the scheduler SHALL log an error and use the default time (`03:33`) for the cron expression