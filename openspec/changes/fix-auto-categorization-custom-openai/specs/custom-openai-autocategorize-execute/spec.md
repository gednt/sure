## ADDED Requirements

### Requirement: Auto-categorize executes against a custom OpenAI-compatible endpoint
The system SHALL invoke the LLM-driven `auto_categorize` execute path against a custom OpenAI-compatible endpoint (`Setting.openai_uri_base` set) the same way it does for the official OpenAI endpoint, and SHALL produce a non-zero `modified_count` for transactions that the LLM can confidently categorize.

#### Scenario: Custom endpoint is used end-to-end
- **WHEN** a self-hoster has configured `Setting.openai_uri_base`, `Setting.openai_model`, `Setting.openai_access_token`, and `Setting.llm_provider = "openai"`
- **AND** a rule with an `auto_categorize` action is run for a family with at least one uncategorized, enrichable transaction
- **THEN** `Family::AutoCategorizer#auto_categorize` SHALL dispatch to a `Provider::Openai` instance whose `custom_provider?` returns `true`
- **AND** `Provider::Openai::AutoCategorizer` SHALL route to the `auto_categorize_openai_generic` path (not the native Responses API path)
- **AND** the OpenAI-compatible client SHALL receive a `chat.completions`-style request
- **AND** at least one `DataEnrichment` SHALL be created for the transaction whose category the LLM returned

#### Scenario: Custom endpoint that does not implement `response_format=json_schema` still completes
- **WHEN** the configured custom OpenAI-compatible endpoint rejects `response_format=json_schema` (HTTP 400)
- **THEN** `Provider::Openai::AutoCategorizer` SHALL fall back to `JSON_MODE_NONE` per the existing auto-mode heuristic
- **AND** the job SHALL still complete (not raise out of `Family::AutoCategorizer#auto_categorize`)

### Requirement: Auto-categorize failures against a custom endpoint are observable
The system SHALL make any failure in the `auto_categorize` execute path against a custom OpenAI-compatible endpoint visible to the operator via `Rails.logger.error` (or `DebugLogEntry.capture`) with enough context to diagnose.

#### Scenario: LLM client raises an unhandled exception
- **WHEN** the OpenAI-compatible client raises an exception while executing `auto_categorize`
- **THEN** `AutoCategorizeJob#perform` SHALL log the exception at `error` level including the family id, the rule_run_id (if any), the `uri_base`, the error class, and the error message
- **AND** the job SHALL complete (not retry, not silently die)

#### Scenario: No LLM provider is configured
- **WHEN** `Provider::Registry.preferred_llm_provider` returns `nil` (e.g. credentials missing)
- **THEN** `AutoCategorizeJob#perform` SHALL log the condition at `error` level naming the family and the rule_run_id
- **AND** the job SHALL complete with `modified_count: 0`

#### Scenario: Scope is empty
- **WHEN** `Family::AutoCategorizer#auto_categorize` is invoked but every transaction in the scope is already categorized or locked
- **THEN** the existing `info`-level log line "No transactions to auto-categorize for family ..." SHALL be emitted
- **AND** the job SHALL complete with `modified_count: 0`
- **AND** no LLM call SHALL be made
