# MetricFlow: Hetzner Deployment

## Server Details

| Property        | Value                                      |
|-----------------|--------------------------------------------|
| Provider        | Hetzner Cloud                              |
| Server hostname | `fuellytics-prod` (also hosts metric_flow + desert_first_cleaning) |
| Server type     | cax11 (ARM64, 2 vCPU, 4 GB RAM, 40 GB SSD)|
| OS              | Ubuntu 24.04                               |
| Public IP       | `178.156.143.212`                          |
| SSH user        | `root`                                     |
| Firewall        | Hetzner cloud firewall                     |
| hcloud context  | `fuellytics`                               |

This server hosts three unrelated projects (`metric_flow`, `fuellytics`,
`desert_first_cleaning`). They share a single Caddy and a single Postgres
container, both managed by the `infra` compose stack at `/opt/shared/`.
See `infra-stack.md` for the shared services.

---

## 1. Directory Layout on Server

```
/opt/metric_flow/
├── app/                     # prod -- rsync target for `scripts/deploy`
│   ├── docker-compose.prod.yml
│   ├── Dockerfile
│   └── ...
├── uat/                     # uat -- rsync target for `scripts/deploy-uat`
│   ├── docker-compose.yml
│   ├── Dockerfile
│   └── ...
├── .env.prod                # prod secrets (chmod 644 currently — tighten to 600)
└── .env.uat                 # uat secrets
```

The shared infra stack lives at `/opt/shared/` — see `infra-stack.md`.

---

## 2. Docker Compose Configuration

### Two separate compose files

UAT and prod use **different** compose files because their service names and
DB targets differ:

| Env  | Compose file                | Project name        | DB                 |
|------|-----------------------------|---------------------|--------------------|
| uat  | `docker-compose.yml`        | `metric-flow-uat`   | `metric_flow_uat`  |
| prod | `docker-compose.prod.yml`   | `metric-flow-prod`  | `metric_flow_prod` |

Both define a single `app` service with no local `db` — `DATABASE_URL` points
at the shared `infra-postgres-1` container on the external `db_net` network.

```bash
# UAT
docker compose -p metric-flow-uat --env-file /opt/metric_flow/.env.uat up -d --build

# Prod
docker compose -f docker-compose.prod.yml -p metric-flow-prod \
  --env-file /opt/metric_flow/.env.prod up -d --build
```

Key points:
- `POSTGRES_DB` must be set in each env file (`metric_flow_uat` / `metric_flow_prod`)
- `POSTGRES_PASSWORD` must match `/opt/shared/.env` exactly
- Project name isolates containers: `metric-flow-uat-app-1` vs `metric-flow-prod-app-1`
- App joins both `caddy_proxy` (for Caddy) and `db_net` (for Postgres) — both `external: true`

### Container names on shared networks

```
metric-flow-uat-app-1     # UAT app   (port 4000 via caddy_proxy)
metric-flow-prod-app-1    # Prod app  (port 4000 via caddy_proxy)
```

---

## 3. Caddy Configuration

The Caddyfile lives at **`/opt/shared/Caddyfile`** (managed by the `infra`
compose stack — see `infra-stack.md`). MetricFlow's routes are already in there:

```caddy
metric-flow.app {
    reverse_proxy metric-flow-prod-app-1:4000
}

uat.metric-flow.app {
    reverse_proxy metric-flow-uat-app-1:4000
}
```

After editing the Caddyfile:

```bash
ssh root@178.156.143.212 "docker exec infra-caddy-1 caddy validate --config /etc/caddy/Caddyfile && \
  docker exec infra-caddy-1 caddy reload --config /etc/caddy/Caddyfile"
```

---

## 4. Environment Variables

### Required env vars (`.env.prod` / `.env.uat`)

```bash
# Database (must match /opt/shared/.env)
POSTGRES_PASSWORD=<shared-password-from-/opt/shared/.env>
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

# AI
ANTHROPIC_API_KEY=<anthropic-key>

# OAuth providers (optional — only the ones in use)
GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...
GOOGLE_ADS_DEVELOPER_TOKEN=...
GOOGLE_ADS_LOGIN_CUSTOMER_ID=...
FACEBOOK_APP_ID=...
FACEBOOK_APP_SECRET=...
QUICKBOOKS_CLIENT_ID=...
QUICKBOOKS_CLIENT_SECRET=...
QUICKBOOKS_API_URL=...

# File storage (Tigris S3-compatible) — not currently set in prod env
AWS_ACCESS_KEY_ID=<tigris-access-key>
AWS_SECRET_ACCESS_KEY=<tigris-secret-key>

# OAuth callback host — not currently set in prod env
OAUTH_BASE_URL=https://metric-flow.app
```

> **Currently missing from `.env.prod`:** `AWS_ACCESS_KEY_ID`,
> `AWS_SECRET_ACCESS_KEY`, `OAUTH_BASE_URL`, `GITHUB_CLIENT_ID`,
> `GITHUB_CLIENT_SECRET`. Add them when those features are enabled in prod.

### Setting secrets on server

```bash
# Edit env file directly
ssh root@178.156.143.212 "nano /opt/metric_flow/.env.uat"

# Generate a new secret key base locally
mix phx.gen.secret

# Generate a new Cloak key locally
:crypto.strong_rand_bytes(32) |> Base.encode64()

# Verify keys are present (without showing values)
ssh root@178.156.143.212 "grep -oE '^[A-Z_]+=' /opt/metric_flow/.env.prod"
```

### Permissions

```bash
chmod 600 /opt/metric_flow/.env.prod /opt/metric_flow/.env.uat
chown root:root /opt/metric_flow/*.env*
```

> **Currently `-rw-r--r--`** — anyone with shell access can read them. Tighten
> to `chmod 600`.

---

## 5. Deploy Scripts

The repo has working deploy scripts at `scripts/deploy` and `scripts/deploy-uat`.
They:

1. `rsync` the working tree (excluding `.git`, `_build`, `deps`, `node_modules`,
   `.code_my_spec`, `test`, and any `.env*` files) to `/opt/metric_flow/{app,uat}/`
2. Run `docker compose ... up -d --build` to rebuild and restart
3. Run `/app/bin/migrate` inside the new container

The prod script uses `-f docker-compose.prod.yml`; UAT uses the default
`docker-compose.yml`. Both target `root@178.156.143.212`.

---

## 6. Database Management

The DB lives in the shared `infra-postgres-1` container. Full details in
`infra-stack.md`. Quick references:

```bash
# psql shell
ssh root@178.156.143.212 -t "docker exec -it infra-postgres-1 psql -U postgres metric_flow_prod"

# Run migrations
ssh root@178.156.143.212 "cd /opt/metric_flow/app && \
  docker compose -f docker-compose.prod.yml -p metric-flow-prod \
  --env-file /opt/metric_flow/.env.prod exec app /app/bin/migrate"

# Rollback
ssh root@178.156.143.212 "cd /opt/metric_flow/app && \
  docker compose -f docker-compose.prod.yml -p metric-flow-prod \
  --env-file /opt/metric_flow/.env.prod exec app /app/bin/metric_flow eval \
  'MetricFlow.Release.rollback(MetricFlow.Repo, 20260101000000)'"

# Remote IEx
ssh root@178.156.143.212 -t "cd /opt/metric_flow/app && \
  docker compose -f docker-compose.prod.yml -p metric-flow-prod \
  --env-file /opt/metric_flow/.env.prod exec app /app/bin/metric_flow remote"

# Backup
ssh root@178.156.143.212 "docker exec infra-postgres-1 pg_dump -U postgres metric_flow_prod" \
  | gzip > metric_flow_prod-$(date +%Y%m%d-%H%M%S).sql.gz
```

---

## 7. Build Notes

The cax11 has 4 GB RAM. Elixir compilation is memory-hungry. If Docker build OOMs:

1. Add temporary swap: `fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile`
2. Or build locally on ARM Mac and push to a registry

---

## 8. Operational Commands

```bash
# All containers
ssh root@178.156.143.212 "docker ps --format 'table {{.Names}}\t{{.Status}}'"

# Logs
ssh root@178.156.143.212 "docker logs metric-flow-prod-app-1 --tail 50 -f"

# Health
ssh root@178.156.143.212 "docker inspect metric-flow-prod-app-1 | jq '.[0].State.Health'"

# Restart without rebuild
ssh root@178.156.143.212 "cd /opt/metric_flow/app && \
  docker compose -f docker-compose.prod.yml -p metric-flow-prod \
  --env-file /opt/metric_flow/.env.prod restart app"

# Disk cleanup
ssh root@178.156.143.212 "docker system df && docker image prune -f && docker builder prune -f"
```

---

## 9. Outstanding Items

- [ ] Tighten `/opt/metric_flow/.env.{prod,uat}` to `chmod 600`
- [ ] Tighten `/opt/shared/.env` to `chmod 600`
- [ ] Replace shared `postgres` superuser with per-app users + scoped grants
      (see security note in `infra-stack.md`)
- [ ] Set up cron backup jobs for `infra-postgres-1` databases to `/opt/shared/backups/`
      (or to Tigris)
- [ ] Add `AWS_*`, `OAUTH_BASE_URL`, GitHub OAuth keys to `.env.prod` if those
      features are enabled
- [ ] Verify Resend sending domain and add DNS records to Cloudflare
