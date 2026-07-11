## Why

A self-hoster wiring Sure against a custom OpenAI-compatible endpoint
(LM Studio, Ollama, vLLM, OpenRouter, …) reports that **auto-categorization
is not running on the custom OpenAI provider**. Chat works against the
same endpoint, but `auto_categorize` is either silently skipped, dispatched
to a different provider, or fails before any LLM call is made.

This is a regression / coverage gap for the
`auto-tagging-custom-openai-endpoints` capability (the integration test at
`test/integration/custom_openai_endpoint_coverage_test.rb` covers
*resolution identity* but not the *execute path*). Chat works, batch
flows don't — a real user-facing break for anyone self-hosting on a
local model.

## What Changes

- Diagnose and fix why `Family::AutoCategorizer` does not produce
  results when the configured `Provider::Openai` is a custom endpoint
  (`uri_base` set, `custom_provider? == true`).
- Add a regression test that drives the full execute path
  (rule action → `AutoCategorizeJob` → `Family::AutoCategorizer` →
  `Provider::Openai#auto_categorize` → `Provider::Openai::AutoCategorizer`)
  with a custom OpenAI-compatible endpoint, asserting that
  `auto_categorize` is invoked and the job completes with a non-zero
  `modified_count`.
- Ensure auto-categorize failures against a custom endpoint are
  observable: log a `Rails.logger.error` with the underlying LLM error
  (or `DebugLogEntry.capture`) so the operator can see *why* it didn't
  run, instead of the current silent-skip behaviour.

## Capabilities

### New Capabilities
- `custom-openai-autocategorize-execute`: end-to-end guarantee that the
  `auto_categorize` execute path runs against a custom OpenAI-compatible
  endpoint (LM Studio / Ollama / vLLM / OpenRouter) and that failures are
  surfaced.

### Modified Capabilities
- (none — no existing capability's REQUIREMENTS are changing; this is
  a fix to behaviour already promised by `auto-tagging-custom-openai-endpoints`
  in the chat path and the provider-registry resolution path)

## Impact

- `app/models/family/auto_categorizer.rb` — provider selection and
  error surfacing.
- `app/models/provider/openai/auto_categorizer.rb` — generic-mode
  execute path; currently routes to `client.chat` for custom providers.
- `app/models/provider/openai.rb` — top-level `auto_categorize` batch
  slicer driver.
- `app/jobs/auto_categorize_job.rb` — job-level error handling.
- `test/integration/custom_openai_endpoint_coverage_test.rb` — extend
  to cover the execute path (not just resolution identity).
- `docs/llm-providers.md` — note the auto-categorize parity guarantee
  and the failure-logging contract.
