## Why

Self-hosters who point Sure at a custom OpenAI-compatible endpoint
(LM Studio, Ollama, vLLM, OpenRouter) hit four UX gaps on top of the
backend execute-path fix that the parallel
`fix-auto-categorization-custom-openai` change addresses:

1. The **AI Prompts** page hardcodes `Provider::Openai::DEFAULT_MODEL`
   (`gpt-4.1`) in three places, so an operator on a local model sees a
   misleading model label next to every prompt.
2. There is no **"Force Auto-Categorize Now"** button in the Self-Hosting
   page, so operators cannot trigger a manual auto-categorization run
   from the UI — they have to set up a Rule action and wait.
3. Auto-tag is **silently disabled** when `uri_base` is set but `model`
   is blank (`Provider::Registry#openai` returns `nil`), with no
   user-visible warning — the error only lands in server logs.
4. **LLM Usage statistics omit `auto_categorize` rows** for
   custom/self-hosted providers, because `statistics_for_family`
   filters to `scope_with_cost` (`WHERE estimated_cost IS NOT NULL`)
   before computing the by-operation breakdown. Custom models have no
   pricing entry, so their rows are excluded and auto-categorization
   is invisible in the stats page even though tokens were consumed.

The backend is correct (token usage *is* recorded); the UI is what's
broken. This change closes the UX gap so a self-hoster can see, trigger,
schedule, and trust auto-categorization against a custom endpoint.

## What Changes

- Resolve the **effective model** for the active LLM provider in
  `Settings::AiPromptsController#show` and pass it to the view, so the
  AI Prompts page shows the configured model (e.g. `llama3.1`,
  `claude-sonnet-4-5`) instead of the hardcoded `gpt-4.1`.
- Add a **"Force Auto-Categorize Now"** action to the Self-Hosting
  controller that enqueues `AutoCategorizeJob` for `Current.family`'s
  uncategorized transactions, with a button in the OpenAI settings
  partial.
- Add a **scheduled auto-categorization** routine that mirrors the
  existing auto-sync scheduling: a new `AutoCategorizeScheduler` service
  manages a Sidekiq-Cron job (`AutoCategorizeAllJob`) that iterates
  every family and enqueues `AutoCategorizeJob` for its uncategorized
  transactions. The operator picks a **frequency** (hourly, every 6h,
  every 12h, daily) and a **time-of-day** (HH:MM, used for the daily
  cadence and as the minute offset for sub-daily cadences). Settings:
  `auto_categorize_enabled`, `auto_categorize_frequency`,
  `auto_categorize_time`, `auto_categorize_timezone`. ENV overrides
  match the sync pattern (`AUTO_CATEGORIZE_ENABLED`,
  `AUTO_CATEGORIZE_FREQUENCY`, `AUTO_CATEGORIZE_TIME`,
  `AUTO_CATEGORIZE_TIMEZONE`). The scheduler is synced on
  `Sidekiq.configure_server` startup and on hosting settings update,
  exactly like `AutoSyncScheduler`.
- Surface an **inline warning banner** in the Self-Hosting page when a
  custom `uri_base` is set but `model` is blank, so the silent
  no-provider condition is visible before the operator wonders why
  auto-tag never runs.
- Extend `LlmUsage.statistics_for_family` to compute **token- and
  request-based breakdowns over all rows** (not just rows with an
  `estimated_cost`), and render those alongside the cost breakdown in
  the LLM Usage page so `auto_categorize` operations appear for custom
  providers with nil cost.
- Add locale keys for the new button, warning, schedule controls, and
  operation labels.
- Add tests covering: effective model resolution, force-auto-categorize
  enqueues the job, non-admin redirect, scheduled job creation/removal
  on enable/disable, `AutoCategorizeAllJob` enqueues per-family jobs,
  and `statistics_for_family` includes `auto_categorize` in the token
  breakdown when cost is nil.

## Capabilities

### New Capabilities

- `auto-tag-ux-custom-endpoints`: operator-facing UX for auto-tag
  against a custom OpenAI-compatible endpoint — effective model
  display, manual trigger, scheduled auto-categorization,
  misconfiguration warning, and usage visibility.

### Modified Capabilities

- (none — no existing capability's REQUIREMENTS are changing; the
  backend execute path is covered by the parallel
  `custom-openai-autocategorize-execute` capability)

## Impact

- `app/controllers/settings/ai_prompts_controller.rb` — resolve
  `@effective_model`.
- `app/views/settings/ai_prompts/show.html.erb` — render
  `@effective_model` instead of `Provider::Openai::DEFAULT_MODEL`.
- `config/routes.rb` — add `force_auto_categorize` collection route
  on `resource :hosting`.
- `app/controllers/settings/hostings_controller.rb` — add
  `force_auto_categorize` action; compute
  `@openai_custom_provider_valid` in `show`; persist the
  `auto_categorize_*` settings and re-sync the scheduler on update.
- `app/views/settings/hostings/_openai_settings.html.erb` — add the
  force button and the misconfiguration warning banner.
- `app/models/setting.rb` — add `auto_categorize_enabled`,
  `auto_categorize_frequency`, `auto_categorize_time`,
  `auto_categorize_timezone` fields; add `valid_auto_categorize_time?`
  and the `AUTO_CATEGORIZE_FREQUENCIES` constant.
- `app/services/auto_categorize_scheduler.rb` — **new**; manages the
  Sidekiq-Cron job (`AutoCategorizeAllJob`) from the configured
  frequency + time-of-day, mirroring `AutoSyncScheduler`.
- `app/jobs/auto_categorize_all_job.rb` — **new**; iterates all
  families and enqueues `AutoCategorizeJob` per family with its
  uncategorized transaction IDs (mirrors `SyncAllJob`).
- `app/models/family.rb` — add a helper that returns the family's
  uncategorized, enrichable transaction IDs (used by
  `AutoCategorizeAllJob` and the force action).
- `config/initializers/sidekiq.rb` — call
  `AutoCategorizeScheduler.sync!` on Sidekiq server startup alongside
  `AutoSyncScheduler.sync!`.
- `app/models/llm_usage.rb` — add token/request breakdowns to
  `statistics_for_family`.
- `app/views/settings/llm_usages/show.html.erb` — render all
  operations with token/request counts alongside cost.
- `app/views/settings/hostings/_openai_settings.html.erb` (or a new
  `_auto_categorize_settings.html.erb` partial) — add the frequency
  selector, time-of-day field, enable toggle, and force button.
- `config/locales/views/settings/hostings/en.yml` — new keys.
- `config/locales/views/settings/llm_usages/en.yml` — operation label
  keys.
- Tests: `test/controllers/settings/hostings_controller_test.rb`,
  `test/controllers/settings/ai_prompts_controller_test.rb` (created
  if absent), `test/models/llm_usage_test.rb`,
  `test/services/auto_categorize_scheduler_test.rb` (**new**),
  `test/jobs/auto_categorize_all_job_test.rb` (**new**).
- No schema migration (settings stored via `rails-settings-cached`);
  no new dependencies (`sidekiq-cron` already used).