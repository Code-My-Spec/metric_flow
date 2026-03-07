# MetricFlow: Cloudflare DNS and Tunnels

## Domain

The MetricFlow domain is `metric-flow.app`. DNS is managed in Cloudflare.

## DNS Records

| Hostname               | Type  | Content                                          | Proxied | Target                          |
|------------------------|-------|--------------------------------------------------|---------|----------------------------------|
| `metric-flow.app`      | A     | `46.225.105.88`                                  | Yes     | Caddy -> prod app container      |
| `uat.metric-flow.app`  | A     | `46.225.105.88`                                  | Yes     | Caddy -> UAT app container       |
| `dev.metric-flow.app`  | CNAME | `087e2228-74d8-437d-bc92-b41c9fc9f253.cfargotunnel.com` | Yes     | CF Tunnel -> localhost:4070      |

## Cloudflare Account

- **Account tag:** `6477547f586ec90db2c2a0081dcd98bd`
- **SSL/TLS mode:** Full (strict)
- Same Cloudflare account as fuellytics

---

## Cloudflare Tunnel (Dev Environment)

The dev environment uses a named Cloudflare Tunnel managed by an Elixir GenServer
that auto-starts in dev mode.

### Tunnel Details

| Property        | Value                                          |
|-----------------|------------------------------------------------|
| Tunnel name     | (check with `cloudflared tunnel list`)         |
| Tunnel ID       | `087e2228-74d8-437d-bc92-b41c9fc9f253`        |
| Hostname        | `dev.metric-flow.app`                          |
| Origin          | `http://127.0.0.1:4070`                        |
| Account tag     | `6477547f586ec90db2c2a0081dcd98bd`             |

### Configuration

The tunnel is configured in `config/dev.exs`:

```elixir
config :metric_flow, :cloudflare_tunnel,
  mode: :named,
  hostname: "dev.metric-flow.app",
  tunnel_id: "087e2228-74d8-437d-bc92-b41c9fc9f253",
  account_tag: "6477547f586ec90db2c2a0081dcd98bd",
  origin_url: "http://127.0.0.1:4070"
```

The tunnel secret is loaded from `CLOUDFLARE_TUNNEL_SECRET` env var in `config/runtime.exs`.
Set this in your local `.env` file:

```bash
# .env (gitignored)
CLOUDFLARE_TUNNEL_SECRET=<base64-secret-from-credentials-json>
```

### How It Works

1. On `mix phx.server`, the GenServer starts and writes `config.yml` + `credentials.json` to a temp dir
2. It spawns `cloudflared` as an Erlang port process
3. Cloudflare routes `dev.metric-flow.app` through the tunnel to `localhost:4070`
4. The tunnel stops when you stop the dev server

### Prerequisites

- `cloudflared` must be installed: `brew install cloudflared`
- `CLOUDFLARE_TUNNEL_SECRET` must be set in `.env`
- If the secret is empty or cloudflared isn't in PATH, the GenServer returns `:ignore` (no crash)

### Useful Commands

```bash
# List all tunnels
cloudflared tunnel list

# Check tunnel status
cloudflared tunnel info 087e2228-74d8-437d-bc92-b41c9fc9f253

# If you need to recreate the tunnel
cloudflared tunnel login
cloudflared tunnel create metric-flow-dev
cloudflared tunnel route dns metric-flow-dev dev.metric-flow.app
```

---

## Cloudflare API

Same API token as fuellytics (Edit zone DNS permission). See the framework docs at
`.code_my_spec/framework/devops/cloudflare-dns-tunnels.md` for full API reference.

```bash
# Quick: list DNS records for metric-flow.app zone
CF_ZONE_ID=$(curl -s "https://api.cloudflare.com/client/v4/zones?name=metric-flow.app" \
  -H "Authorization: Bearer $CF_API_TOKEN" | jq -r '.result[0].id')

curl -s "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  | jq '.result[] | {name, type, content, proxied}'
```
