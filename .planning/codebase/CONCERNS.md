# Codebase Concerns

**Analysis Date:** 2026-07-11

## Tech Debt

### MercuryItem provider integration is largely unimplemented
- **Issue:** `app/models/mercury_item.rb` carries 6 placeholder TODOs that were never filled in. `import_latest_mercury_data` (line 43) delegates to a real `MercuryItem::Importer`, but the surrounding comment block on line 39 (`# TODO: Implement data import from provider API`) and the `process_accounts` / `schedule_account_syncs` / `sync_status_summary` / `connected_institutions` / `institution_summary` methods are still labeled as "to customize". The provider class likely works, but the model surface is scaffolding.
- **Files:** `app/models/mercury_item.rb:39-168`, `app/models/mercury_item/importer.rb`, `app/models/mercury_item/syncer.rb`, `app/controllers/mercury_items_controller.rb`
- **Impact:** Mercury flows appear to work (controller + importer + tests exist) but the model-level method contract is half-baked. Future maintainers may "fix" the right thing while leaving the TODOs behind, or refactor one path and break the others. Confusing surface for new contributors.
- **Fix approach:** Remove the TODO comments once `process_accounts`, `schedule_account_syncs`, `sync_status_summary`, `connected_institutions`, and `institution_summary` are confirmed correct. If they are correct, the comments are noise; if they are not, those methods need real implementation. Audit and resolve per-method.

### IndexaCapitalAccount::ActivitiesProcessor is a TODO-laden template
- **Issue:** `app/models/indexa_capital_account/activities_processor.rb` has 7 inline `TODO: Customize` comments that read like provider-port scaffold left in production code. Activity-type field names, ticker extraction, settlement date fallback, and amount field names are all marked as "customize for your provider's format" — but the same provider (`IndexaCapital`) is in production use.
- **Files:** `app/models/indexa_capital_account/activities_processor.rb:7,70,93,104,133,160,167`
- **Impact:** The processor is sensitive to upstream API field renames; without a test that pins the exact payload format, a provider schema change can silently break categorization. The TODOs invite a future engineer to change `data[:units]` to `data[:quantity]` as an "improvement" and break the parser.
- **Fix approach:** Replace the TODOs with a short note about Indexa Capital's actual API contract (link to provider docs). Add fixture-based tests that pin the current payload field names so regressions are caught.

### IndexaCapitalConnectionCleanupJob is a no-op stub
- **Issue:** `app/jobs/indexa_capital_connection_cleanup_job.rb:43-49` has a `delete_connection` private method that returns `nil` with a `# TODO: Implement API call to delete connection` comment. The job is enqueued (per the message "Connection #{authorization_id} deleted" on line 26) and logs "deleted" — but does not call the provider.
- **Files:** `app/jobs/indexa_capital_connection_cleanup_job.rb`
- **Impact:** Provider-side authorizations are leaked indefinitely when a user unlinks Indexa Capital. May violate provider ToS / cause rate limits / accumulate PII at the vendor.
- **Fix approach:** Implement `provider.delete_connection(authorization_id: ...)` on `Provider::IndexaCapital`, wire it into the cleanup job, add a VCR cassette to the job test.

### Enable Banking GDPR/CCPA retention TODO
- **Issue:** `app/models/enable_banking_item.rb:51` notes `# TODO: implement data retention policy for last_psu_ip (GDPR/CCPA — nullify after session expiry or 90 days)`. The IP is stored in plain `last_psu_ip` column and shipped to the provider on every session refresh via `app/models/enable_banking_item/provided.rb:28`.
- **Files:** `app/models/enable_banking_item.rb`, `app/models/enable_banking_item/provided.rb`
- **Impact:** Personal data (IP) is retained indefinitely, contrary to the in-code policy statement. Self-hosted users in EU/CA jurisdictions may have compliance gaps.
- **Fix approach:** Add a `before_save`/cleanup job that nullifies `last_psu_ip` after `session_expires_at` or 90 days, whichever is earlier. Add a migration if the column needs timestamping; otherwise add a scheduled job to scrub old rows.

### EnableBankingAccount::Processor relies on implicit full-history recalc
- **Issue:** `app/models/enable_banking_account/processor.rb:101-102` notes `# TODO: pass explicit window_start_date to sync_later to avoid full history recalculation on every sync`. The `set_current_balance` call triggers a sync without a window, which (per the comment) causes full-history recalc each time.
- **Files:** `app/models/enable_banking_account/processor.rb`
- **Impact:** Slow sync, potential timeouts/Retries on accounts with long histories. Increases Sidekiq queue time.
- **Fix approach:** Refactor `set_current_balance` (or wrap it) to accept `window_start_date` / `window_end_date` from the parent sync.

## Known Bugs

### MercuryItem test coverage gap: Syncer, Provided, Unlinking, sync_complete_event
- **Issue:** Only `mercury_item_test.rb` (90 lines) and `mercury_item/importer_test.rb` (156 lines) exist for the Mercury model. The other four collaborator files in `app/models/mercury_item/` (`provided.rb`, `unlinking.rb`, `sync_complete_event.rb`, `syncer.rb`) have no direct test files. `mercury_item_test.rb` does not exercise `import_latest_mercury_data`, `process_accounts`, or `schedule_account_syncs` (the only public methods other than basic config).
- **Files:** `app/models/mercury_item/syncer.rb`, `app/models/mercury_item/provided.rb`, `app/models/mercury_item/unlinking.rb`, `app/models/mercury_item/sync_complete_event.rb`
- **Impact:** Regressions in Mercury sync orchestration won't be caught by the test suite.
- **Trigger:** Refactor of the syncer state machine or unlinking flow.
- **Workaround:** Manual QA for Mercury flows today.

### IndexaCapital activity-processor has no dedicated test
- **Issue:** `IndexaCapitalAccount::ActivitiesProcessor` (229 lines) has no test file. The directory `test/models/indexa_capital_account/` only has `data_helpers_test.rb` and `processor_test.rb` (the latter is for the account-level `Processor`, not activities). There is also no `indexa_capital_account/activities_processor_test.rb` to mirror `snaptrade_account/activities_processor_test.rb`.
- **Files:** `app/models/indexa_capital_account/activities_processor.rb`
- **Impact:** The most complex piece of the Indexa pipeline (parsing 9 different activity types into Trades/Transactions) is completely untested at the unit level. A field-name change breaks silently.
- **Trigger:** Any change to Indexa's API.
- **Workaround:** Manual smoke tests with real Indexa data.

### SyncJob.singletons silently re-define a method at runtime
- **Issue:** `app/jobs/sync_job.rb:7-11` uses `sync.define_singleton_method(:balances_only?)` inside a `rescue => e` block. The `rescue` swallows `NoMethodError` (e.g., frozen object), but the failure path is silent: the worker proceeds to `sync.perform` with no flag attached, and the `balances_only?` predicate returns falsy by default — masking the error in a way that may produce a full sync instead of a balances-only sync.
- **Files:** `app/jobs/sync_job.rb`
- **Impact:** Unintended full-sync load (slow) when the singleton attach fails. Hard to debug because the warn log is at INFO-level ("SyncJob: failed to attach…").
- **Trigger:** A `Sync` subclass freezes its instance, or a future migration removes `define_singleton_method` support.
- **Workaround:** Promote the warn to error and re-raise or fail fast.

### `family_exports_controller` / `family_data_export_job` not exercised by specs
- **Issue:** There are no test files matching `family_export*_test.rb` under `test/`. The export pipeline is large (658 lines in `app/models/family/data_exporter.rb`).
- **Files:** `app/models/family/data_exporter.rb`, `app/jobs/family_data_export_job.rb`, `app/controllers/family_exports_controller.rb`
- **Impact:** Export edge cases (currency conversion, missing categories, accounts with no entries) untested.
- **Trigger:** Schema changes to account/category/transaction.
- **Workaround:** None — relies on the sister `data_importer` (which is heavily tested) to exercise symmetry.

## Security Considerations

### Hardcoded demo API key in production code
- **Risk:** `app/models/api_key.rb:13` defines `DEMO_MONITORING_KEY = "demo_monitoring_key_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6"` as a public constant. It is the same string used to authenticate `monitoring` traffic in the deployed app. The string is referenced in `app/jobs/demo_family_refresh_job.rb:50`, `app/models/demo/data_cleaner.rb:21`, `app/models/demo/generator.rb:198,211,216`, and is rendered into logs via `puts` in the generator.
- **Files:** `app/models/api_key.rb:13`, `app/jobs/demo_family_refresh_job.rb`, `app/models/demo/data_cleaner.rb`, `app/models/demo/generator.rb`
- **Current mitigation:** The key has `read` scope and a `:visible` scope filter that excludes it from list views. `revoke!` and `delete` both raise on this key.
- **Recommendations:** Generate per-deployment random monitoring keys, store them in Rails credentials, and remove the constant. Even with read-only scope, a known plaintext key on a long-lived string is a footgun if the scope or filter logic ever changes.

### Encryption-ready guard bypass when keys are missing
- **Risk:** 39 occurrences of `if encryption_ready?` followed by `encrypts :something, deterministic: true`. When Active Record encryption is not configured, **the field is left unencrypted** (no `attr_encrypted` fallback, no KMS). `app/models/api_key.rb`, `app/models/mercury_item.rb`, `app/models/binance_item.rb`, `app/models/questrade_item.rb`, `app/models/enable_banking_item.rb` all follow this pattern.
- **Files:** `app/models/api_key.rb:7-9`, `app/models/mercury_item.rb:16-18`, `app/models/binance_item.rb:11-12`, `app/models/questrade_item.rb:11-13`, `app/models/enable_banking_item.rb:7-12`
- **Current mitigation:** `test/encryption_verification_test.rb` skips when `User.encryption_ready?` is false. The `bin/setup` flow encourages configuring keys.
- **Recommendations:** Add a boot-time check that fails fast (or at least logs a loud warning) if a production deployment lacks encryption keys. Consider a "encrypted-only" CI matrix.

### Deterministic encryption enables email/token correlation
- **Risk:** `encrypts :email, deterministic: true` and `encrypts :token, deterministic: true` mean a DB snapshot (e.g., a backup) can be used to confirm whether two rows share an email or token, even though the plaintext isn't recoverable. Combined with the fact that `User.find_by(email:)` works case-insensitively (`test/encryption_verification_test.rb:29`), the encryption is reversible-equivalent for equality testing.
- **Files:** `app/models/user.rb` (email column), `app/models/api_key.rb` (display_key), `app/models/mercury_item.rb:17` (token)
- **Current mitigation:** Active Record's deterministic encryption.
- **Recommendations:** For tokens/credentials, prefer non-deterministic encryption and store a SHA-256 hash for lookup. Deterministic encryption on `email` is the right tradeoff for login UX, but consider hashing-token pattern elsewhere.

### last_psu_ip is PII, no retention
- **Risk:** See "Enable Banking GDPR/CCPA retention TODO" above. `last_psu_ip` is a user IP, retained indefinitely, and is the most likely PII subject to GDPR Art. 5(1)(e).
- **Files:** `app/models/enable_banking_item.rb`, `app/models/enable_banking_item/provided.rb`
- **Current mitigation:** None.
- **Recommendations:** Implement retention + scheduled scrub (see Tech Debt above).

### Lookbook pinned to old release
- **Risk:** `Gemfile:29` pins `gem "lookbook", "2.3.11"` with a comment "TODO: Remove max version constraint when fixed" referring to upstream issue #712. Pinning to a 2.3.x version means missing later security fixes; the pin exists only because the next versions were broken.
- **Files:** `Gemfile:28-29`
- **Recommendations:** Periodically test the latest Lookbook release; remove the pin and rebuild on a maintenance task.

### SnapTrade and other providers store user_secret / api_key in DB
- **Risk:** `snaptrade_item` (snaptrade user_secret) and other provider credentials are persisted to the DB. Encryption guard is present (per the patterns above), but is opt-in via `encryption_ready?`.
- **Files:** `app/models/snaptrade_item.rb`, `app/models/binance_item.rb`, `app/models/coinbase_item.rb`
- **Current mitigation:** Active Record encryption when keys are set.
- **Recommendations:** Same as the encryption-ready guard above.

## Performance Bottlenecks

### `Family::DataImporter` and `Family::DataExporter` are 1.2k+ lines monoliths
- **Problem:** Both classes process all record types in one pass and may load full result sets. `app/models/family/data_importer.rb:1261` and `app/models/family/data_exporter.rb:658` are the largest non-demo files. Multiple uses of `delete_all` / `destroy_all` after loading intermediate results.
- **Files:** `app/models/family/data_importer.rb`, `app/models/family/data_exporter.rb`
- **Cause:** Designed to be one-shot and self-contained; loads full ActiveRecord relations into memory for hashing/dedup.
- **Improvement path:** Stream record types through `find_each` / `in_batches`. Use `pluck` for the dedup keys. Consider splitting per-record-type processors (one per type) so a single big-family export doesn't lock a worker for 10+ minutes.

### `Account::ProviderImportAdapter#import_holding` deletes via `destroy_all` per call
- **Problem:** `app/models/account/provider_import_adapter.rb:610` runs `future_holdings_query.destroy_all` per holding insert. For a sync that inserts 100 holdings, that's 100 destroy calls (each loads and instantiates each row before destroying).
- **Files:** `app/models/account/provider_import_adapter.rb:599-611`
- **Cause:** Implemented per-holding rather than per-account.
- **Improvement path:** Hoist the `destroy_all` outside the per-security loop, or use `delete_all` (no callbacks needed for raw holdings).

### `app/models/import.rb:264` loads `updated_mappings.map(&:id)` into memory
- **Problem:** `mapping_class.where.not(id: updated_mappings.map(&:id)).destroy_all` materializes the full id list and inlines it into a single SQL statement. For a 100k-row import, this SQL is 100k+ integer literals.
- **Files:** `app/models/import.rb:256-264`
- **Cause:** Naive "find all, then exclude" pattern.
- **Improvement path:** Use `mapping_class.where.not(id: updated_mappings.select(:id)).in_batches(of: 1000).destroy_all` or scope the delete by key columns (`mappable_type`, `mappable_id`).

### Demo generator's `puts`-based progress logging
- **Problem:** `app/models/demo/generator.rb` uses 43 `puts` calls for progress output. Fine for a `bin/rails demo:seed` workflow but easy to accidentally invoke from a web request.
- **Files:** `app/models/demo/generator.rb`
- **Cause:** CLI-style progress reporting mixed into a model.
- **Improvement path:** Move demo seeding to a rake task / runner script; let the model be silent. The `puts "  → Created monitoring API key: #{ApiKey::DEMO_MONITORING_KEY}"` (line 216) is especially problematic — it echoes the hardcoded key to stdout, which may land in CI logs.

### `app/jobs/snaptrade_activities_fetch_job.rb` retries every 10s, up to 6 times (60s window)
- **Problem:** Self-rescheduling with `RETRY_DELAY = 10.seconds` and `MAX_RETRIES = 6` means up to 6 re-enqueues per account. For a family with 5 SnapTrade accounts, that's 30 jobs in the queue while waiting for upstream data.
- **Files:** `app/jobs/snaptrade_activities_fetch_job.rb:21-22,59-66`
- **Cause:** Polling pattern instead of webhook.
- **Improvement path:** SnapTrade has webhook support; the polling pattern is a fallback. Document why polling is required or migrate to webhooks.

## Fragile Areas

### Active Record encryption opt-in via `if encryption_ready?`
- **Files:** 39 occurrences across `app/models/*.rb`
- **Why fragile:** Behavior diverges silently based on env config. Devs who test against a non-encrypted DB will see different storage behavior than prod.
- **Safe modification:** When adding a new encrypted field, mirror the same `if encryption_ready?` block. Do not assume encryption is on. If you remove the guard, audit all 39 call sites for parity.
- **Test coverage:** `test/encryption_verification_test.rb` exists but is skipped when encryption is off. There is no test that runs the non-encryption code path.

### Provider-scaffold TODO comments that read as instructions
- **Files:** `app/models/mercury_item.rb`, `app/models/indexa_capital_account/activities_processor.rb`
- **Why fragile:** Comments are written in second person ("Customize for your provider's format", "Add any provider-specific validation here") as if the file is a starter template, not production code. Future devs may follow the literal instructions and break the parser.
- **Safe modification:** Replace with declarative comments documenting the *current* contract, or delete the TODOs and let the code be the source of truth.
- **Test coverage:** None for the underlying parsing logic.

### `Demo::Generator` is 1,459 lines and reachable from `lib/tasks` / console
- **Files:** `app/models/demo/generator.rb`
- **Why fragile:** A single misnamed association or removed fixture cascades into a broken demo. Mixes "demo" data with a public constant (`ApiKey::DEMO_MONITORING_KEY`) that has real auth effect.
- **Safe modification:** Don't extend with new "demo" data. Move domain logic into a `Demo::Seeder` concern so model methods stay short.
- **Test coverage:** None observed in `test/models/demo_*`.

### `app/models/family/data_importer.rb` is the de-facto import contract
- **Files:** `app/models/family/data_importer.rb`
- **Why fragile:** 1,261 lines, supports 14 record types, custom error types (`MissingReferenceError`, `InvalidRecordError`) — changes ripple across CSV import, restore-from-backup, and the CLI. Mirrored by `data_exporter.rb` (658 lines).
- **Safe modification:** When adding a record type, mirror it in `data_exporter.rb` and add round-trip tests. The class hierarchy is not abstract — every subclass shares raw `class_eval`-style type tables.
- **Test coverage:** Significant; `test/models/family/` has a data_importer_test.

### Encryption-fallback ordering on Active Record 8.x
- **Files:** `app/models/plaid_account.rb:9` (`encrypts :raw_holdings_payload, previous: { attribute: :raw_investments_payload }`)
- **Why fragile:** Uses the `previous:` option for column rename. Re-running migrations after a `down` may fail if the previous-attribute mapping is no longer recognized by the encryption config.
- **Safe modification:** When renaming an encrypted column, the `previous:` block is required in code AND in the migration. Keep them in sync.
- **Test coverage:** `test/encryption_verification_test.rb` exists for User; not for PlaidAccount.

## Scaling Limits

### `self_hosted` Rack::Attack limits are 100x higher than SaaS
- **Current capacity:** SaaS: 100 req/hour per token, 200 req/hour per IP. Self-hosted: 10,000 req/hour per token, 20,000 req/hour per IP.
- **Limit:** Self-hosted limit is per-process; multiple workers compound.
- **Files:** `config/initializers/rack_attack.rb:35,50`
- **Scaling path:** Switch from per-process Rack::Attack cache to a shared cache store (Redis) so limits are global. Already in `Gemfile` (`redis`).

### Polling-based provider sync (SnapTrade, Questrade, Indexa) doesn't scale beyond 1k accounts
- **Current capacity:** Each new account adds N retry jobs. With 1k accounts × 6 retries × 10s = 6k job slots reserved for 60s windows.
- **Limit:** Sidekiq queue depth grows linearly with active accounts.
- **Files:** `app/jobs/snaptrade_activities_fetch_job.rb`, `app/jobs/questrade_activities_fetch_job.rb`, `app/jobs/indexa_capital_activities_fetch_job.rb`
- **Scaling path:** Webhook-driven (most providers support it), or backoff with exponential delay (currently fixed 10s).

### Demo-mode reseed regenerates the entire family on every refresh
- **Current capacity:** `app/jobs/demo_family_refresh_job.rb` rebuilds the demo family + provider connections on a schedule.
- **Limit:** For a large demo family (1459-line generator), this is several minutes of background work; running on a 24h cadence can pile up if a job is still running.
- **Files:** `app/jobs/demo_family_refresh_job.rb`, `app/models/demo/generator.rb`
- **Scaling path:** Add `sidekiq-unique-jobs` lock (`lock: :until_executed`) so a fresh schedule doesn't overlap a running one.

## Dependencies at Risk

### `lookbook` pinned to `2.3.11`
- **Risk:** Stuck on an old release due to upstream issue #712. Misses security and feature updates.
- **Impact:** Dev-only (mounted in development), so production is unaffected, but dev parity suffers.
- **Migration plan:** Periodically re-test the latest Lookbook version; remove pin when issue resolves.

### `connection_pool ~> 2.5`
- **Risk:** Pinned to 2.x because 3.0 "breaks sidekiq 8.x" (per `Gemfile:34` comment).
- **Impact:** Stuck on a major version. Sidekiq 8.x is also pinned, so this is a coordinated migration.
- **Migration plan:** Track Sidekiq's connection_pool 3.0 compatibility; upgrade both together.

### `plaid`, `snaptrade ~> 2.0`, `stripe` SDKs evolve quickly
- **Risk:** Plaid and SnapTrade have aggressive API versioning; Sure pins to a major. Webhook payload formats may drift.
- **Impact:** Silent breakage in `app/controllers/webhooks_controller.rb` if a payload schema changes.
- **Migration plan:** Pin SDK versions in CI, watch for `webhook_body` parse errors in Sentry.

## Missing Critical Features

### No n+1 query detection in dev/test
- **Problem:** The `bullet` gem is not in `Gemfile`. With 110+ model subdirectories and `includes(...)` scattered across controllers, query regressions are silent.
- **Files:** `Gemfile` (absence)
- **Blocks:** Performance regressions in `app/controllers/reports_controller.rb` (1,167 lines, many `includes` calls) and `app/models/family/data_exporter.rb` won't be caught by tests.

### `IndexaCapital` cleanup job is a no-op (see Tech Debt)
- **Problem:** `app/jobs/indexa_capital_connection_cleanup_job.rb` does not actually delete the connection at the provider.
- **Blocks:** Compliant account unlinking; provider-side resource cleanup; potential PII retention at vendor.

### `set_current_balance` windowing on Enable Banking
- **Problem:** `app/models/enable_banking_account/processor.rb` cannot pass an explicit window, forcing full-history recalc.
- **Blocks:** Reasonable sync times for Enable Banking users with years of history.

### No per-provider rate limit coordination
- **Problem:** `app/services/api_rate_limiter.rb` and `app/services/noop_api_rate_limiter.rb` exist but the noop variant is the default. Multiple workers hitting a single provider can stampede.
- **Files:** `app/services/api_rate_limiter.rb`, `app/services/noop_api_rate_limiter.rb`
- **Blocks:** Reliable provider API usage; burst-protection beyond Rack::Attack.

## Test Coverage Gaps

### Indexa Capital activity processor has no unit test
- **What's not tested:** `IndexaCapitalAccount::ActivitiesProcessor#process_activity` for any of the 9 activity types.
- **Files:** `app/models/indexa_capital_account/activities_processor.rb`
- **Risk:** Indexa API field renames break categorization silently.
- **Priority:** High.

### Mercury syncer/unlinking/provided modules are untested
- **What's not tested:** `MercuryItem::Syncer#perform_sync`, `MercuryItem::Provided` mixin, `MercuryItem::Unlinking` mixin.
- **Files:** `app/models/mercury_item/syncer.rb`, `app/models/mercury_item/provided.rb`, `app/models/mercury_item/unlinking.rb`
- **Risk:** State machine regressions in Mercury lifecycle.
- **Priority:** Medium.

### `Family::DataExporter` is not tested directly
- **What's not tested:** Round-trip `DataExporter` → `DataImporter` for each record type.
- **Files:** `app/models/family/data_exporter.rb`
- **Risk:** Backups that don't restore cleanly.
- **Priority:** High.

### Encryption fallback path (no keys) is not tested
- **What's not tested:** Behavior of `if encryption_ready?` blocks when keys are absent. `test/encryption_verification_test.rb` skips rather than asserts fallback behavior.
- **Files:** 39 model files with `if encryption_ready?` guards
- **Risk:** Silent unencrypted storage in dev or misconfigured prod.
- **Priority:** Medium.

### API v1 spec coverage is partial (28 specs vs ~30 controllers)
- **What's not tested:** Some API endpoints have no rswag spec. Endpoints covered by Minitest but not rswag lose OpenAPI documentation parity.
- **Files:** `spec/requests/api/v1/` (28 files)
- **Risk:** Out-of-date OpenAPI doc for endpoints that drift.
- **Priority:** Low (AGENTS.md mandates rswag-as-docs-only; behavioral coverage is in Minitest).

### Webhook signature validation paths lack direct tests
- **What's not tested:** `Plaid` and `Stripe` webhook signature failures (`app/controllers/webhooks_controller.rb:11,28,54`). Tested implicitly by integration tests but no explicit "bad signature returns 400" test.
- **Files:** `app/controllers/webhooks_controller.rb`
- **Risk:** Signature bypass regressions.
- **Priority:** High.

### `app/jobs/identify_recurring_transactions_job.rb` debounce path
- **What's not tested:** The debounce logic (cache check, advisory lock, stale-scheduled guard) is structurally complex and has no observed test.
- **Files:** `app/jobs/identify_recurring_transactions_job.rb`
- **Risk:** Concurrent runs produce duplicate recurring-transaction entries.
- **Priority:** Medium.
