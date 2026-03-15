# Hetzner + Docker Compose Deployment

Reference for provisioning Hetzner Cloud servers, running multi-environment Docker Compose stacks, and managing the full production lifecycle for a Phoenix/Elixir application.

**Stack:** Hetzner cax11 (ARM64, 4GB), Ubuntu 24.04, Docker Compose, Caddy 2, Postgres 17, Phoenix release.

Sources:
- [Hetzner hcloud CLI how-to](https://community.hetzner.com/tutorials/howto-hcloud-cli/)
- [hcloud CLI releases](https://github.com/hetznercloud/cli/releases)
- [Caddy reverse_proxy directive](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy)
- [Docker Compose production docs](https://docs.docker.com/compose/how-tos/production/)
- [docker-rollout](https://github.com/wowu/docker-rollout)
- [Docker Compose pre-defined env vars](https://docs.docker.com/compose/how-tos/environment-variables/envvars/)
- [Phoenix releases guide](https://hexdocs.pm/phoenix/releases.html)

---

## 1. Hetzner Cloud CLI (hcloud)

### Installation

```bash
# macOS
brew install hcloud

# Linux
curl -fsSL https://github.com/hetznercloud/cli/releases/latest/download/hcloud-linux-amd64.tar.gz | tar xz
sudo mv hcloud /usr/local/bin/

# Authenticate — paste API token from Hetzner console
hcloud context create myproject
```

### SSH Key Management

```bash
# Upload your local public key
hcloud ssh-key create --name my-key --public-key-from-file ~/.ssh/id_ed25519.pub

# List keys
hcloud ssh-key list

# Delete a key
hcloud ssh-key delete my-key
```

### Server Provisioning

The cax11 is an ARM64 (Ampere Altra) shared-vCPU plan: 2 vCPU, 4 GB RAM, 40 GB SSD, ~3.79 EUR/month. Available in EU regions only (fsn1, nbg1, hel1).

```bash
# List available server types and images
hcloud server-type list
hcloud image list --type system | grep ubuntu

# Create server with SSH key and firewall
hcloud server create \
  --name myproject-prod \
  --type cax11 \
  --image ubuntu-24.04 \
  --location fsn1 \
  --ssh-key my-key \
  --firewall myproject-fw

# Get server IP
hcloud server describe myproject-prod | grep "Public Net"

# SSH in
ssh root@<IP>
```

### Firewall Rules

```bash
hcloud firewall create --name myproject-fw

# Allow SSH from your IP only
hcloud firewall add-rule myproject-fw \
  --direction in --source-ips YOUR_IP/32 --protocol tcp --port 22

# Allow HTTP (Let's Encrypt ACME challenge)
hcloud firewall add-rule myproject-fw \
  --direction in --source-ips 0.0.0.0/0 --source-ips ::/0 --protocol tcp --port 80

# Allow HTTPS
hcloud firewall add-rule myproject-fw \
  --direction in --source-ips 0.0.0.0/0 --source-ips ::/0 --protocol tcp --port 443

# Allow HTTPS/UDP for HTTP/3 (QUIC)
hcloud firewall add-rule myproject-fw \
  --direction in --source-ips 0.0.0.0/0 --source-ips ::/0 --protocol udp --port 443
```

### Snapshots

Take a snapshot before risky operations (OS upgrades, major migrations). Cost ~0.01 EUR/GB/month.

```bash
# Create snapshot
hcloud server create-image myproject-prod \
  --type snapshot \
  --description "Before Postgres 17 upgrade $(date +%Y-%m-%d)"

# List snapshots
hcloud image list --type snapshot

# Restore: create server from snapshot
hcloud server create \
  --name myproject-restored \
  --type cax11 \
  --image <snapshot-id> \
  --ssh-key my-key
```

---

## 2. Server Bootstrap (one-time)

```bash
# Update system
apt-get update && apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh

# Verify Docker Compose plugin
docker compose version

# Create deploy user
useradd -m -s /bin/bash deploy
usermod -aG docker deploy

# Copy SSH key for deploy user
mkdir -p /home/deploy/.ssh
cp /root/.ssh/authorized_keys /home/deploy/.ssh/
chown -R deploy:deploy /home/deploy/.ssh
chmod 700 /home/deploy/.ssh
chmod 600 /home/deploy/.ssh/authorized_keys

# Create app directories
mkdir -p /opt/myproject/{app,uat}
chown -R deploy:deploy /opt/myproject
```

---

## 3. Multi-Environment Stack (prod + UAT on same host)

### The COMPOSE_PROJECT_NAME Approach

Docker Compose prefixes all resource names with the project name. Two separate project names give fully isolated environments sharing no volumes or networks.

```
prod project:  myproject-prod-app-1, myproject-prod-db-1, myproject-prod-pgdata
uat project:   myproject-uat-app-1,  myproject-uat-db-1,  myproject-uat-pgdata
```

Both stacks share one Caddy reverse proxy that routes by hostname.

### Directory Layout on Server

```
/opt/myproject/
├── app/                     # prod — rsync target
│   ├── docker-compose.yml
│   ├── Dockerfile
│   ├── Caddyfile            # shared (mounted by Caddy service)
│   └── ...
├── uat/                     # uat — rsync target
│   ├── docker-compose.yml
│   ├── Dockerfile
│   └── ...
├── prod.env                 # prod secrets — never in git
└── uat.env                  # uat secrets — never in git
```

### Shared External Network for Caddy

Caddy only lives in one Compose project (prod). Both app services must be on a shared network.

```bash
docker network create caddy_proxy
```

### docker-compose.yml (prod)

```yaml
# Run with: docker compose -p myproject-prod --env-file /opt/myproject/prod.env up -d

services:
  db:
    image: postgres:17
    restart: unless-stopped
    volumes:
      - pgdata:/var/lib/postgresql/data
    environment:
      POSTGRES_USER: myproject
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: myproject_prod
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U myproject"]
      interval: 5s
      timeout: 5s
      retries: 5
    networks:
      - internal

  app:
    build: .
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    expose:
      - "4000"
    environment:
      DATABASE_URL: ecto://myproject:${POSTGRES_PASSWORD}@db/myproject_prod
      SECRET_KEY_BASE: ${SECRET_KEY_BASE}
      PHX_HOST: ${PHX_HOST}
      PHX_SERVER: "true"
      # ... additional app-specific env vars
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:4000/health || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 30s
    networks:
      - internal
      - caddy_proxy

  caddy:
    image: caddy:2
    restart: unless-stopped
    depends_on:
      app:
        condition: service_healthy
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    networks:
      - caddy_proxy

volumes:
  pgdata:
  caddy_data:
  caddy_config:

networks:
  internal:
  caddy_proxy:
    external: true
```

### docker-compose.yml (uat)

Same structure, no Caddy service (prod Caddy routes to UAT too).

```yaml
# Run with: docker compose -p myproject-uat --env-file /opt/myproject/uat.env up -d

services:
  db:
    image: postgres:17
    restart: unless-stopped
    volumes:
      - pgdata:/var/lib/postgresql/data
    environment:
      POSTGRES_USER: myproject
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: myproject_uat
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U myproject"]
      interval: 5s
      timeout: 5s
      retries: 5
    networks:
      - internal

  app:
    build: .
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    expose:
      - "4000"
    environment:
      DATABASE_URL: ecto://myproject:${POSTGRES_PASSWORD}@db/myproject_uat
      SECRET_KEY_BASE: ${SECRET_KEY_BASE}
      PHX_HOST: ${PHX_HOST}
      PHX_SERVER: "true"
    networks:
      - internal
      - caddy_proxy

volumes:
  pgdata:

networks:
  internal:
  caddy_proxy:
    external: true
```

Key isolation facts:
- `-p myproject-prod` vs `-p myproject-uat` means all named volumes are separate.
- Each stack has its own `internal` network — the two databases cannot reach each other.
- Both `app` services join `caddy_proxy` so Caddy can reach them by Docker DNS names.

### How Docker DNS Works Across Projects

Within `caddy_proxy`, Docker resolves container names as `<project>-<service>-<replica>`:

```
myproject-prod-app-1   # prod app container
myproject-uat-app-1    # uat app container
```

---

## 4. Caddy Configuration

### Caddyfile — Multi-Domain Routing

```caddy
myapp.com {
    reverse_proxy myproject-prod-app-1:4000 {
        health_uri /health
        health_interval 10s
        health_timeout 5s
        health_status 2xx
    }
}

uat.myapp.com {
    reverse_proxy myproject-uat-app-1:4000 {
        health_uri /health
        health_interval 10s
        health_timeout 5s
        health_status 2xx
    }
}
```

Auto-TLS notes:
- Caddy obtains Let's Encrypt certificates automatically for every named site block.
- DNS must point to the server's public IP before first deployment.
- Caddy stores certificates in the `caddy_data` volume — must persist across redeploys.
- Port 80 must be reachable (ACME HTTP-01 challenge).

### Reloading Caddy Config

```bash
docker exec myproject-prod-caddy-1 caddy validate --config /etc/caddy/Caddyfile
docker exec myproject-prod-caddy-1 caddy reload --config /etc/caddy/Caddyfile
```

---

## 5. Deployment Workflow

### Deploy Script Pattern

```bash
#!/usr/bin/env bash
# scripts/deploy — deploy prod
set -euo pipefail

SERVER="deploy@<SERVER_IP>"
APP_DIR="/opt/myproject/app"
ENV_FILE="/opt/myproject/prod.env"
PROJECT="myproject-prod"

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

echo "==> Done: https://myapp.com"
```

### Build Performance Notes

cax11 has 4 GB RAM. Elixir builds are memory-intensive. If Docker build OOMs:
- Add swap: `fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile`
- Or build locally and push to a registry (GHCR, Docker Hub).

### Zero-Downtime Deployments with docker-rollout

[docker-rollout](https://github.com/wowu/docker-rollout) scales app to 2 replicas, waits for health, removes old one.

Requirements:
- No `container_name` set on the service
- No `ports` mapped (use `expose` — Caddy proxies internally)
- A `healthcheck` must be defined

```bash
# Install on server (one-time)
mkdir -p /home/deploy/.docker/cli-plugins
curl -fsSL https://raw.githubusercontent.com/wowu/docker-rollout/main/docker-rollout \
  -o /home/deploy/.docker/cli-plugins/docker-rollout
chmod +x /home/deploy/.docker/cli-plugins/docker-rollout

# In deploy script, replace `up -d --build` with:
docker compose -p $PROJECT --env-file $ENV_FILE build
docker compose -p $PROJECT --env-file $ENV_FILE up -d db
docker -p $PROJECT rollout app
```

---

## 6. Phoenix Migrations in Docker

Phoenix releases include a `bin/migrate` script that runs `MyApp.Release.migrate()`.

```elixir
defmodule MyApp.Release do
  @app :myapp

  def migrate do
    load_app()
    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos, do: Application.fetch_env!(@app, :ecto_repos)
  defp load_app, do: Application.load(@app)
end
```

Commands:

```bash
# Run all pending migrations
docker compose -p myproject-prod --env-file /opt/myproject/prod.env \
  exec app /app/bin/migrate

# Rollback one version
docker compose -p myproject-prod --env-file /opt/myproject/prod.env \
  exec app /app/bin/myapp eval \
  'MyApp.Release.rollback(MyApp.Repo, 20260101000000)'

# Interactive shell
docker compose -p myproject-prod --env-file /opt/myproject/prod.env \
  exec app /app/bin/myapp remote
```

---

## 7. Database Management

### Backup

```bash
# Manual dump
docker exec myproject-prod-db-1 \
  pg_dump -U myproject myproject_prod \
  | gzip > /opt/myproject/backups/prod-$(date +%Y%m%d-%H%M%S).sql.gz
```

### Automated Backups via Cron

```
# Prod backup at 3:00 AM daily
0 3 * * * docker exec myproject-prod-db-1 pg_dump -U myproject myproject_prod | gzip > /opt/myproject/backups/prod-$(date +\%Y\%m\%d-\%H\%M\%S).sql.gz

# Purge backups older than 14 days
0 4 * * * find /opt/myproject/backups -name "*.sql.gz" -mtime +14 -delete
```

### Restore

```bash
docker compose -p myproject-prod --env-file /opt/myproject/prod.env stop app
docker exec myproject-prod-db-1 psql -U myproject -c "DROP DATABASE myproject_prod;"
docker exec myproject-prod-db-1 psql -U myproject -c "CREATE DATABASE myproject_prod;"
gunzip -c /opt/myproject/backups/prod-YYYYMMDD.sql.gz \
  | docker exec -i myproject-prod-db-1 psql -U myproject myproject_prod
docker compose -p myproject-prod --env-file /opt/myproject/prod.env start app
```

---

## 8. Secrets Management

### Env Files on Server

Secrets live at `/opt/myproject/{prod,uat}.env`. These files are:
- Never committed to the repo
- Owned by `deploy` user with mode `600`
- Passed via `--env-file`

### Env File Format

```bash
# /opt/myproject/prod.env
POSTGRES_PASSWORD=<openssl-rand-hex-16>
SECRET_KEY_BASE=<mix-phx-gen-secret>
PHX_HOST=myapp.com
# ... service-specific keys
```

### Runtime Config and Dotenvy

Phoenix apps using Dotenvy in `config/runtime.exs` load env files from `$RELEASE_ROOT/envs/`. In Docker, all secrets come as container env vars (via `--env-file`). The `envs/` dir in the Docker image is intentionally empty:

```dockerfile
# Prevents Dotenvy crash on missing file
RUN mkdir -p envs && touch envs/.env envs/prod.env
```

---

## 9. Server Hardening

### SSH: Key-Only Auth

```bash
# /etc/ssh/sshd_config
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AllowUsers deploy
```

Test with `sshd -t` before restarting. Keep current session open while testing in a second terminal.

### Firewall Notes

Docker bypasses UFW by writing its own iptables rules. The Hetzner cloud firewall (network edge) is more reliable for controlling inbound access to Docker-published ports.

### fail2ban

```bash
apt-get install -y fail2ban
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5

[sshd]
enabled  = true
EOF

systemctl enable fail2ban && systemctl start fail2ban
```

### Unattended Upgrades

```bash
apt-get install -y unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades
```

---

## 10. Operational Runbook

### Check Status

```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
docker logs myproject-prod-app-1 --tail 50 -f
docker inspect myproject-prod-app-1 | jq '.[0].State.Health'
```

### Restart

```bash
# Without rebuild
docker compose -p myproject-prod --env-file /opt/myproject/prod.env restart app

# With rebuild
docker compose -p myproject-prod --env-file /opt/myproject/prod.env up -d --build app
```

### Disk Usage

```bash
docker system df
docker image prune -f
docker builder prune -f
```

### Common Issues

**Build OOMs on cax11:** Add swap or build locally and push image to registry.

**Container exits immediately:** Run interactively to see the error:
```bash
docker compose -p myproject-prod --env-file /opt/myproject/prod.env \
  run --rm app /app/bin/myapp eval ":ok"
```

**Caddy not routing to UAT:** Ensure UAT app is on the `caddy_proxy` network:
```bash
docker network inspect caddy_proxy | jq '.[0].Containers | keys'
```

**POSTGRES_PASSWORD changed but DB rejects it:** The password env var only takes effect on first volume creation. Either `ALTER USER` in psql or nuke the volume and re-migrate.

**Containers created with wrong names:** You forgot `-p myproject-prod`. Docker compose used the directory name as the project, creating duplicate containers. Stop the bad ones with `docker compose -p <wrong-name> down`.
