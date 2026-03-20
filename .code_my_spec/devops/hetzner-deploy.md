# MetricFlow: Hetzner Deployment

## Server Details

| Property        | Value                                      |
|-----------------|--------------------------------------------|
| Provider        | Hetzner Cloud                              |
| Server name     | `fuellytics-prod` (shared with fuellytics) |
| Server type     | cax11 (ARM64, 2 vCPU, 4 GB RAM, 40 GB SSD)|
| OS              | Ubuntu 24.04                               |
| IP              | `46.225.105.88`                            |
| SSH user        | `deploy`                                   |
| Firewall        | `fuellytics-fw` (Hetzner cloud firewall)   |
| hcloud context  | `fuellytics`                               |

**This server is shared with fuellytics.** Both projects run as separate Docker Compose
stacks. They share the same Caddy reverse proxy and the `caddy_proxy` Docker network.

---

## 1. Directory Layout on Server

```
/opt/metric_flow/
├── app/                     # prod -- rsync target (TODO: set up)
│   ├── docker-compose.yml
│   ├── Dockerfile
│   └── ...
├── uat/                     # uat -- rsync target
│   ├── docker-compose.yml
│   ├── Dockerfile
│   └── ...
├── .env.prod                 # prod secrets (TODO: create)
└── .env.uat                  # uat secrets
```

---

## 2. Docker Compose Configuration

### Single Compose, Multiple Environments

The same `docker-compose.yml` serves both UAT and prod. The environment is controlled
by the `--env-file` flag and the `-p` (project name) flag. The database name comes from
`POSTGRES_DB` in each env file — **never hardcoded** in the compose file.

```bash
# UAT
docker compose -p metric-flow-uat --env-file /opt/metric_flow/.env.uat up -d

# Prod
docker compose -p metric-flow-prod --env-file /opt/metric_flow/.env.prod up -d
```

Key points:
- `POSTGRES_DB` must be set in each env file (`metric_flow_uat` / `metric_flow_prod`)
- Project name isolates containers: `metric-flow-uat-app-1` vs `metric-flow-prod-app-1`
- Each stack gets its own Docker volume for Postgres data (namespaced by project name)
- Joins `caddy_proxy` external network so Caddy can route to it
- Has its own `internal` network isolating the db

### Container Names on caddy_proxy Network

```
metric-flow-uat-app-1     # UAT app (port 4000)
metric-flow-prod-app-1    # Prod app (port 4000) -- after setup
```

---

## 3. Caddy Configuration

Caddy runs in the `fuellytics-prod` compose stack and routes traffic for ALL projects.
The Caddyfile lives at `/opt/fuellytics/app/Caddyfile`.

Add MetricFlow routes to the existing Caddyfile:

```caddy
# MetricFlow Production
metric-flow.app {
    reverse_proxy metric-flow-prod-app-1:4000 {
        health_uri /health
        health_interval 10s
        health_timeout 5s
        health_status 2xx
    }
}

# MetricFlow UAT
uat.metric-flow.app {
    reverse_proxy metric-flow-uat-app-1:4000 {
        health_uri /health
        health_interval 10s
        health_timeout 5s
        health_status 2xx
    }
}
```

After editing:
```bash
# Validate
docker exec fuellytics-prod-caddy-1 caddy validate --config /etc/caddy/Caddyfile

# Reload (no downtime)
docker exec fuellytics-prod-caddy-1 caddy reload --config /etc/caddy/Caddyfile
```

---

## 4. Environment Variables

### Required Env Vars (.env.prod / .env.uat)

```bash
# Database
POSTGRES_PASSWORD=<strong-random-password>
POSTGRES_DB=metric_flow_prod          # or metric_flow_uat for UAT

# Phoenix
SECRET_KEY_BASE=<64-byte-hex-from-mix-phx-gen-secret>
PHX_HOST=metric-flow.app                    # or uat.metric-flow.app for UAT
PHX_SERVER=true

# Email (Resend)
RESEND_API_KEY=<resend-api-key>

# Encryption
CLOAK_KEY=<base64-encoded-32-byte-key>

# Error Tracking
SENTRY_DSN=<sentry-dsn-url>

# File Storage (Tigris S3-compatible)
AWS_ACCESS_KEY_ID=<tigris-access-key>
AWS_SECRET_ACCESS_KEY=<tigris-secret-key>

# AI
ANTHROPIC_API_KEY=<anthropic-key>

# OAuth (if configured)
GITHUB_CLIENT_ID=<github-oauth-client-id>
GITHUB_CLIENT_SECRET=<github-oauth-client-secret>
GOOGLE_CLIENT_ID=<google-oauth-client-id>
GOOGLE_CLIENT_SECRET=<google-oauth-client-secret>
OAUTH_BASE_URL=https://metric-flow.app     # or https://uat.metric-flow.app
```

### Setting Secrets on Server

```bash
# Edit env file directly
ssh deploy@46.225.105.88 "nano /opt/metric_flow/.env.uat"

# Generate a new secret key base locally
mix phx.gen.secret

# Generate a new Cloak key locally
:crypto.strong_rand_bytes(32) |> Base.encode64()

# Verify keys are present (without showing values)
ssh deploy@46.225.105.88 "grep -o '^[A-Z_]*=' /opt/metric_flow/.env.uat"
```

### Permissions

```bash
chmod 600 /opt/metric_flow/.env.prod /opt/metric_flow/.env.uat
chown deploy:deploy /opt/metric_flow/*.env
```

---

## 5. Deploy Scripts

### Deploy UAT

No deploy scripts exist yet in `scripts/`. Here's the pattern to follow:

```bash
#!/usr/bin/env bash
# scripts/deploy-uat
set -euo pipefail

SERVER="deploy@46.225.105.88"
APP_DIR="/opt/metric_flow/uat"
ENV_FILE="/opt/metric_flow/.env.uat"
PROJECT="metric-flow-uat"

echo "==> Syncing code to server..."
rsync -az --delete \
  --exclude='.git' \
  --exclude='_build' \
  --exclude='deps' \
  --exclude='assets/node_modules' \
  --exclude='.code_my_spec' \
  --exclude='test' \
  --exclude='envs' \
  ./ "$SERVER:$APP_DIR/"

echo "==> Building and restarting containers..."
ssh "$SERVER" "cd $APP_DIR && \
  docker compose -p $PROJECT --env-file $ENV_FILE up -d --build"

echo "==> Running migrations..."
ssh "$SERVER" "cd $APP_DIR && \
  docker compose -p $PROJECT --env-file $ENV_FILE exec app /app/bin/migrate"

echo "==> Done: https://uat.metric-flow.app"
```

### Deploy Prod

```bash
#!/usr/bin/env bash
# scripts/deploy
set -euo pipefail

SERVER="deploy@46.225.105.88"
APP_DIR="/opt/metric_flow/app"
ENV_FILE="/opt/metric_flow/.env.prod"
PROJECT="metric-flow-prod"

echo "==> Syncing code to server..."
rsync -az --delete \
  --exclude='.git' \
  --exclude='_build' \
  --exclude='deps' \
  --exclude='assets/node_modules' \
  --exclude='.code_my_spec' \
  --exclude='test' \
  --exclude='envs' \
  ./ "$SERVER:$APP_DIR/"

echo "==> Building and restarting containers..."
ssh "$SERVER" "cd $APP_DIR && \
  docker compose -p $PROJECT --env-file $ENV_FILE up -d --build"

echo "==> Running migrations..."
ssh "$SERVER" "cd $APP_DIR && \
  docker compose -p $PROJECT --env-file $ENV_FILE exec app /app/bin/migrate"

echo "==> Done: https://metric-flow.app"
```

---

## 6. Database Management

### Containers

| Environment | Container                    | User          | Database           |
|-------------|------------------------------|---------------|--------------------|
| UAT         | `metric-flow-uat-db-1`       | `metric_flow` | `metric_flow_uat`  |
| Prod        | `metric-flow-prod-db-1`      | `metric_flow` | `metric_flow_prod` |

Each has its own Docker volume (`metric-flow-uat_pgdata`, `metric-flow-prod_pgdata`).
Databases are fully isolated -- separate containers, separate volumes, separate networks.

**These are NOT shared with fuellytics.** Fuellytics has its own db containers
(`fuellytics-prod-db-1`, `fuellytics-uat-db-1`) on separate volumes.

### Interactive psql

```bash
docker exec -it metric-flow-uat-db-1 psql -U metric_flow metric_flow_uat
docker exec -it metric-flow-prod-db-1 psql -U metric_flow metric_flow_prod
```

### Migrations

```bash
# Run pending migrations
docker compose -p metric-flow-uat --env-file /opt/metric_flow/.env.uat \
  exec app /app/bin/migrate

# Rollback
docker compose -p metric-flow-uat --env-file /opt/metric_flow/.env.uat \
  exec app /app/bin/metric_flow eval \
  'MetricFlow.Release.rollback(MetricFlow.Repo, 20260101000000)'

# Remote IEx console
docker compose -p metric-flow-uat --env-file /opt/metric_flow/.env.uat \
  exec app /app/bin/metric_flow remote
```

### Backups

```bash
# Manual backup
docker exec metric-flow-uat-db-1 \
  pg_dump -U metric_flow metric_flow_uat \
  | gzip > /opt/backups/metric-flow-uat-$(date +%Y%m%d-%H%M%S).sql.gz

# Restore
docker compose -p metric-flow-uat --env-file /opt/metric_flow/.env.uat stop app
docker exec metric-flow-uat-db-1 psql -U metric_flow -c "DROP DATABASE metric_flow_uat;"
docker exec metric-flow-uat-db-1 psql -U metric_flow -c "CREATE DATABASE metric_flow_uat;"
gunzip -c /opt/backups/metric-flow-uat-YYYYMMDD-HHMMSS.sql.gz \
  | docker exec -i metric-flow-uat-db-1 psql -U metric_flow metric_flow_uat
docker compose -p metric-flow-uat --env-file /opt/metric_flow/.env.uat start app
```

---

## 7. Build Notes

The cax11 has 4 GB RAM. Elixir compilation is memory-hungry. If Docker build OOMs:

1. Add temporary swap: `fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile`
2. Or build locally on ARM Mac and push to a registry

---

## 8. Operational Commands

### Check Status

```bash
# All containers
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Logs
docker logs metric-flow-uat-app-1 --tail 50 -f

# Health
docker inspect metric-flow-uat-app-1 | jq '.[0].State.Health'
```

### Restart

```bash
# Restart without rebuild
docker compose -p metric-flow-uat --env-file /opt/metric_flow/.env.uat restart app

# Rebuild and restart
docker compose -p metric-flow-uat --env-file /opt/metric_flow/.env.uat up -d --build app
```

### Disk Cleanup

```bash
docker system df
docker image prune -f
docker builder prune -f
```

---

## 9. TODO / Outstanding Setup

- [x] Create `/opt/metric_flow/app/` directory on server for prod
- [x] Create `/opt/metric_flow/.env.prod` with all required vars (incl. `POSTGRES_DB`)
- [x] Single `docker-compose.yml` with env-driven `POSTGRES_DB` (no separate prod file needed)
- [x] Add MetricFlow routes to the Caddyfile on server
- [x] Set up DNS records for `metric-flow.app` and `uat.metric-flow.app` in Cloudflare
- [ ] Create deploy scripts at `scripts/deploy` and `scripts/deploy-uat`
- [ ] Set up cron backup jobs for metric_flow databases
- [ ] Add `/health` route to the Phoenix router
- [ ] Add Resend API key to prod and UAT env files
- [ ] Verify sending domain in Resend dashboard (add DNS records to Cloudflare)
