# DevOps Knowledge

Reference docs for infrastructure, deployment, and environment management.

## When to read what

| Task | Read |
|------|------|
| Create S3 buckets or IAM users | `aws-s3-iam.md` |
| Configure ExAws credentials | `aws-s3-iam.md` |
| Add/change DNS records | `cloudflare-dns-tunnels.md` |
| Set up dev tunnel (cloudflared) | `cloudflare-dns-tunnels.md` |
| SSL/TLS with Caddy + Cloudflare | `cloudflare-dns-tunnels.md` |
| Provision a Hetzner server | `hetzner-docker-deploy.md` |
| Deploy with Docker Compose | `hetzner-docker-deploy.md` |
| Run prod + UAT on same host | `hetzner-docker-deploy.md` |
| Back up or restore Postgres | `hetzner-docker-deploy.md` |
| Manage secrets on server | `hetzner-docker-deploy.md` |

## Typical infrastructure layout

```
                    Cloudflare DNS
                   ┌──────────────────────────────┐
                   │  myapp.com → Server IP        │
                   │  uat.myapp.com → same         │
                   │  dev.myapp.com → Tunnel       │
                   └──────────┬───────────────────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
         myapp.com      uat.myapp.com    dev.myapp.com
              │               │               │
              ▼               ▼               ▼
         ┌─────────────────────────┐    Developer laptop
         │  Hetzner cax11 (ARM)    │    (cloudflared tunnel)
         │                         │
         │  Caddy :443 ──┬── prod app :4000 ── prod db
         │               └── uat app  :4001 ── uat db
         └─────────────────────────┘
                              │
                        AWS S3 buckets
                   ┌──────────┴──────────┐
                   │ myproject-uploads    │  (prod)
                   │ myproject-uploads-uat│  (uat)
                   └─────────────────────┘
```

## Key conventions

- Secrets live on the server at `/opt/myproject/{prod,uat}.env` — never in the repo
- Deploy scripts live in project repo (e.g., `scripts/deploy` or `.code_my_spec/devops/deploy`)
- Cloudflare Tunnel GenServer lives in `client_utils` (shared lib) — not per-project
- ExAws uses the standard credential chain: env vars → `~/.aws/credentials` → IAM role
- Project-specific infra details (IPs, domains, bucket names) go in `.code_my_spec/devops/`
