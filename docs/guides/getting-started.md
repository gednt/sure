<!-- generated-by: gsd-doc-writer -->
# Getting Started

This guide walks you through running Sure locally for development and making your first contribution. If you want to **self-host** Sure (e.g. with Docker) rather than hack on the code, see the [Docker Quickstart Guide](../hosting/docker-quickstart.md) instead.

## Prerequisites

Before you start, make sure your machine has the following:

- **Ruby** `3.4.9` — pinned in `.ruby-version`. Use a Ruby version manager such as `rbenv`, `asdf`, or `mise` to install it.
- **PostgreSQL** `>= 9.3` — latest stable recommended. Sure uses Postgres-specific features (JSONB, etc.).
- **Redis** `>= 5.4` — required for the Rails cache, Action Cable, and Sidekiq.
- **Node.js** and **npm** — used to build Tailwind design tokens via `npm run tokens:build` (Biome is the JS/CSS linter and formatter).
- **libvips** — required for image processing through Active Storage. See [libvips on GitHub](https://github.com/libvips/libvips) for installation instructions.
- **Bundler** — installed via `gem install bundler` (the `bin/setup` script will ensure it's present).

OS-specific setup guides maintained by the community:

- [Mac dev setup](https://github.com/we-promise/sure/wiki/Mac-Dev-Setup-Guide)
- [Linux dev setup](https://github.com/we-promise/sure/wiki/Linux-Dev-Setup-Guide)
- [Windows dev setup](https://github.com/we-promise/sure/wiki/Windows-Dev-Setup-Guide)
- [Dev containers guide](https://code.visualstudio.com/docs/devcontainers/containers)

## Installation

Follow these steps to clone the repository and prepare a working development environment.

1. **Clone the repository**

   ```bash
   git clone https://github.com/we-promise/sure.git
   cd sure
   ```

2. **Configure local environment variables**

   ```bash
   cp .env.local.example .env.local
   ```

   The local example file is preconfigured with sensible defaults for `localhost` development (WebAuthn, OIDC redirect, SimpleFIN/Lunchflow debug flags, etc.). For the full list of supported environment variables, see [Configuration](configuration.md).

3. **Install dependencies and prepare the database**

   ```bash
   bin/setup
   ```

   `bin/setup` is idempotent and will:
   - Install Bundler and run `bundle install`
   - Run `npm install` and `npm run tokens:build` to generate the Tailwind design tokens
   - Prepare the database with `bin/rails db:prepare`
   - Clear logs and tmpfiles
   - Restart the application

## First Run

Start the development server (Rails + Tailwind watcher + Sidekiq worker via `Procfile.dev`):

```bash
bin/dev
```

Once the server is up, open <http://localhost:3000> in your browser. You should see the Sure login page.

To explore the app with sample accounts and transactions, load the demo seed data:

```bash
rake demo_data:default
```

The demo data ships with these credentials:

- Email: `user@example.com`
- Password: `Password1!`

## Common Setup Issues

A few things that trip up new contributors:

- **Wrong Ruby version.** The project pins Ruby `3.4.9` in `.ruby-version`. If `bin/setup` fails with version-related errors, verify your active Ruby matches (`ruby -v`). Use `rbenv`/`asdf`/`mise` to switch.
- **PostgreSQL not running or wrong host.** If `bin/rails db:prepare` fails to connect, make sure Postgres is running locally and that `DB_HOST`/`DB_PORT`/`POSTGRES_USER`/`POSTGRES_PASSWORD` in `.env.local` match your setup. Inside a devcontainer, set `DB_HOST=db` (the variable comment in `.env.local.example` notes this).
- **Redis not running.** Sidekiq and the Rails cache require Redis. If you see `Redis::CannotConnectError`, start Redis locally (e.g. `redis-server` or via your OS service manager) and confirm `REDIS_URL` in `.env.local` matches.
- **Missing design tokens / Tailwind not building.** If the UI looks unstyled, run `npm install && npm run tokens:build` to regenerate `app/assets/tailwind/sure-design-system/_generated.css`. The CI runs `npm run tokens:check` to ensure generated CSS is committed.
- **libvips missing for Active Storage.** Image uploads (e.g. avatars) will fail at processing time. Install libvips via your package manager (e.g. `brew install vips`, `apt install libvips-dev`).
- **Port 3000 already in use.** Override the Puma port with `PORT=3001 bin/dev` (or change `PORT` in `.env.local`).

## Running Tests and Linters

Quick reference for the local quality gates (see [Development](development.md) and [Testing](testing.md) for full detail):

```bash
# Ruby tests (Minitest, mirrors app/ structure)
bin/rails test

# Ruby style
bin/rubocop

# JavaScript / CSS lint + format
npm run lint
npm run format

# Security scan
bin/brakeman
```

## Next Steps

- Read the [Architecture Overview](../architecture/overview.md) to understand how the Rails app, providers, Sidekiq, and Action Cable fit together.
- Review [Configuration](configuration.md) before tweaking environment variables.
- Skim [CONTRIBUTING.md](../../CONTRIBUTING.md) for PR conventions, commit message style, and the API consistency checklist.
- Join the [Discord](https://discord.gg/36ZGBsxYEK) if you get stuck or want to discuss a change before opening a PR.
