# Quick Start: Self-Host Sure with Docker

Get Sure running in under 5 minutes with these simple steps.

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running

## One-Minute Setup (Copy & Paste)

```bash
# 1. Create directory and download compose file
mkdir -p ~/sure && cd ~/sure
curl -o compose.yml https://raw.githubusercontent.com/we-promise/sure/main/compose.example.yml

# 2. Generate a random secret key
echo "SECRET_KEY_BASE=$(openssl rand -hex 64)" > .env

# 3. Start Sure
docker compose up -d
```

That's it! Open http://localhost:3000 and create your account.

## What Just Happened?

1. **Created a `sure` directory** - Where all your data lives
2. **Downloaded compose.yml** - The Docker configuration file
3. **Generated a secret key** - Used to encrypt sensitive data
4. **Started Sure** - Runs in the background (detached mode)

## Next Steps

### Access Your Instance

Visit http://localhost:3000 and click "Create your account" to get started.

### (Optional) Secure Your Instance

For production use (internet-accessible), add these to your `.env` file:

```bash
# Generate a database password
POSTGRES_PASSWORD=$(openssl rand -hex 32)

# Restrict future signups
ONBOARDING_STATE=closed
```

Then restart:
```bash
docker compose down
docker compose up -d
```

### Common Commands

```bash
# View logs
docker compose logs -f

# Stop Sure
docker compose down

# Update to latest version
docker compose pull && docker compose up -d

# Reset everything (WARNING: deletes all data)
docker compose down -v
```

## Troubleshooting

### Port 3000 already in use?

Edit `compose.yml` and change the port:
```yaml
ports:
  - "3001:3000"  # Change 3001 to your preferred port
```

### Database connection errors?

First time setup? Run this to reset:
```bash
docker compose down -v  # WARNING: This deletes all data
docker compose up -d
```

### Need help?

- [Discord](https://discord.gg/36ZGBsxYEK)
- [GitHub Discussions](https://github.com/we-promise/sure/discussions)

## Advanced Configuration

For production deployments, SSL, backups, and AI features, see:
- [Full Docker Guide](docker.md)
- [AI Features](ai.md)
- [Pipelock Security](pipelock.md)