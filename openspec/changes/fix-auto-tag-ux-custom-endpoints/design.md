## Context

The backend auto-categorize pipeline for custom OpenAI-compatible
endpoints is correct (the parallel `fix-auto-categorization-custom-openai`
change locks the execute path). What remains is the operator-facing
surface: the AI Prompts page mislabels the model, there is no manual
trigger, a misconfigured custom endpoint fails silently, and LLM Usage
statistics hide `auto_categorize` rows for providers with no pricing
entry.

Current state of each touchpoint:

- `Settings::AiPromptsController#show` builds `@assistant_config` via
  `Assistant.config_for(...)` but never resolves the model the active
  provider will actually use. The view
  `app/views/settings/ai_prompts/show.html.erb` hardcodes
  `Provider::Openai::DEFAULT_MODEL` on lines 42, 70, 98 — so an
  operator on `llama3.1` or `claude-sonnet-4-5` sees `[gpt-4.1]`.
- `Provider::Registry.preferred_llm_provider` already resolves the
  correct provider (OpenAI *or* Anthropic, honoring `Setting.llm_provider`
  and credential presence). The registry's `openai` method returns
  `nil` when `uri_base` is set but `model` is blank
  (`registry.rb:87-90`), which is the right guard — but the only signal
  is a `Rails.logger.error` line the operator never sees.
- `Settings::HostingsController` has `update`, `clear_cache`, and
  `disconnect_external_assistant` actions; there is no manual
  auto-categorize trigger. The routes file declares
  `resource :hosting, only: %i[show update]` with two `delete`
  collection routes.
- `LlmUsage.statistics_for_family` builds `scope_with_cost =
  scope.where.not(estimated_cost: nil)` and computes `by_operation`
  and `by_model` *only* from that scope. Custom/self-hosted models have
  no `PRICING` entry, so `calculate_cost` returns `nil` and those rows
  are excluded entirely — `auto_categorize` is invisible in the stats
  page even though `UsageRecorder#record_usage` wrote a real
  `LlmUsage` row with token counts.

Stakeholders: self-hosters on local models (primary), any operator who
wants to trigger auto-tag on demand or see full token usage regardless
of pricing coverage.

## Goals / Non-Goals

**Goals:**

- The AI Prompts page shows the **effective model** of the active LLM
  provider (OpenAI *or* Anthropic, custom or native), not a hardcoded
  default.
- An operator can trigger a **manual auto-categorization run** for
  `Current.family` from the Self-Hosting page, without setting up a
  Rule.
- A misconfigured custom OpenAI endpoint (`uri_base` set, `model`
  blank) shows an **inline warning** in the Self-Hosting page before
  the operator wonders why auto-tag never runs.
- The LLM Usage page shows `auto_categorize` (and every other
  operation) in the by-operation breakdown **even when
  `estimated_cost` is nil**, with token and request counts.
- All four fixes are covered by tests.

**Non-Goals:**

- Changing provider resolution (`Provider::Registry` /
  `preferred_llm_provider`) — the backend execute path is the parallel
  change's scope.
- Adding pricing entries for custom/self-hosted models — cost stays
  `nil` for those; we surface *tokens* instead.
- Super-admin "auto-categorize all families" action — the button is
  scoped to `Current.family` (confirmed).
- Retry policy for `AutoCategorizeJob` — out of scope; the button just
  enqueues the job, existing error handling applies.
- Translating the new locale keys beyond `en.yml` — other locales fall
  back to English until translated.

## Decisions

### D1. Effective model via `preferred_llm_provider&.model`, not a new helper

`Settings::AiPromptsController#show` resolves
`@effective_model = Provider::Registry.preferred_llm_provider&.model ||
Provider::Openai::DEFAULT_MODEL`. The view renders `@effective_model`
in the three `<pre>[...]</pre>` slots.

**Rationale.** `preferred_llm_provider` already honors
`Setting.llm_provider` and credential presence, so it returns the
*Anthropic* provider when the operator picked Anthropic, and the
*OpenAI* provider (custom or native) otherwise. Reading `.model` off
the returned provider gives the exact string the LLM call will use.
No new helper, no duplication of the resolution logic.

**Alternatives considered.**

- *Read `Setting.openai_model` / `Setting.anthropic_model` directly* —
  rejected, because it would bypass the credential-presence fallback in
  `preferred_llm_provider` and show a model for a provider that won't
  actually be used.
- *Add `Provider::Openai.effective_model` as the source* — that class
  method already exists (`openai.rb:13`) and returns
  `Setting.openai_model.presence || DEFAULT_MODEL`, but it doesn't
  account for Anthropic. Using `preferred_llm_provider&.model` is a
  superset.

### D2. Force auto-categorize enqueues the existing `AutoCategorizeJob`

New action `Settings::HostingsController#force_auto_categorize`:

1. Guarded by `ensure_admin` (added to the `before_action` list).
2. Computes the uncategorized, enrichable transaction IDs for
   `Current.family` (via a new `Family#uncategorized_enrichable_transaction_ids`
   helper — see D5) and calls
   `Current.family.auto_categorize_transactions_later(transactions)`.
   `AutoCategorizeJob#perform` then calls
   `family.auto_categorize_transactions(transaction_ids)`, whose
   `Family::AutoCategorizer#scope` filters `where(id: transaction_ids,
   category_id: nil).enrichable(:category_id)` — so passing the IDs is
   required (the job does **not** auto-discover uncategorized
   transactions when `transaction_ids` is empty, it scopes to nothing).
3. Redirects to `settings_hosting_path` with a flash notice. If the
   family has no uncategorized transactions, redirect with an
   informational flash ("no transactions to categorize") instead of
   enqueuing a no-op job.

Route: `post :force_auto_categorize, on: :collection` added to
`resource :hosting`.

**Rationale.** Reusing the existing enqueue path means the manual run
goes through the *same* `Family::AutoCategorizer` →
`Provider::Registry.preferred_llm_provider` → `Provider::Openai` flow
as rule-driven runs, so the parallel execute-path fix applies
automatically. The force action differs from a rule run only in how
the transaction set is computed (all uncategorized vs the rule's
matched set).

**Alternatives considered.**

- *Add a "categorize now" button per-transaction in the transaction
  list* — useful but a separate, larger UX change. The Self-Hosting
  button covers the "I just set up a custom endpoint and want to verify
  it works" use case, which is the reported pain.
- *Enqueue `AutoCategorizeJob` without `transaction_ids` and have the
  job auto-discover uncategorized transactions when the list is empty*
  — tempting for the force action, but would change the job's contract
  for *all* callers (rule runs pass IDs deliberately). The shared
  `Family#uncategorized_enrichable_transaction_ids` helper keeps the
  job unchanged and serves both the force action and
  `AutoCategorizeAllJob` (D5).

### D3. Misconfiguration warning is computed in the controller, not the view

`Settings::HostingsController#show` sets:

```ruby
@openai_custom_provider_valid =
  (Setting.openai_uri_base.presence || ENV["OPENAI_URI_BASE"]).present? &&
  (Setting.openai_model.presence || ENV["OPENAI_MODEL"]).present?
```

The view renders a `DS::Alert` (variant `:warning`) when
`@openai_custom_provider_valid == false`, keyed off a new locale
string. This mirrors the existing
`Setting.validate_openai_config!` pair (uri_base requires model) but
surfaces it *before* a save, as a persistent banner.

**Rationale.** The registry's `nil` return is intentional (guard
against broken config); we don't want to change that contract. The
warning belongs in the UI layer that the operator actually reads.

**Alternatives considered.**

- *Show the warning only after a failed run* — rejected, because the
  whole point is to surface the misconfiguration *before* the operator
  waits for a run that silently does nothing.
- *Add a flash on `update` when the pair is invalid* — the existing
  `Setting.validate_openai_config!` already flashes on save. The
  persistent banner covers the case where the misconfiguration predates
  this page visit.

### D4. LLM Usage: add token/request breakdowns, keep cost breakdown as-is

`LlmUsage.statistics_for_family` gains two new keys computed over the
**full** scope (not `scope_with_cost`):

- `by_operation_tokens: scope.group(:operation).sum(:total_tokens)`
- `by_operation_requests: scope.group(:operation).count`

`by_operation` (cost) stays computed from `scope_with_cost` as today —
that's accurate cost when available. The view's "Cost by Operation"
section iterates over the **union** of `by_operation_tokens.keys` and
`by_operation.keys`, rendering requests, tokens, and cost (or "N/A")
per operation. Operation labels use
`t(".operations.#{operation}", default: operation.humanize)` so
translations are optional with a safe fallback.

**Rationale.** The cost filter is correct *for cost*; the bug is that
the by-operation breakdown reused the cost-filtered scope. Computing
token/request breakdowns over the full scope shows `auto_categorize`
for custom providers (cost nil, tokens real) without distorting cost
totals.

**Alternatives considered.**

- *Move `by_operation` to the full scope and render `N/A` for nil cost*
  — rejected, because `sum(:estimated_cost)` over rows with nil cost
  would either error or silently coerce nils to 0, both of which lie
  about cost. Keeping two scopes is honest.
- *Add a separate "Token by Operation" card* — considered; folding
  tokens into the existing by-operation list keeps the page compact
  and makes the cost-vs-tokens contrast visible per operation.

### D5. Scheduled auto-categorization mirrors `AutoSyncScheduler`, with a frequency + time-of-day

A new `AutoCategorizeScheduler` service manages a single Sidekiq-Cron
job (`AutoCategorizeAllJob`) from two operator-facing knobs:

- **Frequency** — `hourly`, `every_6_hours`, `every_12_hours`, or
  `daily` (default `daily`). Stored as `Setting.auto_categorize_frequency`.
- **Time-of-day** — `HH:MM` (default `03:33`, offset from sync's `02:22`
  so the two cron jobs don't collide). Stored as
  `Setting.auto_categorize_time`. For the `daily` frequency this is the
  exact run time; for the sub-daily frequencies it supplies only the
  minute offset (the hour(s) are derived from the cadence) so a
  self-hoster's `HH:MM` still meaningfully nudges *when* within the hour
  the job fires.

Cron expressions:

| Frequency        | Cron (UTC)             | Uses HH:MM?                |
|------------------|------------------------|----------------------------|
| hourly           | `M H * * *`? No — `M * * * *`  (minute only)            | minute from HH:MM          |
| every_6_hours    | `M */6 * * *`          | minute from HH:MM          |
| every_12_hours   | `M */12 * * *`         | minute from HH:MM          |
| daily            | `M H * * *`            | full HH:MM (as sync does)   |

Where `M` = minute, `H` = hour, converted from the family/install
timezone (`Setting.auto_categorize_timezone`, defaulting to the sync
timezone's logic: stored on update from `Current.family.timezone`,
ENV-overridable via `AUTO_CATEGORIZE_TIMEZONE`).

**Components:**

1. **`app/models/setting.rb`** — four new fields mirroring the sync
   trio:
   - `auto_categorize_enabled` (boolean, default
     `ENV.fetch("AUTO_CATEGORIZE_ENABLED", "0") == "1"` — **default
     off** so existing installs don't suddenly start spending LLM
     tokens without an opt-in).
   - `auto_categorize_frequency` (string, default
     `ENV.fetch("AUTO_CATEGORIZE_FREQUENCY", "daily")`).
   - `auto_categorize_time` (string, default
     `ENV.fetch("AUTO_CATEGORIZE_TIME", "03:33")`).
   - `auto_categorize_timezone` (string, default
     `ENV.fetch("AUTO_CATEGORIZE_TIMEZONE", "UTC")`).
   - `AUTO_CATEGORIZE_FREQUENCIES = %w[hourly every_6_hours every_12_hours daily].freeze`
   - `valid_auto_categorize_time?` (reuses `AUTO_SYNC_TIME_FORMAT`).

2. **`app/services/auto_categorize_scheduler.rb`** — **new**. Near-exact
   mirror of `AutoSyncScheduler`:
   - `JOB_NAME = "auto_categorize_all"`.
   - `sync!` → upsert or remove based on `auto_categorize_enabled?`.
   - `upsert_job` builds the cron from frequency + time + timezone and
     calls `Sidekiq::Cron::Job.create(name:, cron:, class:
     "AutoCategorizeAllJob", queue: :scheduled, description:)`.
   - `remove_job` destroys the cron job if present.

3. **`app/jobs/auto_categorize_all_job.rb`** — **new**. Mirrors
   `SyncAllJob`:
   ```ruby
   class AutoCategorizeAllJob < ApplicationJob
     queue_as :scheduled
     sidekiq_options lock: :until_executed, on_conflict: :log

     def perform
       Rails.logger.info("Starting scheduled auto-categorize for all families")
       Family.find_each do |family|
         ids = family.uncategorized_enrichable_transaction_ids
         next if ids.empty?
         family.auto_categorize_transactions_later(
           family.transactions.where(id: ids)
         )
       rescue => e
         Rails.logger.error("Failed to auto-categorize family #{family.id}: #{e.message}")
       end
       Rails.logger.info("Completed scheduled auto-categorize for all families")
     end
   end
   ```
   The `lock: :until_executed` prevents overlapping runs (LLM calls are
   slow and expensive; two concurrent runs would double token spend).

4. **`app/models/family.rb`** — new helper:
   ```ruby
   def uncategorized_enrichable_transaction_ids
     transactions.where(category_id: nil)
                .enrichable(:category_id)
                .pluck(:id)
   end
   ```
   Shared by the force action (D2) and `AutoCategorizeAllJob`, so the
   "what counts as needing categorization" definition lives in one
   place.

5. **`config/initializers/sidekiq.rb`** — add
   `AutoCategorizeScheduler.sync!` to the existing
   `config.on(:startup)` block, alongside `AutoSyncScheduler.sync!`.

6. **`Settings::HostingsController#update`** — persist the four new
   params (mirroring the `auto_sync_*` handling), validate
   `auto_categorize_time` with `Setting.valid_auto_categorize_time?`,
   and call `sync_auto_categorize_scheduler!` (a private method that
   wraps `AutoCategorizeScheduler.sync!` with the same error-swallower
   pattern as `sync_auto_sync_scheduler!`). Add the new params to the
   `hosting_params` permit list.

7. **UI** — a new partial
   `app/views/settings/hostings/_auto_categorize_settings.html.erb`
   rendered inside the OpenAI settings section (or as its own
   `settings_section` on the hosting page, beside sync settings). It
   contains: an enable toggle, a frequency `select`, a `time_field` for
   the time-of-day (disabled when frequency is not `daily` *and* when
   auto-categorize is disabled), and the "Force Auto-Categorize Now"
   button (D2). All controls auto-submit on change like the sync
   settings.

**Rationale.** Mirroring `AutoSyncScheduler` means the scheduling
infrastructure (Sidekiq-Cron, startup hook, timezone conversion,
validation) is a known-good pattern already proven in production. The
frequency dimension is the only addition over sync, and it's a trivial
cron-shape switch. Defaulting `auto_categorize_enabled` to **off**
(while sync defaults on) respects that LLM calls cost money and
shouldn't silently start running on every install that upgrades.

**Alternatives considered.**

- *Daily only (no frequency)* — simplest, but the user explicitly asked
  for frequency, and new transactions arriving between daily runs would
  sit uncategorized for up to 24h, which defeats the "catch new imports
  sooner" use case for a local-model self-hoster with no per-call cost.
- *Frequency only (no time-of-day)* — loses the ability to schedule the
  daily run at a quiet hour, which the sync pattern establishes as the
  expected operator control.
- *Per-family scheduling (each family picks its own time)* — rejected
  for scope; `SyncAllJob` is install-wide and a single cron job, and
  matching that keeps the scheduler service simple. Per-family
  scheduling would require N cron jobs or a dispatcher job; a follow-up
  if needed.
- *Reuse `AutoSyncScheduler` with a flag* — rejected; the two jobs have
  different classes, queues, lock semantics, and default times. A
  shared scheduler would couple unrelated concerns.

## Risks / Trade-offs

- **[Risk] `preferred_llm_provider&.model` returns `nil` if no provider
  is configured.** → Mitigation: the `|| Provider::Openai::DEFAULT_MODEL`
  fallback preserves the current label; a fully unconfigured install
  still shows `gpt-4.1` (no regression).
- **[Risk] The force-auto-categorize button could be clicked
  repeatedly, enqueuing many jobs.** → Mitigation: the job is
  idempotent-ish (it scopes to uncategorized transactions; a second run
  with nothing to do returns `modified_count: 0`). A future follow-up
  could debounce, but the current cost is low.
- **[Risk] The misconfiguration warning banner could be noisy for an
  operator who intentionally sets `uri_base` before `model` during
  setup.** → Mitigation: the banner is informational (warning variant),
  not a blocker; it disappears as soon as both fields are filled.
- **[Risk] Adding `by_operation_tokens` changes the
  `statistics_for_family` return shape; existing callers may break.**
  → Mitigation: the new keys are *additive*; existing keys keep their
  names and semantics. The only caller is the LLM Usage controller/view
  in this repo; grep before merging to confirm no other caller.
- **[Risk] Scheduled auto-categorize runs against every family could
  spend significant LLM tokens on a large install.** → Mitigation:
  `auto_categorize_enabled` defaults to **off**; operators opt in
  explicitly. The frequency is bounded (hourly at most), and
  `AutoCategorizeAllJob` uses `lock: :until_executed` so two runs can't
  overlap and double-spend. The `llm_max_items_per_call` budget
  setting still caps each batch.
- **[Risk] `AutoCategorizeAllJob` iterating `Family.find_each` could be
  slow on a large install.** → Mitigation: the job skips families with
  no uncategorized transactions (`next if ids.empty?`) and rescues
  per-family errors so one bad family doesn't abort the run. If
  throughput becomes an issue, a follow-up can shard by family count.
- **[Risk] The time-of-day field is irrelevant for sub-daily
  frequencies (only the minute is used), confusing operators.** →
  Mitigation: the UI disables the time field when frequency is not
  `daily`, and the locale help text explains the role of HH:MM per
  frequency. The daily case is the most common and behaves exactly like
  sync.

## Migration Plan

No schema migration (settings stored via `rails-settings-cached`).
Deploy steps:

1. Land controller/view/locale/test changes in the worktree.
2. Run `bin/rails test test/controllers/settings/hostings_controller_test.rb`,
   `bin/rails test test/controllers/settings/ai_prompts_controller_test.rb`
   (create if absent), `bin/rails test test/models/llm_usage_test.rb`,
   `bin/rails test test/services/auto_categorize_scheduler_test.rb`,
   `bin/rails test test/jobs/auto_categorize_all_job_test.rb`.
3. Run `bin/rubocop` and `npm run lint` (Biome touches ERB-adjacent JS
   if any).
4. Push the worktree branch per the AGENTS.md auto-push policy.

**Post-deploy:** the first Sidekiq server restart calls
`AutoCategorizeScheduler.sync!`; because `auto_categorize_enabled`
defaults to off, no cron job is created until an operator enables it.
Existing installs see no behavior change.

Rollback: revert the commit(s). All changes are additive (new action,
new ivar, new settings fields default-off, new service + job, new stat
keys, new locale keys, new tests); reverting removes the cron job on
next Sidekiq restart and restores the previous UX.

## Open Questions

- The AI Prompts page header currently reads `t(".openai_label")`
  ("OpenAI"). When the active provider is Anthropic or a custom
  endpoint, should the header label change to match? The proposal
  keeps the existing label for scope; a dynamic provider name is a
  reasonable follow-up.