## 1. AI Prompts — effective model

- [x] 1.1 In `Settings::AiPromptsController#show`, resolve `@effective_model = Provider::Registry.preferred_llm_provider&.model || Provider::Openai::DEFAULT_MODEL` and pass it to the view.
- [x] 1.2 In `app/views/settings/ai_prompts/show.html.erb`, replace the three `Provider::Openai::DEFAULT_MODEL` references (lines 42, 70, 98) with `@effective_model`.
- [x] 1.3 Add/extend `test/controllers/settings/ai_prompts_controller_test.rb` to assert `@effective_model` reflects a custom `Setting.openai_model`, an Anthropic model when `Setting.llm_provider == "anthropic"`, and falls back to `DEFAULT_MODEL` when no provider is configured.

## 2. Force auto-categorize action

- [x] 2.1 In `config/routes.rb`, add `post :force_auto_categorize, on: :collection` to `resource :hosting`.
- [x] 2.2 In `Settings::HostingsController`, add `force_auto_categorize` action: compute `Current.family.uncategorized_enrichable_transaction_ids`; if empty, redirect with an informational flash; otherwise call `Current.family.auto_categorize_transactions_later(Current.family.transactions.where(id: ids))` and redirect to `settings_hosting_path` with a success flash.
- [x] 2.3 Add `:force_auto_categorize` to the `ensure_admin` `before_action` list.
- [x] 2.4 Add tests in `test/controllers/settings/hostings_controller_test.rb`: (a) admin POST enqueues `AutoCategorizeJob`; (b) non-admin POST is redirected and no job is enqueued; (c) admin POST with no uncategorized transactions redirects with the informational flash and enqueues nothing.

## 3. Self-Hosting — misconfiguration warning

- [x] 3.1 In `Settings::HostingsController#show`, compute `@openai_custom_provider_valid` = true iff a `uri_base` is present *and* a `model` is present (reading `Setting.*` with `ENV[...]` fallback for each).
- [x] 3.2 In `app/views/settings/hostings/_openai_settings.html.erb`, render a `DS::Alert` (variant `:warning`) with the new locale key when `@openai_custom_provider_valid == false`. Place it above the form fields.
- [x] 3.3 Add locale keys under `settings.hostings.openai_settings` in `config/locales/views/settings/hostings/en.yml`: `custom_provider_model_missing_warning`.
- [x] 3.4 Add a test asserting the warning banner renders when `uri_base` is set and `model` is blank, and does not render when both are set.

## 4. Force button UI

- [x] 4.1 In `app/views/settings/hostings/_openai_settings.html.erb` (or the new `_auto_categorize_settings.html.erb` partial from group 5), add a `DS::Button` (variant `:primary`) that POSTs to `force_auto_categorize_settings_hosting_path`, with a `data-turbo-confirm` dialog.
- [x] 4.2 Add locale keys under `settings.hostings.openai_settings` in `config/locales/views/settings/hostings/en.yml`: `force_auto_categorize_button`, `force_auto_categorize_description`; and under `settings.hostings.force_auto_categorize.success`.

## 5. Scheduled auto-categorization — settings & scheduler

- [x] 5.1 In `app/models/setting.rb`, add fields: `auto_categorize_enabled` (boolean, default `ENV.fetch("AUTO_CATEGORIZE_ENABLED", "0") == "1"` — default off), `auto_categorize_frequency` (string, default `ENV.fetch("AUTO_CATEGORIZE_FREQUENCY", "daily")`), `auto_categorize_time` (string, default `ENV.fetch("AUTO_CATEGORIZE_TIME", "03:33")`), `auto_categorize_timezone` (string, default `ENV.fetch("AUTO_CATEGORIZE_TIMEZONE", "UTC")`). Add `AUTO_CATEGORIZE_FREQUENCIES = %w[hourly every_6_hours every_12_hours daily].freeze` and `valid_auto_categorize_time?` (reuse `AUTO_SYNC_TIME_FORMAT`).
- [x] 5.2 Create `app/services/auto_categorize_scheduler.rb` mirroring `AutoSyncScheduler`: `JOB_NAME = "auto_categorize_all"`, `sync!` (upsert/remove based on `auto_categorize_enabled?`), `upsert_job` (build cron from frequency + time + timezone, `Sidekiq::Cron::Job.create(name:, cron:, class: "AutoCategorizeAllJob", queue: :scheduled)`), `remove_job`. Cron shapes: hourly → `M * * * *`, every_6_hours → `M */6 * * *`, every_12_hours → `M */12 * * *`, daily → `M H * * *` (M/H from HH:MM converted to UTC from the configured timezone).
- [x] 5.3 Create `app/jobs/auto_categorize_all_job.rb` mirroring `SyncAllJob`: `queue_as :scheduled`, `sidekiq_options lock: :until_executed, on_conflict: :log`; `perform` iterates `Family.find_each`, for each computes `uncategorized_enrichable_transaction_ids`, skips if empty, else calls `family.auto_categorize_transactions_later(family.transactions.where(id: ids))`; rescues per-family errors (log + continue).
- [x] 5.4 In `app/models/family.rb`, add `def uncategorized_enrichable_transaction_ids; transactions.where(category_id: nil).enrichable(:category_id).pluck(:id); end` (shared by the force action and `AutoCategorizeAllJob`).
- [x] 5.5 In `config/initializers/sidekiq.rb`, add `AutoCategorizeScheduler.sync!` (with the same rescue+log pattern as `AutoSyncScheduler.sync!`) to the existing `config.on(:startup)` block.
- [x] 5.6 In `Settings::HostingsController#update`, handle `auto_categorize_enabled`, `auto_categorize_frequency` (validate against `AUTO_CATEGORIZE_FREQUENCIES`), `auto_categorize_time` (validate with `Setting.valid_auto_categorize_time?`, flash+redirect on invalid like the sync path), `auto_categorize_timezone` (set from `current_user_timezone` on time change). Add a private `sync_auto_categorize_scheduler!` wrapper (mirror `sync_auto_sync_scheduler!`) and call it when any `auto_categorize_*` param changes. Add the four params to the `hosting_params` permit list.
- [x] 5.7 Add tests in `test/services/auto_categorize_scheduler_test.rb`: (a) enabled + daily creates the cron job with the right cron expression; (b) disabled removes the job; (c) every_6_hours uses minute-only cron; (d) invalid time logs error and falls back to `03:33`; (e) default-off creates no job.
- [x] 5.8 Add tests in `test/jobs/auto_categorize_all_job_test.rb`: (a) perform enqueues `AutoCategorizeJob` per family with uncategorized transactions; (b) families with no uncategorized transactions are skipped; (c) a per-family error is logged and does not abort the run.

## 6. Scheduled auto-categorization — UI

- [x] 6.1 Create `app/views/settings/hostings/_auto_categorize_settings.html.erb` containing: an enable toggle (`auto_categorize_enabled`), a frequency `select` (`auto_categorize_frequency`, options from `AUTO_CATEGORIZE_FREQUENCIES`), a `time_field` (`auto_categorize_time`, disabled when frequency is not `daily` or when auto-categorize is disabled), and the "Force Auto-Categorize Now" `DS::Button` from task 4.1. All controls auto-submit on change (mirror `_sync_settings.html.erb`).
- [x] 6.2 Render the new partial in `show.html.erb` — either inside the OpenAI settings section or as a new `settings_section` beside sync settings (prefer the section to keep auto-categorize concerns visible regardless of provider panel).
- [x] 6.3 Add locale keys under `settings.hostings.auto_categorize_settings` in `config/locales/views/settings/hostings/en.yml`: `title`, `enable_label`, `enable_description`, `frequency_label`, `frequency_description`, `time_label`, `time_description`, `time_sub_daily_help` (explains that only the minute is used for sub-daily frequencies), and per-frequency labels (`frequency_hourly`, `frequency_every_6_hours`, `frequency_every_12_hours`, `frequency_daily`).

## 7. LLM Usage — token/request breakdowns

- [x] 7.1 In `LlmUsage.statistics_for_family`, add `by_operation_tokens: scope.group(:operation).sum(:total_tokens)` and `by_operation_requests: scope.group(:operation).count`, computed over the full `scope` (not `scope_with_cost`). Keep `by_operation` (cost) on `scope_with_cost` unchanged.
- [x] 7.2 Add a test in `test/models/llm_usage_test.rb` asserting `by_operation_tokens` includes `auto_categorize` with its token sum when `estimated_cost` is nil (custom provider scenario), and that `by_operation` (cost) does not include that row.
- [x] 7.3 In `app/views/settings/llm_usages/show.html.erb`, update the "Cost by Operation" section to iterate over the union of `by_operation_tokens.keys` and `by_operation.keys`; render requests (`by_operation_requests`), tokens (`by_operation_tokens`), and cost (`by_operation` or "N/A") per operation.
- [x] 7.4 Replace `operation.humanize` in the by-operation list with `t(".operations.#{operation}", default: operation.humanize)`.
- [x] 7.5 Add locale keys under `settings.llm_usages.operations` in `config/locales/views/settings/en.yml` (or the llm_usages locale file if separate) for `auto_categorize`, `auto_detect_merchants`, and `chat`, with the `.humanize` fallback preserved.

## 8. Verification

- [x] 8.1 Run `bin/rails test test/controllers/settings/hostings_controller_test.rb test/controllers/settings/ai_prompts_controller_test.rb test/models/llm_usage_test.rb test/services/auto_categorize_scheduler_test.rb test/jobs/auto_categorize_all_job_test.rb` and ensure green.
- [x] 8.2 Run `bin/rubocop` and `npm run lint`; fix any offenses in changed files.
- [x] 8.3 Run `openspec validate fix-auto-tag-ux-custom-endpoints` to confirm spec/artifact consistency.
- [x] 8.4 Manual: visit Self-Hosting with `uri_base` set + `model` blank → warning appears; set model, click "Force Auto-Categorize Now" → success flash; enable scheduled auto-categorize (daily, 03:33) → confirm cron job created in Sidekiq-Cron; visit AI Prompts → effective model shown; visit LLM Usage → `auto_categorize` row visible for a custom provider with nil cost.