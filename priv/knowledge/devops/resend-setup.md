# Resend Email Setup Guide

Resend is MetricFlow's transactional email provider. This guide covers account setup,
domain verification, API key management, DNS configuration in Cloudflare, and
integration with the Phoenix app via Swoosh.

---

## 1. Account and Current State

- **Dashboard:** https://resend.com/overview
- **Sending domain:** `metric-flow.app` (verified, sending enabled)
- **Region:** us-east-1
- **Domain ID:** `c97951b6-570f-4726-a780-cb338f59b1c9`

### API Keys

| Name       | ID                                     | Purpose                    |
|------------|----------------------------------------|----------------------------|
| devops     | `e6c57f6b-06a6-4b3e-9fb0-2a73722b7131`| Dev/deployment operations  |
| Onboarding | `f58cc70f-87e5-49fc-99f3-0bd046918dbf`| Initial setup key          |

API keys start with `re_`. The full key is only shown once at creation -- store it
immediately in your `.env` or server env file.

### Plan Limits

| Plan   | Price     | Emails/month | Emails/day | Domains | Dedicated IP  |
|--------|-----------|-------------|------------|---------|---------------|
| Free   | $0        | 3,000       | 100        | 1       | No            |
| Pro    | $20/month | 50,000      | --         | 10      | No            |
| Scale  | $90/month | 100,000     | --         | 10      | $30/mo add-on |

---

## 2. Domain Setup

### Adding a New Domain (CLI)

```bash
# Add a domain
curl -s -X POST https://api.resend.com/domains \
  -H "Authorization: Bearer $RESEND_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name": "metric-flow.app", "region": "us-east-1"}' | python3 -m json.tool
```

The response includes the domain ID and the DNS records you need to add.

### Checking Domain Status

```bash
# List all domains
curl -s https://api.resend.com/domains \
  -H "Authorization: Bearer $RESEND_API_KEY" | python3 -m json.tool

# Get specific domain details (includes DNS records and verification status)
curl -s https://api.resend.com/domains/c97951b6-570f-4726-a780-cb338f59b1c9 \
  -H "Authorization: Bearer $RESEND_API_KEY" | python3 -m json.tool

# Trigger re-verification
curl -s -X POST https://api.resend.com/domains/c97951b6-570f-4726-a780-cb338f59b1c9/verify \
  -H "Authorization: Bearer $RESEND_API_KEY" | python3 -m json.tool
```

### Deleting a Domain

```bash
curl -s -X DELETE https://api.resend.com/domains/<domain-id> \
  -H "Authorization: Bearer $RESEND_API_KEY"
```

---

## 3. DNS Records (Cloudflare)

Three DNS records are required for domain verification. These are already configured
for `metric-flow.app`:

### DKIM (TXT record)

```
Type:    TXT
Name:    resend._domainkey
Content: p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDKvCwH/ET3zjQY5QwaR7uZv9/bW2CVuf8HBxWSnI4Z0ScpX7igqvUDnbxBQCqWhz2pXnrmhPijGjmfueYrSgT6oJcNvJWuHzrMO8rZLZIktPpisjKWeO2Rsk43bbGdKAFW/EfMLz3XL0HrHhzirsMROCl5lCgcaKAZOHvzL8ixgwIDAQAB
TTL:     Auto
Proxied: No (DNS only -- gray cloud)
```

### SPF (MX record)

```
Type:     MX
Name:     send
Content:  feedback-smtp.us-east-1.amazonses.com
Priority: 10
TTL:      Auto
```

### SPF (TXT record)

```
Type:    TXT
Name:    send
Content: v=spf1 include:amazonses.com ~all
TTL:     Auto
```

### Adding Records via Cloudflare API

If you prefer the CLI over the Cloudflare dashboard:

```bash
# Get zone ID for metric-flow.app
CF_ZONE_ID=$(curl -s "https://api.cloudflare.com/client/v4/zones?name=metric-flow.app" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | python3 -c "import sys,json; print(json.load(sys.stdin)['result'][0]['id'])")

# DKIM TXT record
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "TXT",
    "name": "resend._domainkey",
    "content": "p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDKvCwH/ET3zjQY5QwaR7uZv9/bW2CVuf8HBxWSnI4Z0ScpX7igqvUDnbxBQCqWhz2pXnrmhPijGjmfueYrSgT6oJcNvJWuHzrMO8rZLZIktPpisjKWeO2Rsk43bbGdKAFW/EfMLz3XL0HrHhzirsMROCl5lCgcaKAZOHvzL8ixgwIDAQAB",
    "ttl": 1,
    "proxied": false,
    "comment": "Resend DKIM verification"
  }'

# SPF MX record
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "MX",
    "name": "send",
    "content": "feedback-smtp.us-east-1.amazonses.com",
    "priority": 10,
    "ttl": 1,
    "comment": "Resend SPF (MX)"
  }'

# SPF TXT record
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "TXT",
    "name": "send",
    "content": "v=spf1 include:amazonses.com ~all",
    "ttl": 1,
    "proxied": false,
    "comment": "Resend SPF (TXT)"
  }'
```

### Verifying DNS Propagation

```bash
# Check DKIM
dig TXT resend._domainkey.metric-flow.app +short

# Check SPF MX
dig MX send.metric-flow.app +short

# Check SPF TXT
dig TXT send.metric-flow.app +short
```

---

## 4. API Key Management

### Create a New API Key

```bash
# Full access key
curl -s -X POST https://api.resend.com/api-keys \
  -H "Authorization: Bearer $RESEND_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name": "production"}' | python3 -m json.tool

# Domain-scoped key (can only send from specified domain)
curl -s -X POST https://api.resend.com/api-keys \
  -H "Authorization: Bearer $RESEND_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "metric-flow-prod",
    "permission": "sending_access",
    "domain_id": "c97951b6-570f-4726-a780-cb338f59b1c9"
  }' | python3 -m json.tool
```

The response includes the full API key (`re_xxx`). **This is shown only once** --
copy it immediately.

### List API Keys

```bash
curl -s https://api.resend.com/api-keys \
  -H "Authorization: Bearer $RESEND_API_KEY" | python3 -m json.tool
```

### Delete an API Key

```bash
curl -s -X DELETE https://api.resend.com/api-keys/<key-id> \
  -H "Authorization: Bearer $RESEND_API_KEY"
```

### Key Rotation

1. Create a new key with `POST /api-keys`
2. Update the server env file with the new key
3. Restart the app: `docker compose -p metric-flow-uat --env-file /opt/metric_flow/uat.env restart app`
4. Verify emails send successfully
5. Delete the old key with `DELETE /api-keys/<old-key-id>`

---

## 5. Phoenix Integration

### How It Works

MetricFlow uses Swoosh with the built-in Resend adapter (`Swoosh.Adapters.Resend`,
available since Swoosh 1.20.0). No extra dependencies needed.

### Configuration

```elixir
# config/config.exs -- dev default (local mailbox at /dev/mailbox)
config :metric_flow, MetricFlow.Mailer, adapter: Swoosh.Adapters.Local

# config/dev.exs
config :swoosh, :api_client, false

# config/prod.exs
config :swoosh, api_client: Swoosh.ApiClient.Req

# config/runtime.exs -- inside `if config_env() == :prod do`
config :metric_flow, MetricFlow.Mailer,
  adapter: Swoosh.Adapters.Resend,
  api_key: System.fetch_env!("RESEND_API_KEY")
```

### Environment Variables

| Environment | Variable         | Where                            |
|-------------|------------------|----------------------------------|
| dev         | (none needed)    | Uses `Swoosh.Adapters.Local`     |
| test        | (none needed)    | Uses `Swoosh.Adapters.Test`      |
| UAT         | `RESEND_API_KEY` | `/opt/metric_flow/uat.env`       |
| prod        | `RESEND_API_KEY` | `/opt/metric_flow/prod.env`      |

### Sending a Test Email (API)

Quick test that bypasses the app entirely -- useful for verifying the API key works:

```bash
curl -s -X POST https://api.resend.com/emails \
  -H "Authorization: Bearer $RESEND_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "from": "MetricFlow <noreply@metric-flow.app>",
    "to": ["your-email@example.com"],
    "subject": "Test from Resend",
    "text": "If you see this, Resend is working."
  }' | python3 -m json.tool
```

### Sending via Phoenix (IEx)

```elixir
# In a running prod console:
# docker compose -p metric-flow-uat exec app /app/bin/metric_flow remote

import Swoosh.Email

new()
|> to("your-email@example.com")
|> from({"MetricFlow", "noreply@metric-flow.app"})
|> subject("Test from Phoenix")
|> text_body("If you see this, Swoosh + Resend is working.")
|> MetricFlow.Mailer.deliver()
```

---

## 6. Agency White-Label Domains

Each agency can send emails from their own domain (e.g. `noreply@clientagency.com`).
This requires adding and verifying the agency's domain in Resend.

### Programmatic Domain Onboarding

```bash
# 1. Add the agency domain
curl -s -X POST https://api.resend.com/domains \
  -H "Authorization: Bearer $RESEND_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name": "clientagency.com", "region": "us-east-1"}' | python3 -m json.tool

# 2. Response includes DNS records the agency must add
# 3. After they add records, trigger verification
curl -s -X POST https://api.resend.com/domains/<domain-id>/verify \
  -H "Authorization: Bearer $RESEND_API_KEY"

# 4. Check verification status
curl -s https://api.resend.com/domains/<domain-id> \
  -H "Authorization: Bearer $RESEND_API_KEY" | python3 -m json.tool
```

### Domain Limit by Plan

| Plan   | Max Domains |
|--------|------------|
| Free   | 1          |
| Pro    | 10         |
| Scale  | 10         |

Monitor domain count as agencies onboard. Upgrade plan before hitting the limit.

---

## 7. Monitoring and Debugging

### Email Logs

View sent emails in the Resend dashboard: https://resend.com/emails

### Get Email Details via API

```bash
# Get details of a specific email
curl -s https://api.resend.com/emails/<email-id> \
  -H "Authorization: Bearer $RESEND_API_KEY" | python3 -m json.tool
```

### Webhooks (Optional)

Resend supports webhooks for delivery events (delivered, bounced, complained, etc.):

```bash
curl -s -X POST https://api.resend.com/webhooks \
  -H "Authorization: Bearer $RESEND_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://metric-flow.app/webhooks/resend",
    "events": ["email.delivered", "email.bounced", "email.complained"]
  }' | python3 -m json.tool
```

### Common Issues

**"Missing API key" error on deploy:**
`RESEND_API_KEY` is not set in the server env file. The app will crash on startup
because `runtime.exs` uses `System.fetch_env!` (raises if missing).

**"Domain not verified" / 403 on send:**
The `from` address uses a domain not verified in Resend. Check domain status with
`GET /domains/<id>`. If DNS records were recently added, trigger re-verification
with `POST /domains/<id>/verify`.

**"Rate limit exceeded" / 429:**
Free plan is capped at 100 emails/day. Upgrade to Pro or check for runaway
notification loops.

**Emails going to spam:**
Check that all three DNS records (DKIM TXT, SPF MX, SPF TXT) are correctly set.
Run `dig TXT resend._domainkey.metric-flow.app +short` to verify DKIM is resolving.
Also ensure the `from` name and address look legitimate (not generic like "test").

---

## 8. Resend API Reference

| Endpoint                         | Method | Purpose                        |
|----------------------------------|--------|--------------------------------|
| `/emails`                        | POST   | Send an email                  |
| `/emails/:id`                    | GET    | Get email status               |
| `/domains`                       | GET    | List all domains               |
| `/domains`                       | POST   | Add a domain                   |
| `/domains/:id`                   | GET    | Get domain details + DNS       |
| `/domains/:id`                   | DELETE | Remove a domain                |
| `/domains/:id/verify`            | POST   | Trigger domain verification    |
| `/api-keys`                      | GET    | List API keys                  |
| `/api-keys`                      | POST   | Create an API key              |
| `/api-keys/:id`                  | DELETE | Delete an API key              |
| `/webhooks`                      | GET    | List webhooks                  |
| `/webhooks`                      | POST   | Create a webhook               |
| `/webhooks/:id`                  | DELETE | Delete a webhook               |

Base URL: `https://api.resend.com`
Auth header: `Authorization: Bearer re_xxx`
Full docs: https://resend.com/docs/api-reference
