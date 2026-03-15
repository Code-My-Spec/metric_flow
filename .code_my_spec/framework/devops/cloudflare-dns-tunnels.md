# Cloudflare DNS and Tunnel Setup for Web App Deployment

Reference for deploying web apps with Cloudflare DNS, Cloudflare Tunnels, and Caddy as the origin reverse proxy. Covers multi-environment DNS routing, tunnel-based dev access, SSL/TLS configuration, and the Cloudflare API.

---

## 1. DNS Management

### Record Types

**A record** — Maps hostname to IPv4. Use for apex (`@`) and subdomains pointing to your server.

**AAAA record** — Same but for IPv6.

**CNAME record** — Maps hostname to another hostname. Cannot be used at zone apex in standard DNS, but Cloudflare supports it via CNAME flattening.

### Proxied vs DNS-Only

| Mode | Effect |
|------|--------|
| Proxied (orange cloud) | Traffic through Cloudflare edge. Origin IP hidden. DDoS protection, WAF, caching. |
| DNS-only (gray cloud) | Raw IP in DNS. No Cloudflare features. Origin IP exposed. |

For Tunnel CNAMEs, the record **must be proxied**.

### CNAME Flattening

Cloudflare resolves apex CNAME chains and returns the final A record IP. Automatic for `@` records on all plans.

### Multi-Environment DNS Pattern

```
# Production — apex A record
Type: A,  Name: @,   Content: <SERVER_IP>, Proxied: true

# UAT — subdomain A record (same server)
Type: A,  Name: uat, Content: <SERVER_IP>, Proxied: true

# Dev — CNAME to Cloudflare Tunnel
Type: CNAME, Name: dev, Content: <tunnel-uuid>.cfargotunnel.com, Proxied: true
```

Caddy routes by `Host` header. Dev traffic goes through the tunnel to the developer's machine, never reaching the server.

---

## 2. Cloudflare Tunnels

### What They Are

Cloudflare Tunnels expose a local service without opening inbound ports. Your machine connects *out* to Cloudflare's edge, and Cloudflare routes matching traffic back.

- Outbound-only QUIC/HTTP2 connections
- No public IP exposure for tunnel-routed hostnames
- mTLS between cloudflared and Cloudflare edge

### Installing cloudflared

```bash
# macOS
brew install cloudflared

# Linux (Debian/Ubuntu)
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb
```

### Creating a Named Tunnel (One-Time)

```bash
# Authenticate (opens browser, downloads cert.pem)
cloudflared tunnel login

# Create tunnel (generates ~/.cloudflared/<UUID>.json credentials)
cloudflared tunnel create dev-myproject

# Create DNS CNAME pointing to the tunnel
cloudflared tunnel route dns dev-myproject dev.myapp.com

# Verify
cloudflared tunnel list
```

### Credentials File

`~/.cloudflared/<UUID>.json`:
```json
{
  "AccountTag": "<account-id>",
  "TunnelSecret": "<base64-secret>",
  "TunnelID": "<uuid>",
  "Endpoint": ""
}
```

Treat as a secret. Store `TunnelSecret` in env vars if managing programmatically.

### config.yml

```yaml
tunnel: <uuid>
credentials-file: /path/to/credentials.json

ingress:
  - hostname: dev.myapp.com
    service: http://127.0.0.1:4000
  - service: http_status:404    # catch-all, required
```

### Running

```bash
cloudflared tunnel --no-autoupdate run
cloudflared tunnel --config /path/to/config.yml --no-autoupdate run
```

### Useful Commands

```bash
cloudflared tunnel list
cloudflared tunnel info <name-or-uuid>
cloudflared tunnel delete <name-or-uuid>
cloudflared tunnel rotate-secret <name-or-uuid>
```

### Elixir GenServer Pattern

Manage `cloudflared` as an Erlang port process:

1. Read config from `Application.get_env/3`
2. Write config.yml and credentials.json from env vars
3. Open port with `Port.open({:spawn_executable, path}, [:binary, :exit_status, ...])`
4. Log stdout/stderr, stop on unexpected exit

```elixir
# Config shape (dev.exs)
config :myapp, :cloudflare_tunnel,
  enabled: true,
  hostname: "dev.myapp.com",
  tunnel_id: "<uuid>",
  account_tag: "<account-id>",
  tunnel_secret: "",   # from env var in runtime.exs
  origin_url: "http://127.0.0.1:4000"
```

Return `:ignore` from `init/1` if cloudflared not in PATH or secret is empty.

---

## 3. SSL/TLS Configuration

### Cloudflare Encryption Modes

| Mode | Edge-to-Origin | Certificate Validation |
|------|---------------|----------------------|
| Off | None | — |
| Flexible | None | — |
| Full | HTTPS | Not validated (self-signed OK) |
| Full (strict) | HTTPS | Validated (CA-signed or CF Origin CA) |

**Use Full (strict)** with Caddy (Caddy gets its own Let's Encrypt cert).

### Caddy TLS Options

**Option A: Let's Encrypt (simplest)** — Caddy requests/renews certs automatically. Works with Full (strict).

**Option B: Cloudflare Origin CA (15-year)** — For servers accepting only Cloudflare traffic:
```
myapp.com {
    tls /etc/ssl/cloudflare/origin-cert.pem /etc/ssl/cloudflare/origin-key.pem
    reverse_proxy app:4000
}
```

**Option C: `tls internal`** — For dev behind tunnel only.

### Caddy trusted_proxies for Cloudflare

All incoming connections appear from Cloudflare IPs. Add trusted_proxies in Caddyfile global block:

```
{
    servers {
        trusted_proxies static 103.21.244.0/22 103.22.200.0/22 103.31.4.0/22 \
            104.16.0.0/13 104.24.0.0/14 108.162.192.0/18 131.0.72.0/22 \
            141.101.64.0/18 162.158.0.0/15 172.64.0.0/13 173.245.48.0/20 \
            188.114.96.0/20 190.93.240.0/20 197.234.240.0/22 198.41.128.0/17 \
            2400:cb00::/32 2606:4700::/32 2803:f800::/32 2405:b500::/32 \
            2405:8100::/32 2a06:98c0::/29 2c0f:f248::/32
        client_ip_headers CF-Connecting-IP X-Forwarded-For
        trusted_proxies_strict
    }
}
```

IP ranges: https://www.cloudflare.com/ips-v4 / https://www.cloudflare.com/ips-v6

Alternative: [caddy-cloudflare-ip](https://github.com/WeidiDeng/caddy-cloudflare-ip) module auto-refreshes ranges.

---

## 4. Phoenix Endpoint Config for Dev Tunnel

```elixir
# dev.exs
config :myapp, MyAppWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4090],
  url: [host: "dev.myapp.com", scheme: "https", port: 443],
  check_origin: false   # requests arrive from Cloudflare edge
```

---

## 5. Cache Rules via API

### Bypass Cache for Dev Environments

Dev tunnels should bypass Cloudflare cache to avoid stale CSS/JS during development. Use the Cache Rules (rulesets) API.

**Required token permission:** Zone > Cache Rules > Edit

```bash
# Create/replace cache rules for the zone (PUT replaces all rules in this phase)
curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/rulesets/phases/http_request_cache_settings/entrypoint" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "rules": [
      {
        "expression": "(http.host eq \"dev.myapp.com\")",
        "description": "Bypass cache for dev environment",
        "action": "set_cache_settings",
        "action_parameters": {
          "cache": false
        }
      }
    ]
  }'
```

**Important:** PUT replaces the entire ruleset. To add a rule without removing existing ones, GET the current ruleset first, append your rule, then PUT the full list back.

```bash
# Read existing cache rules
curl -s "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/rulesets/phases/http_request_cache_settings/entrypoint" \
  -H "Authorization: Bearer $CF_API_TOKEN"
```

### Development Mode (Temporary)

Disables all caching zone-wide for 3 hours. Useful for one-off debugging but not a permanent solution.

```bash
# Enable
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/settings/development_mode" \
  -H "Authorization: Bearer $CF_API_TOKEN" -H "Content-Type: application/json" \
  -d '{"value":"on"}'

# Disable
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/settings/development_mode" \
  -H "Authorization: Bearer $CF_API_TOKEN" -H "Content-Type: application/json" \
  -d '{"value":"off"}'
```

**Required token permission:** Zone > Zone Settings > Edit

---

## 6. Cloudflare API

### Authentication

Create API token at: Dashboard > My Profile > API Tokens. Use "Edit zone DNS" template.

```bash
curl -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer $CF_API_TOKEN"
```

### Get Zone ID

```bash
curl -s "https://api.cloudflare.com/client/v4/zones?name=myapp.com" \
  -H "Authorization: Bearer $CF_API_TOKEN" | jq -r '.result[0].id'
```

### CRUD DNS Records

```bash
# List
curl -s "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CF_API_TOKEN" | jq '.result[] | {name, type, content, proxied}'

# Create A record
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CF_API_TOKEN" -H "Content-Type: application/json" \
  -d '{"type":"A","name":"uat","content":"<IP>","ttl":1,"proxied":true}'

# Update (PATCH for partial, PUT for full replace)
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$RECORD_ID" \
  -H "Authorization: Bearer $CF_API_TOKEN" -H "Content-Type: application/json" \
  -d '{"content":"<NEW_IP>"}'

# Delete
curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$RECORD_ID" \
  -H "Authorization: Bearer $CF_API_TOKEN"
```

Response envelope: `{"success": true, "errors": [], "messages": [], "result": {...}}`

---

### API Token Permissions Reference

| Permission | Covers |
|-----------|--------|
| Zone > DNS > Edit | DNS record CRUD |
| Zone > Zone Settings > Edit | Development mode, SSL mode, etc. |
| Zone > Cache Purge > Purge | Purge cache by URL or everything |
| Zone > Cache Rules > Edit | Cache rulesets (bypass, TTL overrides) |
| Zone > Zone > Edit | Broad zone-level rulesets (WAF, redirects, etc.) |

---

## Reference Links

- [Cloudflare Tunnel overview](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/)
- [Create locally-managed tunnel](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/local-management/create-local-tunnel/)
- [cloudflared config reference](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/local-management/configuration-file/)
- [Cloudflare proxy status](https://developers.cloudflare.com/dns/proxy-status/)
- [SSL/TLS modes](https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/)
- [Origin CA certificates](https://developers.cloudflare.com/ssl/origin-configuration/origin-ca/)
- [CNAME flattening](https://developers.cloudflare.com/dns/cname-flattening/)
- [DNS API](https://developers.cloudflare.com/api/resources/dns/subresources/records/methods/create/)
- [Rulesets API (Cache Rules)](https://developers.cloudflare.com/ruleset-engine/rulesets-api/)
- [Cloudflare IP ranges](https://www.cloudflare.com/ips/)
- [Caddy reverse_proxy](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy)
- [cloudflared releases](https://github.com/cloudflare/cloudflared/releases)
