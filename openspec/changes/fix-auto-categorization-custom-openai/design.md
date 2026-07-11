## Context

Sure's LLM-driven features all resolve through
`Provider::Registry.preferred_llm_provider`, which honors
`Setting.llm_provider` and the configured credentials for both OpenAI
and Anthropic. For a self-hoster pointing Sure at a custom
OpenAI-compatible endpoint (`OPENAI_URI_BASE` set), the chat path is
known to work: `Provider::Openai#chat_response` picks the
`generic_chat_response` path (via `supports_responses_endpoint? ==
false` for custom providers) and the request reaches the endpoint.

The user reports that **`auto_categorize` is not running** on a custom
OpenAI provider. There are several distinct failure modes that all
present as "auto-categorization didn't run":

1. **Silent provider skip.** If `Provider::Registry.preferred_llm_provider`
   returns `nil` (e.g. only Anthropic credentials are present but
   `Setting.llm_provider == "openai"`), `Family::AutoCategorizer#auto_categorize`
   raises `Error, "No LLM provider for auto-categorization"` — but this
   error is raised inside a Sidekiq job and is *not* rescued, so the
   job goes to the dead set with no operator-visible log line.
2. **Custom-provider dispatch.** For a custom OpenAI provider,
   `Provider::Openai::AutoCategorizer#auto_categorize` routes to
   `auto_categorize_openai_generic`, which uses `client.chat` and
   `json_mode` negotiation. If `client.chat` raises (e.g. the endpoint
   doesn't implement `response_format=json_schema` correctly), the
   error is raised out of `Family::AutoCategorizer#auto_categorize`
   and the job silently retries / dies.
3. **Empty scope.** If transactions are already categorized (or locked),
   the scope returns no rows and `auto_categorize` returns `0` without
   any LLM call. This is correct behaviour but indistinguishable from
   "didn't run" in the operator's logs.
4. **Transaction-scope mismatch.** If `transaction_ids` from the rule
   executor are re-plucked to IDs but the join on `entryable` /
   `enrichable(:category_id)` filters everything out, again we get a
   silent `0` return.

The existing identity test at
`test/integration/custom_openai_endpoint_coverage_test.rb` only
asserts that the provider instance resolved by
`Family::AutoCategorizer#llm_provider` is the *same* provider that
chat uses. It does not drive an actual `auto_categorize` invocation
end-to-end, so any of the four failure modes above would slip through.

The chat path's *resolution* is what the previous
`auto-tagging-custom-openai-endpoints` change covered; this change
covers the *execute* path of `auto_categorize` against a custom
endpoint, and makes silent failures observable.

## Goals / Non-Goals

**Goals:**

- `Family::AutoCategorizer#auto_categorize` produces real
  categorizations when the configured `Provider::Openai` is a custom
  endpoint, end-to-end (rule → job → LLM → DB write).
- Failures in the auto-categorize execute path against a custom
  OpenAI-compatible endpoint are **observable**: an operator sees an
  error in `Rails.logger` (or `DebugLogEntry`) including the upstream
  LLM error message and `uri_base`, not just a Sidekiq dead-set.
- A regression test drives the full execute path with a stubbed custom
  OpenAI client, asserting the LLM endpoint is called and at least one
  transaction is categorized.

**Non-Goals:**

- Changing the provider-resolution algorithm
  (`Provider::Registry.preferred_llm_provider` is already correct for
  resolution identity).
- Changing the JSON-mode negotiation heuristics in
  `Provider::Openai::AutoCategorizer` (those are independent and
  already exercised by the existing `auto_categorize` tests).
- Adding new provider implementations (Anthropic / other).
- UI changes to surface failure status — the *logs* are the contract
  for now (matching the `DebugLogEntry` guidance in `AGENTS.md`).

## Decisions

### D1. Diagnose first, then patch

Before changing code, reproduce the user's report by running the
existing `Family::AutoCategorizer` execute path with a stubbed custom
`Provider::Openai` and capturing the exact failure mode (1–4 above).
The regression test for the *fixed* behaviour will then be a strict
superset of the reproduction case.

**Rationale.** The user's report ("definitely not running") covers
several distinct failure modes with different fixes. Patching
speculatively risks fixing the wrong one.

**Alternatives considered.**

- *Patch all four modes blindly* — rejected, because some may not
  actually be broken and we'd be adding error-handling paths to
  working code.
- *Just add logging everywhere* — tempting, but doesn't fix the
  underlying execute-path bug.

### D2. Failures are logged, not rescued, at the job boundary

`AutoCategorizeJob#perform` should `rescue` any exception raised by
`family.auto_categorize_transactions(...)`, log it with enough
context to diagnose (family id, rule_run_id, `uri_base`, error class,
error message), and let the job complete (not retry). This matches
the guidance in `AGENTS.md` for `DebugLogEntry.capture` for
recoverable errors during provider syncs.

**Rationale.** The current behaviour is "exception → Sidekiq dead
set → silent" because the job has no `rescue` clause. Adding a
`rescue_from` at the job boundary turns silent failure into
operator-visible failure without changing the contract for the happy
path.

**Alternatives considered.**

- *Use `retry_on` for transient errors* — rejected for this change;
  the right retry policy depends on the failure mode, and that
  decision belongs in a follow-up. For now: log + complete.
- *Surface failures in `RuleRun`* — would be a nice follow-up but
  is UI-adjacent and out of scope.

### D3. Regression test is end-to-end, not unit-level

Add a test in `test/integration/custom_openai_endpoint_coverage_test.rb`
that:

1. Stubs the OpenAI-compatible HTTP client to return a valid
   categorizations response.
2. Configures `Setting.openai_uri_base`, `Setting.openai_model`,
   `Setting.openai_access_token`, `Setting.llm_provider = "openai"`.
3. Enqueues `AutoCategorizeJob` for a family with three uncategorized
   transactions and a single rule action of type `auto_categorize`.
4. Performs the job inline (`perform_enqueued_jobs`).
5. Asserts that the OpenAI-compatible client received a
   `chat.completions` request (custom-provider path), that the
   `categorizations` array was returned, and that at least one
   `DataEnrichment` was created on the family.

**Rationale.** The existing identity test only checks
`assert_same chat_provider, family_provider` — that proves *identity*
but not *execution*. A custom endpoint can resolve to the right
provider instance and still fail to dispatch. The new test exercises
the full path.

**Alternatives considered.**

- *Unit-test `Provider::Openai::AutoCategorizer` directly* — already
  covered by existing tests, and misses the wiring through
  `Family::AutoCategorizer` → `Provider::Registry` → job.
- *Use VCR cassettes* — overkill for this; we stub the OpenAI client
  directly because the auto_categorize method is well-isolated.

### D4. No change to `Provider::Registry` or `preferred_llm_provider`

The provider-resolution identity is already guaranteed by the
existing tests. The bug is downstream of resolution, in the execute
path. Do not modify `Provider::Registry` in this change.

## Risks / Trade-offs

- **[Risk] Diagnosis may reveal the failure is in `Provider::Openai::AutoCategorizer#auto_categorize_openai_generic` (e.g. an unhandled error in JSON extraction against a non-OpenAI schema).** → Mitigation: the regression test uses a stubbed client that returns a known-good response, so the failing mode will surface in the reproduction case before we write the test for the fixed case.
- **[Risk] Adding `rescue` in `AutoCategorizeJob` masks intermittent failures that *should* be retried.** → Mitigation: this change is a *diagnostic* improvement (visibility); retry policy is intentionally deferred to a follow-up.
- **[Risk] Logging at `error` level for every LLM failure could be noisy on a misconfigured deployment.** → Mitigation: log at `error` only for unhandled exceptions and at `info` for empty scopes and provider-unconfigured conditions, matching the existing log levels in `Family::AutoCategorizer` and `Provider::Openai::AutoCategorizer`.
- **[Risk] The fix could be a one-line correction (e.g. we missed passing `custom_provider: true` somewhere), in which case a "design" is overkill.** → Mitigation: this is acceptable; the design still documents the regression test that locks the fix in place.

## Migration Plan

No data migration. Deploy steps:

1. Land the regression test first (red), to capture the failure mode.
2. Land the fix (which may be a one-liner in
   `Provider::Openai::AutoCategorizer`, a `rescue` in
   `AutoCategorizeJob`, or both).
3. Run `bin/rails test test/integration/custom_openai_endpoint_coverage_test.rb`
   and `bin/rails test test/models/family/auto_categorizer_test.rb`
   in the worktree.
4. Push the worktree branch per the AGENTS.md auto-push policy.

Rollback: revert the commit(s). The change is additive (a `rescue`
clause + a test); reverting restores the previous silent-failure
behaviour.

## Open Questions

- Is the user's report specifically about *rule-driven* auto-categorize
  (the rule executor + `AutoCategorizeJob` path) or *manual*
  auto-categorize (the "Categorize" button in the transaction list)?
  The fix targets the rule-driven path because that is the path that
  uses the `Family::AutoCategorizer` enqueueing machinery; manual
  categorization uses the same `Family::AutoCategorizer` directly. If
  the manual path is also broken, the same fix will cover it, but we
  should confirm with the user.
- Does the operator's endpoint actually implement
  `chat.completions` correctly, or are they trying to use the
  Responses API through a custom endpoint? `Provider::Openai#chat_response`
  picks the path based on `custom_provider?` and
  `supports_responses_endpoint?`, which defaults to `false` for
  custom providers — but `OPENAI_SUPPORTS_RESPONSES_ENDPOINT=1` would
  flip it.
