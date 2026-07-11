# LLM Providers in Sure

This document describes how Sure routes requests to LLM providers, how a
self-hoster can point Sure at a custom OpenAI-compatible endpoint (LM
Studio, Ollama, vLLM, OpenRouter, …), and how to verify the contract
end-to-end.

The contract this document describes is locked in by the
`custom-openai-endpoint-coverage` OpenSpec capability
(`openspec/changes/auto-tagging-custom-openai-endpoints/`) and the
identity test at
`test/integration/custom_openai_endpoint_coverage_test.rb`.

## Overview

The following features are all LLM-driven and honor the same provider
configuration:

- **Chat** — `Provider::Openai#chat_response` (and the Anthropic
  equivalent when `Setting.llm_provider = "anthropic"`).
- **Auto-categorize** — `Family::AutoCategorizer` →
  `Provider::Openai#auto_categorize`.
- **Auto-detect merchants** —
  `Provider::LlmConcept::AutoMerchantDetector` →
  `Provider::Openai#auto_detect_merchants`.
- **Enhance provider merchants** —
  `Provider::LlmConcept::EnhanceProviderMerchants` →
  `Provider::Openai#enhance_provider_merchants`.
- **PDF processing** — `Provider::Openai#process_pdf`.

All five of these go through `Provider::Registry.openai` /
`Provider::Registry.preferred_llm_provider`, so any change to the
operator's OpenAI configuration is reflected identically across every
LLM-driven feature on the next request.

The user-facing settings UI in
`app/views/settings/hostings/_openai_settings.html.erb` and the i18n
string in
`config/locales/views/settings/hostings/en.yml` (under
`openai_settings.*`) already enumerate these features; the
`OPENAI_URI_BASE` / `OPENAI_MODEL` / `OPENAI_ACCESS_TOKEN` env vars and
the `Setting.openai_*` fields are the single source of truth.

## Configuration

The OpenAI provider is configured via env vars (which take precedence)
or `Setting.*` fields:

| Env var                | Setting field            | Purpose                                   |
| ---------------------- | ------------------------ | ----------------------------------------- |
| `OPENAI_ACCESS_TOKEN`  | `Setting.openai_access_token`  | Bearer token sent to the endpoint.        |
| `OPENAI_URI_BASE`      | `Setting.openai_uri_base`      | Custom OpenAI-compatible URL (LM Studio, etc.). |
| `OPENAI_MODEL`         | `Setting.openai_model`         | Model the provider should call.           |
| `OPENAI_JSON_MODE`     | `Setting.openai_json_mode`     | Force JSON-mode completions.              |
| `OPENAI_REQUEST_TIMEOUT` | n/a                       | Per-request timeout (seconds).            |
| `LLM_CONTEXT_WINDOW`   | `Setting.llm_context_window`  | Token budget for the prompt.              |
| `LLM_MAX_RESPONSE_TOKENS` | `Setting.llm_max_response_tokens` | Token budget for the completion.     |

When `OPENAI_URI_BASE` (or `Setting.openai_uri_base`) is set, every
LLM-driven feature constructs a `Provider::Openai` with
`uri_base: <value>` and `custom_provider?` returns `true`. That in turn
makes the SDK use the OpenAI-compatible `chat.completions` path instead
of the native Responses API, and makes `supports_model?` accept any
model the endpoint exposes.

### Precedence

`ENV[*]` always wins over `Setting.*`. See
`Provider::Registry.openai` (`app/models/provider/registry.rb`) for the
exact resolution order.

## Custom OpenAI-compatible endpoint (LM Studio example)

LM Studio exposes an OpenAI-compatible HTTP server. The
`http://192.168.15.6:1234/v1` URL with model `microsoft/phi-4` is the
canonical example used by the tests in this change.

To wire Sure against LM Studio:

```bash
# .env.local
OPENAI_URI_BASE=http://192.168.15.6:1234/v1
OPENAI_MODEL=microsoft/phi-4
OPENAI_ACCESS_TOKEN=lm-studio  # LM Studio does not enforce a key, but the SDK requires one
```

Or, equivalently, via the Self-Hosting settings page
(`/settings/hosting`).

Restart Sure. From that point on, chat, auto-categorize, merchant
detection, provider merchant enhancement, and PDF processing all route
through LM Studio.

### Other common endpoints

The same configuration works for:

- **Ollama** — `OPENAI_URI_BASE=http://localhost:11434/v1`,
  `OPENAI_MODEL=llama3.2`.
- **vLLM** — `OPENAI_URI_BASE=http://localhost:8000/v1`,
  `OPENAI_MODEL=<model-id>`.
- **OpenRouter** — `OPENAI_URI_BASE=https://openrouter.ai/api/v1`,
  `OPENAI_MODEL=anthropic/claude-3.5-sonnet`,
  `OPENAI_ACCESS_TOKEN=<openrouter-key>`.

## Provider selection (OpenAI vs. Anthropic)

`Setting.llm_provider` selects the default LLM provider:

- `"openai"` (default) — the registry tries OpenAI first, then
  Anthropic.
- `"anthropic"` — the registry tries Anthropic first, then OpenAI.

If the preferred provider is not configured (no API key), the registry
falls back to whichever one is configured, and returns `nil` only when
neither is configured. Callers guard on `nil` and surface a "no LLM
provider" message rather than silently falling back.

The resolution path is `Provider::Registry.preferred_llm_provider`
(`app/models/provider/registry.rb`). Every LLM-driven feature and every
cost-preview path uses this same entry point, so the cost label a
self-hoster sees in `/rules/:id/confirm` and `/rules/confirm_all`
always reflects the provider the actual batch will call.

## Verification recipe

After wiring `OPENAI_URI_BASE=http://192.168.15.6:1234/v1` and
`OPENAI_MODEL=microsoft/phi-4`, verify the contract:

1. **Registry resolves to the configured endpoint.** Run
   `bin/rails runner "p Provider::Registry.openai.uri_base; p Provider::Registry.openai.model"`.
   Expect:

   ```text
   "http://192.168.15.6:1234/v1"
   "microsoft/phi-4"
   ```

2. **Settings UI shows the custom URL.** Open
   `/settings/hosting` and confirm the OpenAI form shows the custom URL.

3. **Cost preview reflects the configured model.** Open a rule with an
   `auto_categorize` action and visit
   `/rules/:id/confirm`. The model shown should be `microsoft/phi-4`,
   and the cost estimate should be the cost Sure would bill for that
   model (or `N/A` for unknown pricing).

4. **Identity test passes locally.** Run
   `bin/rails test test/integration/custom_openai_endpoint_coverage_test.rb`.

5. **Chat reflects the same endpoint.** Start a chat and confirm the
   request lands at the configured URL (LM Studio's developer console
   shows the request, or use a packet trace).

## What this does not cover

- **Per-user LLM settings are not supported.** LLM config is global on
  `Setting` (and on `ENV`). All families in a self-hosted install
  share the same provider configuration. This is by design; Sure does
  not model per-user LLM keys.
- **Adding a new LLM feature must route through the registry.** Any
  new code path that talks to an LLM MUST construct the provider via
  `Provider::Registry.openai` (for OpenAI-only flows) or
  `Provider::Registry.preferred_llm_provider` (for flows that should
  honor `Setting.llm_provider`). Constructing `Provider::Openai.new(...)`
  directly is a regression and will fail the identity test.
- **Cost estimation is approximate.** `LlmUsage.estimate_auto_categorize_cost`
  uses a heuristic (100 prompt tokens per transaction, 50 completion
  tokens per transaction, 50 prompt tokens per category). It does not
  read live provider pricing for custom models — unknown models return
  `nil` and the UI shows "cost: N/A".

## Failure observability for the `auto_categorize` execute path

`AutoCategorizeJob` rescues any exception raised by the LLM execute
path and logs it at `error` level with the family id, the
`rule_run_id`, the resolved provider class, and the `uri_base` of the
custom endpoint. The job then completes (it does not retry or hand
off to the dead set) so a misconfigured custom endpoint does not
silently accumulate in the Sidekiq queue.

If a self-hoster reports that "auto-categorization is not running" on
their custom OpenAI-compatible endpoint, the first thing to check is
`Rails.logger` (or the Sidekiq output) for a line of the form:

```
[AutoCategorizeJob] auto_categorize failed for family_id=...
rule_run_id=... provider=Provider::Openai uri_base=http://host:port/v1: <ErrorClass>: <message>
```

Common causes surfaced by this log line:

- `uri_base` is `nil` and the log line says "No LLM provider for
  auto-categorization" — credentials are missing for both OpenAI and
  Anthropic, or `Setting.llm_provider` is set to a provider with no
  credentials.
- `uri_base` is set but the upstream call returns a non-JSON response
  or rejects `response_format=json_schema` (HTTP 400) — re-check the
  endpoint's compatibility.
- The endpoint is reachable but the LLM is misconfigured (wrong model
  name, missing `--api` flag on Ollama, etc.) — the upstream error
  message is included verbatim after the colon.

The end-to-end execute path is locked in by
`test/integration/custom_openai_auto_categorize_execute_test.rb`; the
failure-observability contract is locked in by the same file's
`AutoCategorizeJob surfaces the failure to the operator when the LLM
call raises` and `AutoCategorizeJob logs and completes when no LLM
provider is configured` tests.
