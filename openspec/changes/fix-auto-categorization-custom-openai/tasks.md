## 1. Reproduce and diagnose

- [x] 1.1 In a new worktree, write a failing integration test in `test/integration/custom_openai_endpoint_coverage_test.rb` that drives the full execute path: configure `Setting.openai_uri_base` + `Setting.openai_model` + `Setting.openai_access_token` + `Setting.llm_provider = "openai"`, enqueue `AutoCategorizeJob` for a family with three uncategorized enrichable transactions, perform the job inline, and assert the OpenAI-compatible client received a `chat.completions` request and at least one `DataEnrichment` was created.
- [x] 1.2 Run the test (`bin/rails test test/integration/custom_openai_endpoint_coverage_test.rb`) and capture the exact failure mode (silent skip, unhandled exception, empty scope, dispatch to wrong provider).
- [x] 1.3 Read the failure mode against the four candidate causes listed in `design.md` (Context §) and decide which one(s) the fix needs to address.

## 2. Fix the execute path

- [x] 2.1 If the failure is in `Provider::Openai::AutoCategorizer#auto_categorize_openai_generic` (e.g. a JSON-extraction error against a non-OpenAI schema), add a focused `rescue` clause in that method that logs the raw response and the error, then re-raises. Mirror the existing `Rails.logger.warn` / `Rails.logger.error` style used in `auto_categorize_with_mode` and `auto_categorize_with_auto_mode`.
- [x] 2.2 Add a `rescue_from` (or `begin/rescue`) to `AutoCategorizeJob#perform` that catches any unhandled exception from `family.auto_categorize_transactions(...)`, logs the family id, rule_run_id, `llm_provider.uri_base` (if present), error class, and error message at `error` level, and lets the job complete with `modified_count: 0`. Cover the "no LLM provider configured" branch (where `Family::AutoCategorizer` raises `Error, "No LLM provider for auto-categorization"`) explicitly.
- [x] 2.3 If the failure is a one-line correction (e.g. a missing `custom_provider:` kwarg), apply that correction in place and add a comment referencing this change.

## 3. Lock the fix in

- [x] 3.1 Re-run the failing test from 1.1 and confirm it now passes.
- [x] 3.2 Add a second test in `test/integration/custom_openai_endpoint_coverage_test.rb` asserting that an unhandled LLM exception in `auto_categorize` is logged at `error` level (use a stub that raises `Faraday::Error` or `StandardError`) and that the job still completes.
- [x] 3.3 Add a third test asserting that when `Provider::Registry.preferred_llm_provider` returns `nil`, `AutoCategorizeJob#perform` logs the condition and completes with `modified_count: 0`.
- [x] 3.4 Run the full test files that touch the changed code: `bin/rails test test/integration/custom_openai_endpoint_coverage_test.rb`, `bin/rails test test/models/family/auto_categorizer_test.rb`, `bin/rails test test/jobs/auto_categorize_job_test.rb` (if it exists), `bin/rails test test/models/rule/action_executor/auto_categorize_test.rb`. All must pass green.

## 4. Documentation

- [x] 4.1 Update `docs/llm-providers.md` to add a one-paragraph note that the execute path of `auto_categorize` is covered for custom OpenAI-compatible endpoints and that failures are logged with `uri_base` and error context. Reference the new integration test by path.
- [x] 4.2 If `AGENTS.md` already documents the `DebugLogEntry.capture` pattern for provider-sync diagnostics, do not duplicate it; just cross-reference.

## 5. Lint, commit, and push

- [x] 5.1 Run `bin/rubocop` on the worktree and `bin/brakeman` if the changes touch request-handling or auth-adjacent code (they do not here, but verify).
- [ ] 5.2 Commit with an imperative subject ≤ 72 chars (e.g. `fix(ai): run auto_categorize against custom OpenAI endpoints`) and a body that references the user's report, the design decision (D1–D4), and the integration test path.
- [ ] 5.3 Push the worktree branch per the AGENTS.md auto-push policy (`git push -u origin gsd/fix-auto-categorization-custom-openai`).
