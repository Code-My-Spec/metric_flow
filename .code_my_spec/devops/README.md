# MetricFlow DevOps

Infrastructure, deployment, and environment management for MetricFlow.

## Quick Reference

| Task                                  | Read                          |
|---------------------------------------|-------------------------------|
| Deploy to UAT or prod                 | `hetzner-deploy.md`          |
| Shared Postgres + Caddy on the box    | `infra-stack.md`             |
| Server access, project layout         | `hetzner-deploy.md`          |
| DNS, Cloudflare Tunnel (dev)          | `cloudflare.md`              |
| Email delivery (Resend)               | `services.md`                |
| File storage (Tigris/S3)              | `services.md`                |
| Error tracking (Sentry)               | `services.md`                |
| Encryption keys (Cloak)               | `services.md`                |
| Secrets and env var management        | `hetzner-deploy.md`          |

## Infrastructure Overview

```
                    Cloudflare DNS
                   +---------------------------------------+
                   |  metric-flow.app        -> Hetzner IP |
                   |  uat.metric-flow.app    -> same        |
                   |  dev.metric-flow.app    -> CF Tunnel   |
                   +-------------------+-------------------+
                                       |
                                       v
                +----------------------------------------------+
                |  Hetzner cax11 (ARM64)  178.156.143.212      |
                |  hostname: fuellytics-prod                   |
                |                                              |
                |  /opt/shared/    -- infra stack              |
                |    +-- infra-caddy-1     :443  TLS + proxy   |
                |    +-- infra-postgres-1  :5432 shared DB     |
                |                                              |
                |  /opt/metric_flow/                           |
                |    +-- metric-flow-prod-app-1  :4000         |
                |    +-- metric-flow-uat-app-1   :4000         |
                |                                              |
                |  /opt/fuellytics/                            |
                |    +-- fuellytics-prod-app-1   :4000         |
                |    +-- fuellytics-uat-app-1    :4000         |
                |                                              |
                |  /opt/desert_first_cleaning/                 |
                |    +-- desert-first-prod-app-1 :4000         |
                +----------------------------------------------+
                                       |
                                Tigris S3 storage
                          fly.storage.tigris.dev
```

**IMPORTANT:** This server hosts three unrelated projects (`metric_flow`,
`fuellytics`, `desert_first_cleaning`). They share **one** Caddy and **one**
Postgres container, both managed by the `infra` compose stack at
`/opt/shared/`. See `infra-stack.md`.

## Environments

| Env    | Domain                   | Infra              | DB (in `infra-postgres-1`) |
|--------|--------------------------|--------------------|----------------------------|
| dev    | `dev.metric-flow.app`    | Local + CF Tunnel  | local postgres             |
| uat    | `uat.metric-flow.app`    | Hetzner (Docker)   | `metric_flow_uat`          |
| prod   | `metric-flow.app`        | Hetzner (Docker)   | `metric_flow_prod`         |

## Server Layout

```
/opt/
├── shared/                   # infra stack (Caddy + Postgres)
│   ├── docker-compose.yml
│   ├── Caddyfile             # routes for ALL apps on the box
│   └── .env                  # POSTGRES_PASSWORD (shared)
│
├── metric_flow/
│   ├── app/                  # prod stack (rsync target for `scripts/deploy`)
│   ├── uat/                  # uat stack (rsync target for `scripts/deploy-uat`)
│   ├── .env.prod
│   └── .env.uat
│
├── fuellytics/
│   ├── app/    uat/    .env.prod    .env.uat
│
└── desert_first_cleaning/
    ├── app/    .env
```

Each app's compose project name isolates its containers:
- `metric-flow-prod-app-1`, `metric-flow-uat-app-1`
- `fuellytics-prod-app-1`, `fuellytics-uat-app-1`
- `desert-first-prod-app-1`

There are **no per-app `db` containers** — every app connects to the shared
`infra-postgres-1` over the external `db_net` network. See `infra-stack.md`
for postgres details, password rotation, and the security caveats around the
shared `postgres` superuser.

## Key Conventions

- Server: `root@178.156.143.212` (the box hostname is `fuellytics-prod` for
  historical reasons; it now hosts multiple projects)
- Secrets live on the server at `/opt/metric_flow/.env.{prod,uat}` — never in the repo
- The shared Postgres password lives at `/opt/shared/.env` and is duplicated
  into every app's env file. Keep them in sync if you rotate it.
- Deploy via rsync + remote `docker compose` (no CI/CD pipeline yet)
- Dev port is `4070` (not 4000) — see `config/dev.exs`
- Cloudflare Tunnel GenServer auto-starts in dev for `dev.metric-flow.app`
- Email: Resend in prod (`runtime.exs`), Swoosh Local adapter in dev
- File storage: Tigris (S3-compatible) in prod, local in dev
- Encryption: Cloak AES-GCM for sensitive fields (OAuth tokens, etc.)
