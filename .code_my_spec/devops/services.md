# MetricFlow: External Services

All third-party services used by MetricFlow, their configuration, and how credentials flow.

---

## 1. Email: Resend

**Used in:** Production only (dev/test use Swoosh Local adapter with `/dev/mailbox`)

### Configuration

```elixir
# config/runtime.exs (prod block)
config :metric_flow, MetricFlow.Mailer,
  adapter: Swoosh.Adapters.Resend,
  api_key: System.fetch_env!("RESEND_API_KEY")
```

### Env Vars

| Variable         | Example                    | Where              |
|------------------|----------------------------|--------------------|
| `RESEND_API_KEY` | `re_xxxxxxxxxxxxxxxx`      | prod.env, uat.env  |

### Setup Checklist

- [ ] Create Resend account at resend.com
- [ ] Add and verify sending domain (SPF, DKIM records in Cloudflare)
- [ ] Get API key from Resend dashboard
- [ ] Add `RESEND_API_KEY` to server env files

### Domain Verification

Each sending domain must be verified in Resend. Go to Resend dashboard > Domains > Add Domain,
then add the DNS records Resend provides to Cloudflare.

For agency white-labeling, each agency's sender domain also needs verification via the
Resend Domains API (`POST https://api.resend.com/domains`).

### Pricing

| Plan   | Price     | Emails/month | Domains |
|--------|-----------|-------------|---------|
| Free   | $0        | 3,000       | 1       |
| Pro    | $20/month | 50,000      | 10      |
| Scale  | $90/month | 100,000     | 10      |

---

## 2. File Storage: Tigris (S3-compatible)

**Used in:** Production (dev uses local disk)

Tigris is an S3-compatible object store on Fly.io's infrastructure.

### Configuration

```elixir
# config/runtime.exs (prod block)
config :ex_aws,
  access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
  secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY")

config :ex_aws, :s3,
  scheme: "https://",
  host: "fly.storage.tigris.dev",
  region: "auto"
```

### Env Vars

| Variable                | Where              |
|-------------------------|--------------------|
| `AWS_ACCESS_KEY_ID`     | prod.env, uat.env  |
| `AWS_SECRET_ACCESS_KEY` | prod.env, uat.env  |

### Notes

- Uses ExAws with Req HTTP client (no Hackney dependency)
- Endpoint is `fly.storage.tigris.dev`, not AWS S3
- Region is `"auto"` (Tigris handles routing)
- The `AWS_*` env var names are reused for S3 API compatibility

---

## 3. Error Tracking: Sentry

**Used in:** Production only

### Configuration

```elixir
# config/config.exs
config :sentry, client: Sentry.FinchHTTPClient

# config/runtime.exs (prod block)
config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  environment_name: :prod,
  enable_source_code_context: true,
  root_source_code_paths: [File.cwd!()],
  integrations: [oban: [capture_errors: true]]
```

### Env Vars

| Variable     | Where              |
|--------------|--------------------|
| `SENTRY_DSN` | prod.env, uat.env  |

---

## 4. Encryption: Cloak

**Used in:** All environments (encrypts sensitive DB fields like OAuth tokens)

### Configuration

```elixir
# config/config.exs -- dev/test default key (NOT for production)
config :metric_flow, MetricFlow.Vault,
  ciphers: [
    default: {
      Cloak.Ciphers.AES.GCM,
      tag: "AES.GCM.V1",
      key: Base.decode64!("w09FSTq2MKlGVsfejph/sQiw6j9PSrqmgpCccRNG33s="),
      iv_length: 12
    }
  ]

# config/runtime.exs -- prod overrides with env var
if cloak_key = System.get_env("CLOAK_KEY") do
  config :metric_flow, MetricFlow.Vault, ...
end
```

### Env Vars

| Variable    | Where              |
|-------------|--------------------|
| `CLOAK_KEY` | prod.env, uat.env  |

### Generate a New Key

```elixir
# In IEx
:crypto.strong_rand_bytes(32) |> Base.encode64()
```

**WARNING:** Changing the Cloak key in an environment with existing encrypted data
will make that data unreadable. You must migrate encrypted fields if you rotate keys.

---

## 5. AI: Anthropic Claude

**Used in:** All environments (for AI insights, chat features)

### Configuration

```elixir
# config/runtime.exs
if anthropic_key = System.get_env("ANTHROPIC_API_KEY") do
  config :req_llm, :anthropic_api_key, anthropic_key
end
```

### Env Vars

| Variable            | Where                      |
|---------------------|----------------------------|
| `ANTHROPIC_API_KEY` | .env (dev), prod.env, uat.env |

---

## 6. OAuth Providers

**Used in:** All environments (for platform integrations -- GitHub, Google)

### Configuration

```elixir
# config/runtime.exs
config :metric_flow,
  github_client_id: env!("GITHUB_CLIENT_ID", :string, nil),
  github_client_secret: env!("GITHUB_CLIENT_SECRET", :string, nil),
  google_client_id: env!("GOOGLE_CLIENT_ID", :string, nil),
  google_client_secret: env!("GOOGLE_CLIENT_SECRET", :string, nil),
  oauth_base_url: env!("OAUTH_BASE_URL", :string, nil)
```

### Env Vars

| Variable                | Where                      |
|-------------------------|----------------------------|
| `GITHUB_CLIENT_ID`      | .env (dev), prod.env, uat.env |
| `GITHUB_CLIENT_SECRET`  | .env (dev), prod.env, uat.env |
| `GOOGLE_CLIENT_ID`      | .env (dev), prod.env, uat.env |
| `GOOGLE_CLIENT_SECRET`  | .env (dev), prod.env, uat.env |
| `OAUTH_BASE_URL`        | .env (dev), prod.env, uat.env |

The `OAUTH_BASE_URL` should match the environment's public URL:
- dev: `https://dev.metric-flow.app`
- uat: `https://uat.metric-flow.app`
- prod: `https://metric-flow.app`

---

## 7. Background Jobs: Oban

**Used in:** All environments

### Configuration

```elixir
# config/config.exs
config :metric_flow, Oban,
  repo: MetricFlow.Repo,
  queues: [default: 10, sync: 5, correlations: 3]

# config/runtime.exs (prod block) -- adds cron schedule
config :metric_flow, Oban,
  plugins: [
    {Oban.Plugins.Cron,
     crontab: [
       {"0 2 * * *", MetricFlow.DataSync.Scheduler, queue: :sync, max_attempts: 1}
     ]}
  ]
```

The daily data sync runs at 2:00 AM UTC in production.

---

## Complete Env Var Reference

### Production / UAT (server env files)

| Variable                | Required | Service          |
|-------------------------|----------|------------------|
| `POSTGRES_PASSWORD`     | Yes      | Database         |
| `SECRET_KEY_BASE`       | Yes      | Phoenix          |
| `PHX_HOST`              | Yes      | Phoenix          |
| `DATABASE_URL`          | Auto*    | Ecto             |
| `RESEND_API_KEY`        | Yes      | Email            |
| `CLOAK_KEY`             | Yes      | Encryption       |
| `SENTRY_DSN`            | No       | Error tracking   |
| `AWS_ACCESS_KEY_ID`     | No       | Tigris/S3        |
| `AWS_SECRET_ACCESS_KEY` | No       | Tigris/S3        |
| `ANTHROPIC_API_KEY`     | No       | AI features      |
| `GITHUB_CLIENT_ID`      | No       | OAuth            |
| `GITHUB_CLIENT_SECRET`  | No       | OAuth            |
| `GOOGLE_CLIENT_ID`      | No       | OAuth            |
| `GOOGLE_CLIENT_SECRET`  | No       | OAuth            |
| `OAUTH_BASE_URL`        | No       | OAuth            |

*`DATABASE_URL` is constructed in docker-compose.yml from `POSTGRES_PASSWORD`.

### Dev (local .env file)

| Variable                    | Required | Notes                          |
|-----------------------------|----------|--------------------------------|
| `CLOUDFLARE_TUNNEL_SECRET`  | No       | For dev.metric-flow.app tunnel |
| `ANTHROPIC_API_KEY`         | No       | For AI feature development     |
| `GITHUB_CLIENT_ID`          | No       | For OAuth testing              |
| `GITHUB_CLIENT_SECRET`      | No       | For OAuth testing              |
| `GOOGLE_CLIENT_ID`          | No       | For OAuth testing              |
| `GOOGLE_CLIENT_SECRET`      | No       | For OAuth testing              |
| `OAUTH_BASE_URL`            | No       | `https://dev.metric-flow.app`  |
