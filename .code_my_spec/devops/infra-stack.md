# Shared Infrastructure Stack (`/opt/shared/`)

The Hetzner server runs **one shared Caddy + one shared Postgres** that all
project apps (metric_flow, fuellytics, desert_first_cleaning) connect to. This
is its own Docker Compose stack, separate from any project's stack.

**Compose project name:** `infra`
**Location on server:** `/opt/shared/`

```
/opt/shared/
├── docker-compose.yml    # defines `postgres` and `caddy` services
├── Caddyfile             # routes for ALL apps on the box
└── .env                  # POSTGRES_PASSWORD (shared by every app)
```

---

## 1. Containers

| Container          | Image       | Purpose                                   |
|--------------------|-------------|-------------------------------------------|
| `infra-postgres-1` | postgres:17 | Shared DB for all apps (prod + UAT)       |
| `infra-caddy-1`    | caddy:2     | TLS termination + reverse proxy for all apps |

Both attach to two external Docker networks that every app stack joins:

| Network       | Used by              | Purpose                              |
|---------------|----------------------|--------------------------------------|
| `caddy_proxy` | All app containers   | Caddy -> app HTTP routing            |
| `db_net`      | All app containers   | App -> postgres connection            |

The networks are created once (manually) and referenced as `external: true` in
both the infra compose file and every app compose file.

---

## 2. Postgres

### Connection

All apps connect as the `postgres` **superuser** to host `infra-postgres-1` on
the `db_net` network:

```
DATABASE_URL=ecto://postgres:${POSTGRES_PASSWORD}@infra-postgres-1/<db_name>
```

### Databases

| Database           | Owned by app                        |
|--------------------|-------------------------------------|
| `metric_flow_prod` | metric-flow-prod-app-1              |
| `metric_flow_uat`  | metric-flow-uat-app-1               |
| `fuellytics_prod`  | fuellytics-prod-app-1               |
| `fuellytics_uat`   | fuellytics-uat-app-1                |

(Desert First currently has no DB in this instance — it may be using a different
backend or hasn't been provisioned yet.)

### Volume

Data lives in the Docker volume `infra_pgdata`. Backing up = `pg_dump` against
this single container, restoring = restore into the same volume.

```bash
# Backup all metric_flow DBs
ssh root@178.156.143.212 "docker exec infra-postgres-1 pg_dump -U postgres metric_flow_prod" \
  | gzip > metric_flow_prod-$(date +%Y%m%d).sql.gz

# psql shell
ssh root@178.156.143.212 -t "docker exec -it infra-postgres-1 psql -U postgres metric_flow_prod"
```

### Where the superuser password lives

The `postgres` superuser password is defined in **`/opt/shared/.env`**
(`POSTGRES_PASSWORD=...`). The infra container reads it on first boot to set
the `postgres` superuser password.

A local copy lives at **`~/Documents/github/devops/.env`** (chmod 600, outside
any repo) so you don't need SSH access to recover it. Save it to a password
manager too.

To rotate the superuser password:
1. `ALTER USER postgres WITH PASSWORD '...';` inside the running container
2. Update `/opt/shared/.env` on the server
3. Update `~/Documents/github/devops/.env` locally

Per-app DB users (see below) have their own passwords and are unaffected by
superuser rotation.

### Per-app DB users (preferred over the shared superuser)

Each app should have its own DB user with grants scoped to its own database.
This means a leak of one app's env file does not give attackers access to
other projects' data.

Pattern (run as the `postgres` superuser):

```sql
-- 1. Create the user
CREATE USER metric_flow_uat_app WITH PASSWORD '<strong-random>';

-- 2. Make it the owner of the database
ALTER DATABASE metric_flow_uat OWNER TO metric_flow_uat_app;

-- 3. Inside the database, reassign ownership of all existing objects.
--    REASSIGN OWNED only touches objects in the *current* database.
\c metric_flow_uat
REASSIGN OWNED BY postgres TO metric_flow_uat_app;
```

The app's env file then carries a fully-formed `DATABASE_URL` instead of
piecing together user/password/db separately:

```
DATABASE_URL=ecto://metric_flow_uat_app:<password>@infra-postgres-1/metric_flow_uat
```

And the compose file passes it through directly:

```yaml
environment:
  DATABASE_URL: ${DATABASE_URL}
```

Naming convention: `<project>_<env>_app` — separate users per env so a UAT
credential leak does not expose prod data.

Migration status:

| Database           | DB user             | Migrated from `postgres`? |
|--------------------|---------------------|----------------------------|
| `metric_flow_uat`  | `metric_flow_uat_app`   | yes                       |
| `metric_flow_prod` | `metric_flow_prod_app`  | yes                       |
| `fuellytics_uat`   | `postgres` (still)  | TODO (different project)   |
| `fuellytics_prod`  | `postgres` (still)  | TODO (different project)   |

> **Other security cleanups:** `/opt/shared/.env` and `/opt/metric_flow/.env.*`
> are currently `-rw-r--r--` (world-readable on the server). Tighten to
> `chmod 600`.

---

## 3. Caddy

### Caddyfile location

`/opt/shared/Caddyfile`. (The metric_flow `hetzner-deploy.md` previously claimed
this lived in `/opt/fuellytics/app/Caddyfile` — that's stale.)

### Current routes

```caddy
# Production
fuellytics.app                                       -> fuellytics-prod-app-1:4000
metric-flow.app                                      -> metric-flow-prod-app-1:4000
desertfirstcleaning.com, www.desertfirstcleaning.com -> desert-first-prod-app-1:4000

# UAT
uat.fuellytics.app                                   -> fuellytics-uat-app-1:4000
uat.metric-flow.app                                  -> metric-flow-uat-app-1:4000
```

No health checks are configured in the live Caddyfile (the metric_flow docs
showed `health_uri /health` in the snippet, but the live file is plain
`reverse_proxy` blocks). Apps still have container-level healthchecks in their
own compose files.

### Reload after editing

```bash
ssh root@178.156.143.212 "docker exec infra-caddy-1 caddy validate --config /etc/caddy/Caddyfile && \
  docker exec infra-caddy-1 caddy reload --config /etc/caddy/Caddyfile"
```

---

## 4. Bringing the infra stack up/down

```bash
# Start
ssh root@178.156.143.212 "cd /opt/shared && docker compose -p infra --env-file .env up -d"

# Restart just Caddy (rare — usually `caddy reload` is enough)
ssh root@178.156.143.212 "docker restart infra-caddy-1"

# Restart Postgres (will drop every app's DB connection — apps will reconnect)
ssh root@178.156.143.212 "docker restart infra-postgres-1"
```

The networks `caddy_proxy` and `db_net` must exist before this stack or any app
stack can come up. They were created once with:

```bash
docker network create caddy_proxy
docker network create db_net
```

---

## 5. Adding a new project

1. Create `/opt/<project>/` with `app/` (and optionally `uat/`) and `.env.<env>` files.
2. Set `POSTGRES_PASSWORD` in the project's env file to match `/opt/shared/.env`.
3. In the project's `docker-compose.yml`, point `DATABASE_URL` at
   `infra-postgres-1` and join networks `caddy_proxy` + `db_net` as `external`.
4. `CREATE DATABASE <project_env>;` inside `infra-postgres-1`.
5. Add a `reverse_proxy` block to `/opt/shared/Caddyfile` and reload Caddy.
6. Add the DNS A record in Cloudflare pointing at `178.156.143.212`.
