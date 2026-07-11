<!-- generated-by: gsd-doc-writer -->
# Development

This guide covers the day-to-day workflow for hacking on Sure locally: scripts, code style, branch conventions, and the PR process. For first-time setup see [Getting Started](getting-started.md); for environment variables see [Configuration](configuration.md).

## Local Setup

The full prerequisites and installation walkthrough live in [Getting Started](getting-started.md). In short:

1. Clone the repo and `cd` into it.
2. Copy `.env.local.example` to `.env.local` (preconfigured defaults for `localhost` dev).
3. Run `bin/setup` — installs Bundler dependencies, runs `npm install` plus `npm run tokens:build`, prepares the database, and clears logs.
4. (Recommended) Load the demo data: `rake demo_data:default` (credentials `user@example.com` / `Password1!`).
5. Start the dev server: `bin/dev` (web + Tailwind watcher + Sidekiq via `Procfile.dev`).

You can also use a Dev Container in VSCode — see the [Dev Containers guide](https://code.visualstudio.com/docs/devcontainers/containers) and the `.devcontainer/` folder in this repo. The Dev Container ships with `selenium/standalone-chrome`, so system tests work without a local Chrome install.

## Build Commands

Scripts are defined in `package.json` and the standard Rails `bin/` wrappers. There is no separate `npm run build` step for production; the Rails asset pipeline and `tailwindcss:watch` handle assets during development.

| Command | Description |
|---------|-------------|
| `bin/setup` | Idempotent environment bootstrap (Bundler, npm, tokens, DB prepare, tmp/log clean). |
| `bin/dev` | Start Rails server, Tailwind watcher, and Sidekiq worker via `Procfile.dev`. |
| `bin/rails server` | Run the Rails server alone (use `bin/dev` unless you don't need Sidekiq or CSS rebuilds). |
| `bin/rails console` | Open a Rails console for interactive work. |
| `bin/rails db:prepare` | Create, migrate, and seed the development database. |
| `bin/rails tailwindcss:watch` | Rebuild Tailwind CSS on file changes (also started by `bin/dev`). |
| `bin/rails tailwindcss:build` | One-shot Tailwind build (used in CI / production). |
| `npm install` | Install Node dependencies (Biome, etc.). |
| `npm run tokens:build` | Generate `app/assets/tailwind/sure-design-system/_generated.css` from design tokens. |
| `npm run tokens:check` | Build tokens and fail if the generated CSS is dirty (used in CI). |
| `rake demo_data:default` | Seed the local DB with demo users, accounts, and transactions. |

## Code Style

Sure uses RuboCop for Ruby and Biome for JavaScript and CSS. The Tailwind build is run by the Rails pipeline; linting happens separately.

### Ruby — RuboCop

- Config: `.rubocop.yml` (inherits from `rubocop-rails-omakase`) and `.erb_lint.yml` (for ERB templates).
- Lint: `bin/rubocop`
- Auto-correct safe cops: `bin/rubocop -A`
- Formatting rules: 2-space indent, double-quoted strings (enforced by `Style/StringLiterals` in `erb-lint`).
- Naming: `snake_case` for methods/variables, `CamelCase` for classes/modules. Follow Rails conventions for folder and file names.

### JavaScript / CSS — Biome

- Config: `biome.json` (v1.9.x). Linting scope is `app/javascript/**/*.js`.
- Lint: `npm run lint`
- Lint + auto-fix: `npm run lint:fix`
- Format check: `npm run format:check`
- Format + write: `npm run format`
- Style check (lint + format): `npm run style:check`
- Style fix: `npm run style:fix`
- Naming: `lowerCamelCase` for variables/functions, `PascalCase` for classes/components. Let Biome format the code rather than hand-formatting.

### ERB

- Config: `.erb_lint.yml` (default linters + `Style/StringLiterals` for double quotes, plus a `DeprecatedClasses` rule that blocks raw `text-gray-*` / `bg-gray-*` / `border-gray-*` / `text-white` / `bg-white` / `border-white` classes in favor of design tokens).
- Run: bundled with `bin/rubocop` for the Rubocop-bridged linter portion; for full ERB linting use the `erb_lint` gem directly.

### Design system tokens

- Source of truth: `design/tokens/sure.tokens.json` (Style Dictionary).
- Generated CSS: `app/assets/tailwind/sure-design-system/_generated.css` — must be committed after `npm run tokens:build`.
- Use semantic tokens (`bg-container`, `text-primary`, `border-primary`, `text-destructive`, etc.) instead of raw Tailwind palette classes.
- For shared shapes (alert, button, disclosure, dialog, menu, input), reach for a `DS::*` component in `app/components/DS/` before writing new markup.

### Editor settings

- `.editorconfig` enforces UTF-8, LF line endings, and 2-space indent at the editor level.
- `.gitattributes` normalizes line endings for the repository.

## Branch Conventions

- Default branch: `main`. All PRs target `main`.
- Branch naming: there is no strictly enforced prefix convention, but the contributing guide uses descriptive names such as `my-new-feature` and recent commit history shows both topic-style names and `area/topic` names. Pick a short, descriptive name.
- Keep branches in sync with `main` before requesting a review (`git pull --rebase origin main` or merge `main` in).

## PR Process

The full PR checklist lives in [CONTRIBUTING.md](../../CONTRIBUTING.md). Summary:

1. Fork the repository and create a feature branch from `main`.
2. Make small, cohesive commits. Imperative subject ≤ 72 characters (for example: `Add account balance validation`). Include rationale in the body and reference issues (`#123`).
3. Run the local quality gates before pushing:
   - `bin/rails test` (Minitest suite)
   - `bin/rubocop` (Ruby style)
   - `npm run lint` and `npm run format` (JS/CSS via Biome)
   - `bin/brakeman` (security scan) for non-trivial PRs
4. Push your branch and open a Pull Request against `main`. Enable **Allow edits from maintainers** so reviewers can collaborate on the PR.
5. If your PR addresses an issue, link it with a keyword (e.g. `fixes #123`) in the description.
6. CI must pass — RuboCop, Biome, Brakeman, importmap audit, Minitest, and system tests all run on every PR (see `.github/workflows/ci.yml`).
7. Wait for a maintainer review. There is no formal SLA; priority is generally given to previous committers.

### API PRs

When touching `app/controllers/api/v1/`, the API consistency checklist (see [CONTRIBUTING.md](../../CONTRIBUTING.md) and `.cursor/rules/api-endpoint-consistency.mdc`) requires:

- Minitest behavioral coverage in `test/controllers/api/v1/{resource}_controller_test.rb`.
- `spec/requests/api/v1/{resource}_spec.rb` exists for OpenAPI / rswag documentation only — no behavioral `expect`/`assert_*` calls there.
- rswag auth uses the `X-Api-Key` pattern consistently (no OAuth/Bearer in docs).
- Regenerate the OpenAPI spec with `RAILS_ENV=test bundle exec rake rswag:specs:swaggerize` after endpoint changes.

### UI PRs

When touching `.erb`, view components, or `.css`:

- Use semantic design tokens, not raw Tailwind palette.
- Reach for `DS::*` components (`app/components/DS/`) before writing new alert/button/dialog/menu/input shapes.
- If you find yourself duplicating a hand-rolled shape twice in a diff with no `DS` equivalent, propose a new `DS::*` primitive first.
- Use the `icon` helper (never `lucide_icon` directly), translate user-facing strings via `t()`, and avoid arbitrary `*-[Npx]` values when a scale token fits.

## Issue Reporting

Use the GitHub issue templates under `.github/ISSUE_TEMPLATE/` — there are templates for [bug reports](https://github.com/we-promise/sure/issues/new/choose) and other requests. For security vulnerabilities, follow the disclosure process in [SECURITY.md](../../SECURITY.md) rather than opening a public issue.

## Security & Configuration Tips

- Never commit secrets. Start from `.env.local.example`; use `.env.local` for development only.
- Run `bin/brakeman` before major PRs.
- Prefer environment variables over hard-coded values, and read [Configuration](configuration.md) before adding new ones.
- Every PR to `main` also runs an automatic [Pipelock](https://github.com/we-promise/pipelock) security scan (`.github/workflows/pipelock.yml`) for leaked secrets and agent security risks. No local configuration is required.

## Where to Go Next

- [Getting Started](getting-started.md) — first-time local setup and first run.
- [Configuration](configuration.md) — full environment variable reference.
- [Architecture Overview](../architecture/overview.md) — how the Rails app, providers, Sidekiq, and Action Cable fit together.
- [Onboarding guide](../onboarding/guide.md) — a deeper walkthrough of the codebase and conventions.
- [LLM guides](../llm-guides/) — guides intended for AI coding assistants (also useful for humans).
