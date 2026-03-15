# Cloudflare + Resend Email Setup

How to configure transactional email for a Phoenix app using **Resend** as the email provider with a domain managed by **Cloudflare DNS**.

## Overview

- **Email provider**: [Resend](https://resend.com) — API-based transactional email service
- **DNS provider**: Cloudflare — manages domain DNS records including email authentication (SPF, DKIM, DMARC)
- **Elixir library**: [Swoosh](https://hexdocs.pm/swoosh) with `Swoosh.Adapters.Resend`
- **API client**: `Swoosh.ApiClient.Req` (uses the Req HTTP library already in the project)

## 1. Create a Resend Account & API Key

1. Sign up at [resend.com](https://resend.com)
2. Go to **API Keys** → **Create API Key**
3. Name it after the environment (e.g. `fuellytics-prod`)
4. Copy the key — it starts with `re_` (e.g. `re_ivXHbYW9_...`)
5. Store it in your environment secrets file (e.g. `envs/prod.env`):

```bash
RESEND_API_KEY=re_your_api_key_here
```

## 2. Add Your Domain in Resend

1. In the Resend dashboard, go to **Domains** → **Add Domain**
2. Enter your domain (e.g. `fuellytics.com` or `fuellytics.app`)
3. Resend will provide DNS records you need to add — typically:
   - **SPF** (TXT record)
   - **DKIM** (CNAME records, usually 3)
   - **DMARC** (TXT record, optional but recommended)

## 3. Add DNS Records in Cloudflare

In your Cloudflare dashboard for the domain:

1. Go to **DNS** → **Records**
2. Add each record Resend provides:

### SPF Record

| Type | Name | Content | Proxy |
|------|------|---------|-------|
| TXT | `@` | `v=spf1 include:send.resend.com ~all` | N/A (TXT records are never proxied) |

> If you already have an SPF record (e.g. for another email provider), merge the `include:` directive into the existing record rather than creating a second one. Only one SPF record is allowed per domain.

### DKIM Records

Resend provides 3 CNAME records for DKIM signing. Add them exactly as shown:

| Type | Name | Content | Proxy |
|------|------|---------|-------|
| CNAME | `resend._domainkey` | *(value from Resend dashboard)* | **DNS only** (grey cloud) |
| CNAME | `resend2._domainkey` | *(value from Resend dashboard)* | **DNS only** (grey cloud) |
| CNAME | `resend3._domainkey` | *(value from Resend dashboard)* | **DNS only** (grey cloud) |

> **Important**: DKIM CNAME records must NOT be proxied (orange cloud). Toggle to **DNS only** (grey cloud) or they won't resolve correctly.

### DMARC Record (recommended)

| Type | Name | Content | Proxy |
|------|------|---------|-------|
| TXT | `_dmarc` | `v=DMARC1; p=none; rua=mailto:dmarc@yourdomain.com` | N/A |

4. Go back to Resend dashboard and click **Verify** — it checks DNS propagation
5. Once verified, the domain status shows **Verified** and you can send from any address `@yourdomain.com`

## 4. Configure the Phoenix App

### Dependencies (mix.exs)

Swoosh and Req should already be in your deps:

```elixir
{:swoosh, "~> 1.16"},
{:req, "~> 0.5"},
```

### Mailer Module

```elixir
# lib/my_app/mailer.ex
defmodule MyApp.Mailer do
  use Swoosh.Mailer, otp_app: :my_app
end
```

### Config: Development (config/dev.exs)

Use the local adapter — emails are viewable at `/dev/mailbox`:

```elixir
config :my_app, MyApp.Mailer, adapter: Swoosh.Adapters.Local

# Disable the API client (not needed for local adapter)
config :swoosh, :api_client, false
```

### Config: Test (config/test.exs)

```elixir
config :my_app, MyApp.Mailer, adapter: Swoosh.Adapters.Test
config :swoosh, :api_client, false
```

### Config: Production (config/prod.exs)

Enable the Req-based API client for Swoosh:

```elixir
# Use Req as the Swoosh API client for Resend
config :swoosh, :api_client, Swoosh.ApiClient.Req
```

### Config: Runtime (config/runtime.exs)

Configure the Resend adapter with the API key from the environment:

```elixir
if config_env() == :prod do
  config :my_app, MyApp.Mailer,
    adapter: Swoosh.Adapters.Resend,
    api_key: env!("RESEND_API_KEY", :string, "")
end
```

### Docker Compose

Pass the API key through to the app container:

```yaml
services:
  app:
    environment:
      RESEND_API_KEY: ${RESEND_API_KEY:-}
```

## 5. Sending Emails

### Basic Email

```elixir
import Swoosh.Email

new()
|> to("user@example.com")
|> from({"MyApp", "noreply@mydomain.com"})
|> subject("Welcome!")
|> text_body("Hello from MyApp")
|> MyApp.Mailer.deliver()
```

### With Attachments

```elixir
attachment = Swoosh.Attachment.new({:data, binary_data}, filename: "report.pdf")

new()
|> to(recipient)
|> from({"MyApp", "noreply@mydomain.com"})
|> subject("Your Report")
|> text_body("See attached.")
|> Swoosh.Email.attachment(attachment)
|> MyApp.Mailer.deliver()
```

### From Address

The `from` address must use a domain verified in Resend. Common pattern:

```elixir
@default_from {"MyApp", "noreply@mydomain.com"}
```

## 6. Troubleshooting

| Issue | Fix |
|-------|-----|
| Emails not sending in prod | Check `RESEND_API_KEY` is set and non-empty |
| Resend domain not verifying | Ensure DKIM CNAMEs are **DNS only** (not proxied) in Cloudflare |
| SPF failures | Ensure only one SPF TXT record exists on the domain |
| Emails going to spam | Add DMARC record, ensure SPF + DKIM both pass |
| `** (RuntimeError) :api_client is not set` | Add `config :swoosh, :api_client, Swoosh.ApiClient.Req` in prod.exs |
| Dev mailbox not showing | Ensure `dev_routes: true` in config and visit `/dev/mailbox` |
