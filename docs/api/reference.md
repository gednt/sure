<!-- generated-by: gsd-doc-writer -->

# API Reference

The Sure API is a JSON over HTTP API served by the Rails application under
`/api/v1`. All endpoints (except `auth/*` and `users/*` self-service) require
authentication and operate on resources owned by the authenticated user's
family.

The machine-readable, executable OpenAPI specification is maintained at
`docs/api/openapi.yaml` and regenerated from `spec/requests/api/v1/*_spec.rb`
via rswag. This document is a human-readable companion covering the same
surface.

## Base URLs

- Production: `https://app.sure.am/api/v1` <!-- VERIFY: production base URL -->
- Local development: `http://localhost:3000/api/v1`

All responses are JSON. The base controller forces `request.format = :json`
on every request.

## Authentication

The API supports two authentication mechanisms. The `auth/*` endpoints are the
only public routes; everything else requires a credential.

### API key (recommended for scripts and integrations)

Send the key in the `X-Api-Key` request header. API keys are created from
**Settings → API Keys** in the Sure UI and stored hashed in the `api_keys`
table. Each key has an explicit scope set (`read` or `read_write`) and is
subject to per-key rate limiting.

```http
GET /api/v1/accounts
X-Api-Key: sk_live_…
```

Successful API key responses include the headers:

- `X-RateLimit-Limit`
- `X-RateLimit-Remaining`
- `X-RateLimit-Reset` (Unix seconds)

When the limit is exceeded the API returns `429 Too Many Requests` with
`Retry-After` and a `rate_limit_exceeded` body (see [Error codes](#error-codes)).

### OAuth 2.0 (Doorkeeper)

OAuth is provided by the Doorkeeper mount wired in `config/routes.rb`. Send a
bearer token in the `Authorization` header:

```http
GET /api/v1/accounts
Authorization: Bearer <access_token>
```

Required scope is `read` or `read_write`. `read_write` implicitly grants `read`
access. The OAuth metadata endpoints are exposed at:

- `GET /.well-known/oauth-authorization-server`
- `GET /.well-known/oauth-protected-resource`
- `POST /register` (dynamic client registration)

The Doorkeeper mount handles standard `/oauth/authorize`, `/oauth/token`, and
`/oauth/revoke` flows.

### Mobile / SSO authentication

The `auth/*` endpoints exist for first-party mobile clients and SSO flows and
are not part of the public partner API. They live under `Api::V1::AuthController`
and skip the standard `authenticate_request!` filter:

- `POST /api/v1/auth/signup` — register a new user (invite code may be
  required), atomically creating the user, claiming the invite, and issuing
  device tokens.
- `POST /api/v1/auth/login` — email + password login, with optional
  `otp_code` when MFA is enabled.
- `POST /api/v1/auth/refresh` — exchange a refresh token for a new access
  token.
- `POST /api/v1/auth/sso_exchange`, `POST /api/v1/auth/sso_link`,
  `POST /api/v1/auth/sso_create_account` — SSO bridge flows.
- `PATCH /api/v1/auth/enable_ai` — opt the authenticated user into AI
  features (requires `read_write` scope).

These endpoints return `access_token`, `refresh_token`, `token_type`,
`expires_in`, and a `user` payload.

## Scopes

| Scope        | Grants                                      |
| ------------ | ------------------------------------------- |
| `read`       | `GET` access to all resource endpoints      |
| `read_write` | Full `read` access plus all write methods   |

A token with `read_write` satisfies any check that requires `read`. Endpoints
that mutate state require `read_write`. `Api::V1::BaseController#authorize_scope!`
implements the hierarchy; missing scope returns `403` with
`insufficient_scope`.

## Pagination

Index endpoints are paginated using Pagy. Two query parameters are supported:

| Parameter  | Default | Constraints |
| ---------- | ------- | ----------- |
| `page`     | `1`     | integer ≥ 1 |
| `per_page` | `25`    | integer 1–100; values above 100 are clamped to 100 |

The response envelope for paginated collections is defined by the
`Pagination` schema in `docs/api/openapi.yaml` and includes `page`,
`per_page`, `total_count`, and `total_pages`.

## Endpoints overview

The complete route table for the API namespace is declared in
`config/routes.rb` under `namespace :api { namespace :v1 { … } }`. The list
below mirrors the routes file and the OpenAPI spec; method/path columns are
the canonical reference. `Auth` indicates whether an `X-Api-Key` or OAuth
bearer token is required (the `auth/*` and `users/reset*` routes are
unauthenticated by design).

| Method     | Path                                              | Description                                | Auth |
| ---------- | ------------------------------------------------- | ------------------------------------------ | ---- |
| `GET`      | `/api/v1/accounts`                                | List accounts (paginated)                  | Yes  |
| `GET`      | `/api/v1/accounts/{id}`                           | Retrieve an account                        | Yes  |
| `GET`      | `/api/v1/balance_sheet`                           | Family balance sheet snapshot              | Yes  |
| `GET`      | `/api/v1/balances`                                | List balances                              | Yes  |
| `GET`      | `/api/v1/balances/{id}`                           | Retrieve a balance                         | Yes  |
| `GET`      | `/api/v1/budget_categories`                       | List budget categories                     | Yes  |
| `GET`      | `/api/v1/budget_categories/{id}`                  | Retrieve a budget category                 | Yes  |
| `GET`      | `/api/v1/budgets`                                 | List budgets                               | Yes  |
| `GET`      | `/api/v1/budgets/{id}`                            | Retrieve a budget                          | Yes  |
| `GET`      | `/api/v1/categories`                              | List categories                            | Yes  |
| `POST`     | `/api/v1/categories`                              | Create a category                          | Yes  |
| `GET`      | `/api/v1/categories/{id}`                         | Retrieve a category                        | Yes  |
| `GET`      | `/api/v1/chats`                                   | List AI chats                              | Yes  |
| `POST`     | `/api/v1/chats`                                   | Create an AI chat                          | Yes  |
| `GET`      | `/api/v1/chats/{id}`                              | Retrieve a chat                            | Yes  |
| `PATCH`    | `/api/v1/chats/{id}`                              | Update a chat                              | Yes  |
| `DELETE`   | `/api/v1/chats/{id}`                              | Delete a chat                              | Yes  |
| `POST`     | `/api/v1/chats/{chat_id}/messages`                | Send a chat message                        | Yes  |
| `POST`     | `/api/v1/chats/{chat_id}/messages/retry`          | Retry the last failed message              | Yes  |
| `GET`      | `/api/v1/family_exports`                          | List family data exports                   | Yes  |
| `POST`     | `/api/v1/family_exports`                          | Request a new family export                | Yes  |
| `GET`      | `/api/v1/family_exports/{id}`                     | Retrieve an export                         | Yes  |
| `GET`      | `/api/v1/family_exports/{id}/download`            | Download the generated export file         | Yes  |
| `GET`      | `/api/v1/family_settings`                         | Family-level settings                      | Yes  |
| `GET`      | `/api/v1/holdings`                                | List holdings                              | Yes  |
| `GET`      | `/api/v1/holdings/{id}`                           | Retrieve a holding                         | Yes  |
| `POST`     | `/api/v1/import_sessions`                         | Start a chunked CSV import session         | Yes  |
| `GET`      | `/api/v1/import_sessions/{id}`                    | Retrieve an import session                 | Yes  |
| `POST`     | `/api/v1/import_sessions/{id}/chunks`             | Upload a CSV chunk for an import session   | Yes  |
| `POST`     | `/api/v1/import_sessions/{id}/publish`            | Publish a finalized import session         | Yes  |
| `GET`      | `/api/v1/imports`                                 | List imports                               | Yes  |
| `POST`     | `/api/v1/imports`                                 | Create a single-shot import                | Yes  |
| `GET`      | `/api/v1/imports/{id}`                            | Retrieve an import                         | Yes  |
| `GET`      | `/api/v1/imports/{id}/rows`                       | Inspect parsed import rows                 | Yes  |
| `POST`     | `/api/v1/imports/preflight`                       | Dry-run an import payload                  | Yes  |
| `GET`      | `/api/v1/merchants`                               | List merchants                             | Yes  |
| `POST`     | `/api/v1/merchants`                               | Create a merchant                          | Yes  |
| `GET`      | `/api/v1/merchants/{id}`                          | Retrieve a merchant                        | Yes  |
| `GET`      | `/api/v1/provider_connections`                    | List provider (bank/brokerage) connections | Yes  |
| `GET`      | `/api/v1/recurring_transactions`                  | List recurring transactions                | Yes  |
| `POST`     | `/api/v1/recurring_transactions`                  | Create a recurring transaction             | Yes  |
| `GET`      | `/api/v1/recurring_transactions/{id}`             | Retrieve a recurring transaction           | Yes  |
| `PATCH`    | `/api/v1/recurring_transactions/{id}`             | Update a recurring transaction             | Yes  |
| `DELETE`   | `/api/v1/recurring_transactions/{id}`             | Delete a recurring transaction             | Yes  |
| `GET`      | `/api/v1/rejected_transfers`                      | List rejected transfers                    | Yes  |
| `GET`      | `/api/v1/rejected_transfers/{id}`                 | Retrieve a rejected transfer               | Yes  |
| `GET`      | `/api/v1/rule_runs`                               | List rule runs                             | Yes  |
| `GET`      | `/api/v1/rule_runs/{id}`                          | Retrieve a rule run                        | Yes  |
| `GET`      | `/api/v1/rules`                                   | List rules                                 | Yes  |
| `GET`      | `/api/v1/rules/{id}`                              | Retrieve a rule                            | Yes  |
| `GET`      | `/api/v1/securities`                              | List securities                            | Yes  |
| `GET`      | `/api/v1/securities/{id}`                         | Retrieve a security                        | Yes  |
| `GET`      | `/api/v1/security_prices`                         | List security prices                       | Yes  |
| `GET`      | `/api/v1/security_prices/{id}`                    | Retrieve a security price                  | Yes  |
| `GET`      | `/api/v1/syncs`                                   | List sync jobs                             | Yes  |
| `GET`      | `/api/v1/syncs/latest`                            | Latest sync per provider                   | Yes  |
| `GET`      | `/api/v1/syncs/{id}`                              | Retrieve a sync job                        | Yes  |
| `GET`      | `/api/v1/tags`                                    | List tags                                  | Yes  |
| `POST`     | `/api/v1/tags`                                    | Create a tag                               | Yes  |
| `GET`      | `/api/v1/tags/{id}`                               | Retrieve a tag                             | Yes  |
| `PATCH`    | `/api/v1/tags/{id}`                               | Update a tag                               | Yes  |
| `DELETE`   | `/api/v1/tags/{id}`                               | Delete a tag                               | Yes  |
| `GET`      | `/api/v1/trades`                                  | List trades                                | Yes  |
| `POST`     | `/api/v1/trades`                                  | Create a trade                             | Yes  |
| `GET`      | `/api/v1/trades/{id}`                             | Retrieve a trade                           | Yes  |
| `PATCH`    | `/api/v1/trades/{id}`                             | Update a trade                             | Yes  |
| `DELETE`   | `/api/v1/trades/{id}`                             | Delete a trade                             | Yes  |
| `GET`      | `/api/v1/transactions`                            | List transactions                          | Yes  |
| `POST`     | `/api/v1/transactions`                            | Create a transaction                       | Yes  |
| `GET`      | `/api/v1/transactions/{id}`                       | Retrieve a transaction                     | Yes  |
| `PATCH`    | `/api/v1/transactions/{id}`                       | Update a transaction                       | Yes  |
| `DELETE`   | `/api/v1/transactions/{id}`                       | Delete a transaction                       | Yes  |
| `GET`      | `/api/v1/transfers`                               | List transfers                             | Yes  |
| `GET`      | `/api/v1/transfers/{id}`                          | Retrieve a transfer                        | Yes  |
| `GET`      | `/api/v1/usage`                                   | API usage & rate-limit info                | Yes  |
| `GET`      | `/api/v1/valuations`                              | List valuations                            | Yes  |
| `POST`     | `/api/v1/valuations`                              | Create a valuation                         | Yes  |
| `GET`      | `/api/v1/valuations/{id}`                         | Retrieve a valuation                       | Yes  |
| `PATCH`    | `/api/v1/valuations/{id}`                         | Update a valuation                         | Yes  |
| `POST`     | `/api/v1/sync`                                    | Enqueue a manual sync job                  | Yes  |
| `POST`     | `/api/v1/auth/signup`                             | Register a new user                        | No   |
| `POST`     | `/api/v1/auth/login`                              | Email + password login                     | No   |
| `POST`     | `/api/v1/auth/refresh`                            | Refresh an access token                    | No   |
| `POST`     | `/api/v1/auth/sso_exchange`                       | Exchange SSO code for tokens               | No   |
| `POST`     | `/api/v1/auth/sso_link`                           | Link an SSO identity to an account         | No   |
| `POST`     | `/api/v1/auth/sso_create_account`                 | Create an account from SSO                 | No   |
| `PATCH`    | `/api/v1/auth/enable_ai`                          | Enable AI features for the current user    | Yes  |
| `DELETE`   | `/api/v1/users/reset`                             | Reset account data                         | No   |
| `GET`      | `/api/v1/users/reset/status`                      | Check the status of an account reset       | No   |
| `DELETE`   | `/api/v1/users/me`                                | Delete the current user                    | Yes  |

## Request and response formats

### Headers

All authenticated requests should send either `X-Api-Key` or
`Authorization: Bearer <token>`. `Content-Type: application/json` is required
for endpoints that accept a body.

### Date and time parameters

Endpoints that accept date filters (e.g. transaction listing) expect ISO 8601
dates. The base controller parses them with `Date.iso8601` and raises
`InvalidFilterError` (rendered as `validation_failed`) on invalid input.

### Error envelope

Errors are returned as a JSON object with an `error` code and a human-readable
`message`. Validation errors may also include an `errors` array, and
rate-limit responses include a `details` object with the limit and reset
window.

```json
{
  "error": "validation_failed",
  "message": "date must be an ISO 8601 date",
  "errors": ["date must be an ISO 8601 date"]
}
```

## Error codes

| HTTP | `error` code            | Meaning                                                                                  |
| ---- | ----------------------- | ---------------------------------------------------------------------------------------- |
| 400  | `bad_request`           | Required parameters are missing or invalid                                               |
| 401  | `unauthorized`          | API key or OAuth token is missing, invalid, expired, or the user is deactivated           |
| 403  | `forbidden`             | Authenticated user is not allowed to access this family resource                         |
| 403  | `insufficient_scope`    | Token does not have the required scope (use `read_write` for write operations)           |
| 403  | `feature_disabled`      | The called feature (e.g. AI) is not enabled for the authenticated user                   |
| 404  | `record_not_found`      | The requested resource does not exist or is outside the caller's family                  |
| 422  | `validation_failed`     | Input failed model or business validation (e.g. invalid filter value)                    |
| 429  | `rate_limit_exceeded`   | API key exceeded its request quota; see `Retry-After` and the `details.reset_in_seconds` |
| 500  | `internal_server_error` | Unexpected server error (logged with the request id from `log_api_access`)               |

## Rate limits

API key authentication is rate-limited per key by `ApiRateLimiter`. The
remaining quota is exposed on every response via the `X-RateLimit-Limit`,
`X-RateLimit-Remaining`, and `X-RateLimit-Reset` headers. OAuth bearer tokens
are not currently rate-limited at this layer.

When the limit is exceeded the API returns `429 Too Many Requests` with a
`Retry-After` header (seconds until the window resets) and a body of the form:

```json
{
  "error": "rate_limit_exceeded",
  "message": "Rate limit exceeded. Try again in 3600 seconds.",
  "details": {
    "limit": 1000,
    "current": 1000,
    "reset_in_seconds": 3600
  }
}
```

Use `GET /api/v1/usage` to inspect the current quota and consumption for the
authenticated key or token.

<!-- VERIFY: Default rate limit values and reset window are configured by
ApiRateLimiter; the values above are illustrative and not necessarily the
defaults. -->

## Family-scoped access

All resource endpoints enforce family isolation. `Api::V1::BaseController`
records `current_resource_owner` from the authenticated user, and individual
controllers scope their queries to `current_resource_owner.family_id`. A
mismatched family yields `403 forbidden` (not `404`) so that a token cannot be
used to probe for the existence of resources in other families.

## Versioning and compatibility

The API is currently at `v1`. Breaking changes will be introduced as new
versioned namespaces (`/api/v2`); existing `v1` routes will be supported
alongside for the deprecation window defined in the release notes.

## Related documents

- `docs/api/openapi.yaml` — executable OpenAPI 3.0 spec
- `docs/api/transactions.md`, `docs/api/categories.md`, `docs/api/tags.md`,
  `docs/api/merchants.md`, `docs/api/chats.md`, `docs/api/imports.md`,
  `docs/api/users.md` — resource-specific guides
- `docs/guides/configuration.md` — runtime configuration and environment
  variables
- `docs/architecture/overview.md` — system architecture and component map
