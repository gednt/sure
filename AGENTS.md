# Repository Guidelines

This repository follows the GSD + openspec development workflow (worktree per phase/plan, verifier-gated plans, auto-push, planning-artifact promotion, cross-platform portability). See [## Development workflow](#development-workflow) below.

In addition, the Rails-specific conventions, build commands, API and design-system rules are documented in the remaining sections.

## # Development workflow

1. Open a Worktree.

2. Copy the `.env.local` (without reading) from the `main` checkout to the worktree (and `.env.test` if needed for tests).

3. Develop a plan using `/openspec-propose` or `/gsd-plan-phase` (Use openspec propose for simpler tasks and gsd-plan-phase for complex ones)

   1. `{the-correct-agent-for-the-task} statement of the problem or feature, or etc`

   2. Wait for the artifacts to be drafted.

   3. Run the verifier to assert the plan completeness and adherence to the task being solved.

4. Invoke a new agent to do the task. Using `/openspec-apply {plan}` or `/gsd-phase {x}` depending on the tool you used to develop the plan.

5. Run all the unit, integration and E2E tests.

6. After all tests pass, commit the changes to `main`

7. Delete worktree.

8. Do the cleanup jobs for git and docker (if docker was used).

## Git workflow

After every commit in this repo, push to `origin` automatically. Do not ask for confirmation.

```bash
git push
```

If the push fails (auth, network, non-fast-forward), surface the error and stop — do not force-push.

## Documentation promotion

When a phase is verified complete and merged to `main`, promote its relevant planning artifacts from `.planning/` to `docs/` so shipped documentation is visible to readers who don't look inside `.planning/`.

**`.planning/` is never modified by promotion.** It remains the working source of truth that agents read from. Promotion is a one-way copy to `docs/` only.

### Rules

1. **Promotion happens on `main`, after the phase merge.** Not in the worktree.
2. **Copy, don't move.** `.planning/` is never modified by promotion.
3. **One commit per promotion.** Message: `docs: promote phase {n} artifacts to docs/`.
4. **`docs/` is append-only.** Promoted files are added and never edited.
5. **Never edit `docs/` directly.** All edits happen in `.planning/`; `docs/` is a promotion target only.
6. **Decide your own structure.** Choose whatever folder layout and filenames make sense for `docs/` based on what was actually produced in the phase. Don't follow a rigid template — the agent decides the proper organization.
7. **Don't promote agent-internal files.** `PROJECT.md`, `REQUIREMENTS.md`, `ROADMAP.md`, `STATE.md`, `REVIEW-FIX.md`, and `config.json` stay in `.planning/` only — agents rely on them there. Promote phase outputs (plans, verification reports, research summaries) and any user-facing documentation that emerged during the phase.

## Repo context

- Remote: `origin` (Gitea) — configured via `git remote add origin <your-gitea-url>`
- Branch: `main`
- Planning docs in `.planning/` are tracked in git (`commit_docs: true`)

## Cross-platform rules

Development happens on macOS, Linux, Windows 11 ARM64, and Windows x64. To keep the repo portable:

- **Line endings:** `.gitattributes` enforces `* text=auto eol=lf`. Never commit CRLF.
- **Paths in scripts:** always forward slashes; never `C:\`; never use PowerShell-only cmdlets in shared scripts (use `sh`/`bash`).
- **Docker:** all dev/build/test operations run inside Docker (when used); Dockerfiles are multi-arch (`linux/arm64` + `linux/amd64`).
- **No host toolchain assumed:** never call `npm` directly when a Docker compose service exists for it; prefer `docker compose run` for tooling that has a container.

## Worktree workflow

All changes are made under git worktrees; the main checkout (the repo root you cloned into) stays clean on `main` and is never edited directly. This enables parallel phase/plan work without stashing and keeps `main` deployable at all times.

### Layout

```
<repo-root>/                                       # main checkout — stays on `main`, clean
├── .git/                                          # shared git dir (worktrees link here)
├── .planning/                                     # project context (read-only from worktrees)
├── .worktrees/                                    # all worktrees live here
│   ├── phase-0/                                   #   phase worktree
│   ├── 00-01/                                     #   plan worktree (one plan at a time)
│   ├── phase-1/
│   └── 01-03/
└── ...                                            # no source files in main checkout until merge
```

### Branch naming

- Phase worktree: `gsd/phase-{n}-{slug}` (e.g., `gsd/phase-0-foundation`)
- Plan worktree: `gsd/{plan-id}` (e.g., `gsd/00-01`, `gsd/01-03`)
- Hotfix worktree: `gsd/hotfix-{slug}`

### Lifecycle

**Create a worktree** (start of a phase or plan):

```bash
git worktree add .worktrees/{slug} -b gsd/{slug}
# Example:
git worktree add .worktrees/phase-0 -b gsd/phase-0-foundation
git worktree add .worktrees/00-01 -b gsd/00-01
```

**`.env.local` is gitignored and not tracked**, so each new worktree must copy it from the main checkout before bringing the stack up. Without this, Rails falls back to default ports/secrets and can collide with the main checkout's running stack:

```bash
cp .env.local .worktrees/{slug}/.env.local
cp .env.test .worktrees/{slug}/.env.test   # when running tests in the worktree
```

**Work inside the worktree:**

```bash
cd .worktrees/{slug}
# ... make changes, commit, push (per the auto-push policy above)
```

**Merge back to main** (when phase/plan is verified complete):

```bash
# From the main checkout:
cd <repo-root>
git fetch origin
git merge --no-ff gsd/{slug}
git push
```

**Remove the worktree** (after merge, to reclaim disk):

```bash
git worktree remove .worktrees/{slug}
git branch -d gsd/{slug}   # delete the merged branch
```

### Rules

1. **Never edit the main checkout directly.** All source changes happen in a worktree. The only exception is `.planning/` updates that span phases (roadmap edits, requirement re-mapping) — those can land on `main` directly; and edits to `AGENTS.md` itself, which the orchestrator may apply on `main` since the worktree workflow it describes is the thing being edited.
2. **One worktree per phase or plan.** Don't nest worktrees or share working directories.
3. **Commit + push from inside the worktree.** The auto-push policy applies everywhere.
4. **Worktrees are disposable.** If a plan is abandoned, `git worktree remove --force .worktrees/{slug}` and delete the branch. No data is lost — the main checkout is untouched.
5. **Run services from the worktree.** `bin/dev` / `bin/rails` / `docker compose` run from inside the active worktree, so the process sees the in-progress code, not `main`.
6. **Clean up after merge.** Don't accumulate stale worktrees — remove them once their branch is merged to `main`.

### Practical example: Phase 0

```bash
# From main checkout:
git worktree add .worktrees/phase-0 -b gsd/phase-0-foundation
cd .worktrees/phase-0
cp .env.local .worktrees/phase-0/.env.local

# Work happens here:
bin/setup
bin/dev
bin/rails test
# ... edit code, commit, push (auto-push policy)

# When Phase 0 is verified complete:
cd <repo-root>
git fetch origin
git merge --no-ff gsd/phase-0-foundation
git push
git worktree remove .worktrees/phase-0
git branch -d gsd/phase-0-foundation
```

## Verification gate for plans and proposals

Anything that produces a plan or proposal must be verified before it is treated as ready for execution. This is the pre-execution counterpart to the `Verify before merge.` / `Fix verification findings.` loop in the worktree workflow above — same `gsd-verifier` subagent, same `gsd-code-fixer` follow-up, same convergence-exit policy.

### Proposal sources

| Source                                                       | Output artifacts                       | Path                                           |
| ------------------------------------------------------------ | -------------------------------------- | ---------------------------------------------- |
| `openspec-propose` skill (or `/opsx-propose` cursor command) | `proposal.md`, `design.md`, `tasks.md` | `openspec/changes/{change-name}/`              |
| `gsd-planner` subagent (spawned by `/gsd-plan-phase`)        | `PLAN.md`                              | `.planning/phases/{NN-name}/{NN}-{NN}-PLAN.md` |

The cursor command `/opsx-propose` is a thin wrapper around the `openspec-propose` skill — they produce the same artifacts in the same paths. Treat them as one source.

### Required behavior

After any of the sources above produces artifacts, dispatch `gsd-verifier` against those artifacts before the plan is treated as ready for execution. Verdict handling mirrors the post-execution loop exactly:

- `gaps_found` — **hard stop.** Do not start implementation or merge. Fix the gap (regenerate / re-plan) and re-verify.
- `human_needed` — **blocks** until the human checkpoint clears, then re-verify.
- `status: passed` — proceed to execution (`/opsx:apply` for openspec output; `/gsd-execute-phase` for `gsd-planner` output).

If the verifier surfaces fixable findings, dispatch `gsd-code-fixer` with a translated `REVIEW.md` (one section per finding) — same shape as the post-execution loop. The fixer applies atomic commits per finding (auto-pushed per the Git workflow policy). If the same finding reappears after two fixer iterations, break the loop and escalate to the developer — the agent pair is oscillating. Loop verifier → fixer (with translation) until the verifier reports `status: passed`.

### Rules

1. **No plan ships without verifier sign-off.** A `proposal.md`, `design.md`, `tasks.md`, or `PLAN.md` is not "ready" until `gsd-verifier` has reported `status: passed` against it. Self-reported completeness from the planner / propose source is not sufficient.
2. **Verdict authority is the server / subagent output, not the caller's judgment.** Do not override a `gaps_found` verdict because the artifacts "look fine" on a quick read.
3. **Apply to both source families uniformly.** Running `openspec-propose` (or `/opsx-propose`) instead of `gsd-planner` does not exempt the proposal from verification — both produce implementation-ready artifacts and both go through the same gate.
4. **Skipping the gate requires explicit developer approval.** If a proposal must skip verification (e.g., a trivial single-file change), the developer must say so in writing in the conversation log. The agent does not self-approve skips.

## Database migrations

All schema changes go through Rails migrations — never apply DDL by hand or via ad-hoc scripts.

- New migrations: `bin/rails g migration <Name>` (never edit an applied migration — add a new one to change course).
- Migrations run inside the worktree's database (test DB in CI, dev DB locally). Never run migrations against the main checkout's database while another worktree is using the same Postgres service — the schema is shared.
- One concern per migration. Commit the migration with the model/code that uses it in the same commit.

## Project Structure & Module Organization

- Code: `app/` (Rails MVC, services, jobs, mailers, components), JS in `app/javascript/`, styles/assets in `app/assets/` (Tailwind, images, fonts).
- Config: `config/`, environment examples in `.env.local.example` and `.env.test.example`.
- Data: `db/` (migrations, seeds), fixtures in `test/fixtures/`.
- Tests: `test/` mirroring `app/` (e.g., `test/models/*_test.rb`).
- Tooling: `bin/` (project scripts), `docs/` (guides), `public/` (static), `lib/` (shared libs).

## Build, Test, and Development Commands

- Setup: `cp .env.local.example .env.local && bin/setup` — install deps, set DB, prepare app.
- Run app: `bin/dev` — starts Rails server and asset/watchers via `Procfile.dev`.
- Test suite: `bin/rails test` — run all Minitest tests; add `TEST=test/models/user_test.rb` to target a file.
- Lint Ruby: `bin/rubocop` — style checks; add `-A` to auto-correct safe cops.
- Lint/format JS/CSS: `npm run lint` and `npm run format` — uses Biome.
- Security scan: `bin/brakeman` — static analysis for common Rails issues.

## Coding Style & Naming Conventions

- Ruby: 2-space indent, `snake_case` for methods/vars, `CamelCase` for classes/modules. Follow Rails conventions for folders and file names.
- Views: ERB checked by `erb-lint` (see `.erb_lint.yml`). Avoid heavy logic in views; prefer helpers/components.
- JavaScript: `lowerCamelCase` for vars/functions, `PascalCase` for classes/components. Let Biome format code.
- Commit small, cohesive changes; keep diffs focused.

## Testing Guidelines

- Framework: Minitest (Rails). Name files `*_test.rb` and mirror `app/` structure.
- Run: `bin/rails test` locally and ensure green before pushing.
- Fixtures/VCR: Use `test/fixtures` and existing VCR cassettes for HTTP. Prefer unit tests plus focused integration tests.

## Commit & Pull Request Guidelines

- Commits: Imperative subject ≤ 72 chars (e.g., "Add account balance validation"). Include rationale in body and reference issues (`#123`).
- PRs: Clear description, linked issues, screenshots for UI changes, and migration notes if applicable. Ensure CI passes, tests added/updated, and `rubocop`/Biome are clean.

## Security & Configuration Tips

- Never commit secrets. Start from `.env.local.example`; use `.env.local` for development only.
- Run `bin/brakeman` before major PRs. Prefer environment variables over hard-coded values.

## API Development Guidelines

### OpenAPI Documentation (MANDATORY)
When adding or modifying API endpoints in `app/controllers/api/v1/`, you **MUST** create or update corresponding OpenAPI request specs for **DOCUMENTATION ONLY**:

1. **Location**: `spec/requests/api/v1/{resource}_spec.rb`
2. **Framework**: RSpec with rswag for OpenAPI generation
3. **Schemas**: Define reusable schemas in `spec/swagger_helper.rb`
4. **Generated Docs**: `docs/api/openapi.yaml`
5. **Regenerate**: Run `RAILS_ENV=test bundle exec rake rswag:specs:swaggerize` after changes

### Post-commit API consistency (LLM checklist)
After every API endpoint commit, ensure: (1) **Minitest** behavioral coverage in `test/controllers/api/v1/{resource}_controller_test.rb` (no behavioral assertions in rswag); (2) **rswag** remains docs-only (no `expect`/`assert_*` in `spec/requests/api/v1/`); (3) **rswag auth** uses the same API key pattern everywhere (`X-Api-Key`, not OAuth/Bearer). Full checklist: [.cursor/rules/api-endpoint-consistency.mdc](.cursor/rules/api-endpoint-consistency.mdc).

## Design System Hygiene (UI PRs)

When a PR touches `.erb`, view components, or `.css`:

1. **Tokens, not palette.** Use functional tokens from `app/assets/tailwind/sure-design-system.css` (`bg-warning/10`, `text-destructive`, `bg-container`, `text-primary`, `border-primary`). No raw Tailwind palette (`bg-blue-50`, `text-red-500`, hex literals).
2. **Reach for `DS::*` first.** Check `app/components/DS/` (`DS::Alert`, `DS::Button`, `DS::Disclosure`, `DS::Dialog`, `DS::Menu`, etc.) before writing an alert, badge, button, disclosure, dialog, or input shape.
3. **Two copies → lift to DS.** Same hand-rolled shape ≥2× in a diff with no DS equivalent → propose a new `DS::*` primitive before the second copy lands.
4. **Conventions.** Use the `icon` helper (never `lucide_icon` directly), no raw SVG outside DS primitives, user-facing strings via `t()`, avoid arbitrary `*-[Npx]` values when a scale token fits.

Reviewers escalate violations of (2)–(3) to close/rewrite; (1) and (4) are request-changes.

## Securities Providers

If you need to add a new securities price provider (Tiingo, EODHD, Binance-style crypto, etc.), see [adding-a-securities-provider.md](./docs/llm-guides/adding-a-securities-provider.md) for the full walkthrough — provider class, registry wiring, MIC handling, settings UI, locales, and tests.

## Debug Logging for Provider Syncs

When a provider sync/import path hits a recoverable error or suspicious partial response that support may need to inspect later, prefer `DebugLogEntry.capture(...)` over `Rails.logger.*`.

- Record support-relevant diagnostics in the debug log so they surface in the super-admin-friendly `/settings/debug` UI.
- Include `category`, `level`, `message`, `source`, `provider_key`, and useful structured `metadata`.
- Attach `family` and `account_provider` when available so support can filter and trace the affected connection.
- Reserve raw Rails logging for low-value local noise; anything operators may need should go to the debug log.

## Providers: Pending Transactions and FX Metadata (SimpleFIN/Plaid/Lunchflow)

- Pending detection
  - SimpleFIN: pending when provider sends `pending: true`, or when `posted` is blank/0 and `transacted_at` is present.
  - Plaid: pending when Plaid sends `pending: true` (stored at `transaction.extra["plaid"]["pending"]` for bank/credit transactions imported via `PlaidEntry::Processor`).
  - Lunchflow: pending when API returns `isPending: true` in transaction response (stored at `transaction.extra["lunchflow"]["pending"]`).
- Storage (extras)
  - Provider metadata lives on `Transaction#extra`, namespaced (e.g., `extra["simplefin"]["pending"]`).
  - SimpleFIN FX: `extra["simplefin"]["fx_from"]`, `extra["simplefin"]["fx_date"]`.
- UI
  - Shows a small “Pending” badge when `transaction.pending?` is true.
- Variability
  - Some providers don’t expose pendings; in that case nothing is shown.
- Configuration (default-off)
  - SimpleFIN runtime toggles live in `config/initializers/simplefin.rb` via `Rails.configuration.x.simplefin.*`.
  - Lunchflow runtime toggles live in `config/initializers/lunchflow.rb` via `Rails.configuration.x.lunchflow.*`.
  - ENV-backed keys:
    - `SIMPLEFIN_INCLUDE_PENDING=1` (forces `pending=1` on SimpleFIN fetches when caller didn’t specify a `pending:` arg)
    - `SIMPLEFIN_DEBUG_RAW=1` (logs raw payload returned by SimpleFIN)
    - `LUNCHFLOW_INCLUDE_PENDING=1` (forces `include_pending=true` on Lunchflow API requests)
    - `LUNCHFLOW_DEBUG_RAW=1` (logs raw payload returned by Lunchflow)

### Provider support notes

- SimpleFIN: supports pending + FX metadata; stored under `extra["simplefin"]`.
- Plaid: supports pending when the upstream Plaid payload includes `pending: true`; stored under `extra["plaid"]`.
- Plaid investments: investment transactions currently do not store pending metadata.
- Lunchflow: supports pending via `include_pending` query parameter; stored under `extra["lunchflow"]`.
- Manual/CSV imports: no pending concept.

<!-- GSD Configuration — managed by gsd-core installer -->
# Instructions for GSD

- Use the gsd-core skill when the user asks for GSD or uses a `gsd-*` command.
- Treat `/gsd-...` or `gsd-...` as command invocations and load the matching file from `.github/skills/gsd-*`.
- When a command says to spawn a subagent, prefer a matching custom agent from `.github/agents`.
- Do not apply GSD workflows unless the user explicitly asks for them.
- After completing any `gsd-*` command (or any deliverable it triggers: feature, bug fix, tests, docs, etc.), ALWAYS: (1) offer the user the next step by prompting via `ask_user`; repeat this feedback loop until the user explicitly indicates they are done.
<!-- /GSD Configuration -->
