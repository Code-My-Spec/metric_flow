# MetricFlow DevOps

Infrastructure, deployment, and environment management for MetricFlow.

## Quick Reference

| Task                                  | Read                          |
|---------------------------------------|-------------------------------|
| Deploy to UAT or prod                 | `hetzner-deploy.md`          |
| Server setup, Docker, Caddy           | `hetzner-deploy.md`          |
| DNS, Cloudflare Tunnel (dev)          | `cloudflare.md`              |
| Email delivery (Resend)               | `services.md`                |
| File storage (Tigris/S3)             | `services.md`                |
| Error tracking (Sentry)              | `services.md`                |
| Encryption keys (Cloak)              | `services.md`                |
| Secrets and env var management        | `hetzner-deploy.md`          |

## Infrastructure Overview

```
                    Cloudflare DNS
                   +-------------------------------+
                   |  metric-flow.app -> Hetzner IP |
                   |  uat.metric-flow.app -> same   |
                   |  dev.metric-flow.app -> Tunnel |
                   +---------------+---------------+
                                   |
               +-------------------+-------------------+
               |                   |                   |
          metric-flow.app   uat.metric-flow.app   dev.metric-flow.app
               |                   |                   |
               v                   v                   v
          +----------------------------+         Developer laptop
          |  Hetzner cax11 (ARM64)     |         (cloudflared tunnel)
          |  46.225.105.88             |
          |                            |
          |  Caddy :443 --+-- prod app :4000 -- prod db
          |               +-- uat app  :4000 -- uat db
          +----------------------------+
                                   |
                          Tigris S3 storage
                   +-----------+-----------+
                   | fly.storage.tigris.dev |
                   +-----------------------+
```

**IMPORTANT:** This server is shared with the fuellytics project. Both projects run
separate Docker Compose stacks on the same Hetzner cax11 at `46.225.105.88`.

## Environments

| Env    | Domain                   | Infra              | DB                   |
|--------|--------------------------|--------------------|----------------------|
| dev    | `dev.metric-flow.app`    | Local + CF Tunnel  | local postgres       |
| uat    | `uat.metric-flow.app`    | Hetzner (Docker)   | `metric_flow_uat`    |
| prod   | `metric-flow.app`        | Hetzner (Docker)   | `metric_flow_prod`   |

## Shared Server Layout

The Hetzner server at `46.225.105.88` hosts multiple projects:

```
/opt/
├── fuellytics/              # Fuellytics project
│   ├── app/                 # fuellytics prod stack
│   ├── uat/                 # fuellytics UAT stack
│   ├── prod.env
│   └── uat.env
│
├── metric_flow/             # MetricFlow project
│   ├── app/                 # metric_flow prod stack (TODO: set up)
│   ├── uat/                 # metric_flow UAT stack
│   ├── prod.env             # (TODO: create)
│   └── uat.env
│
└── backups/                 # shared backup directory
```

Each project uses `COMPOSE_PROJECT_NAME` to isolate Docker resources:
- `fuellytics-prod-*`, `fuellytics-uat-*`
- `metric-flow-prod-*`, `metric-flow-uat-*`

They share one `caddy_proxy` Docker network so a single Caddy instance routes all traffic.

## Key Conventions

- Secrets live on the server at `/opt/metric_flow/{prod,uat}.env` -- never in the repo
- Deploy via rsync + remote docker compose (no CI/CD pipeline yet)
- Dev port is `4070` (not 4000) -- see `config/dev.exs`
- Cloudflare Tunnel GenServer auto-starts in dev for `dev.metric-flow.app`
- Email: Resend in prod (runtime.exs), Swoosh Local adapter in dev
- File storage: Tigris (S3-compatible) in prod, local in dev
- Encryption: Cloak AES-GCM for sensitive fields (OAuth tokens etc.)
