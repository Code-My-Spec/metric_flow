# Secrets inventory — `/metric_flow/{prod,uat}/*`

The list of every SSM Parameter Store key the deployed app fetches at
boot, with format hints. Source values live in
`/metric_flow/<env>/<KEY>` as `SecureString` parameters in AWS account
`889081505590`, region `us-east-1`. See `secrets-runtime.md` for
how the values get into the running app.

This file is for humans **and LLMs** who need to know "which keys does
metric_flow expect, and what does each one look like?" without seeing
the actual values. Update it whenever a key is added or removed.

| Key                              | Type          | Format / Pattern                                                          | Per-env? | Notes                                                                                              |
|----------------------------------|---------------|---------------------------------------------------------------------------|----------|----------------------------------------------------------------------------------------------------|
| `DATABASE_URL`                   | secret        | `ecto://<user>:<password>@infra-postgres-1/<db>`                          | yes      | Per-app DB user. Host is the shared-infra Postgres container on the box.                           |
| `SECRET_KEY_BASE`                | secret        | 64+ chars, base64-ish; `mix phx.gen.secret`                               | yes      | Phoenix session signing.                                                                           |
| `CLOAK_KEY`                      | secret        | base64 of 32 raw bytes                                                    | yes      | Symmetric key for Cloak.Ciphers.AES.GCM. Encrypts at-rest fields in DB.                            |
| `PHX_HOST`                       | config        | hostname (e.g. `metric-flow.app`, `uat.metric-flow.app`)                  | yes      | Used by Endpoint url config.                                                                       |
| `PHX_SERVER`                     | config        | `true` (literal string)                                                    | both same | Tells release to start Phoenix endpoint; presence-checked, not parsed.                            |
| `SENTRY_DSN`                     | semi-secret   | `https://<token>@<region>.ingest.us.sentry.io/<project_id>`               | yes      | Sentry recommends treating DSN as semi-public; we mark @sensitive anyway.                          |
| `ANTHROPIC_API_KEY`              | secret        | `sk-ant-api03-…`                                                          | shared   | Same key for prod + UAT — usage on the same Anthropic account.                                     |
| `RESEND_API_KEY`                 | secret        | `re_…`                                                                    | yes      | Distinct keys per env recommended (Resend supports it).                                            |
| `GOOGLE_CLIENT_ID`               | secret-ish    | `<digits>-<hash>.apps.googleusercontent.com`                              | shared?  | Public-facing OAuth ID; treated as @sensitive for transcript safety. Verify single OAuth app vs per-env. |
| `GOOGLE_CLIENT_SECRET`           | secret        | `GOCSPX-…`                                                                | shared?  | Pairs with `GOOGLE_CLIENT_ID`.                                                                     |
| `GOOGLE_ADS_DEVELOPER_TOKEN`     | secret        | 22 chars, alnum                                                           | shared   | Google Ads API developer-level token; same for both envs.                                          |
| `GOOGLE_ADS_LOGIN_CUSTOMER_ID`   | config        | digits (`<10-digit-id>` no dashes)                                        | yes      | Google Ads MCC ID. UAT can be empty/placeholder until needed.                                      |
| `FACEBOOK_APP_ID`                | secret-ish    | digits (`<15-19-digit-id>`)                                               | shared?  | OAuth client ID. Treated as @sensitive.                                                            |
| `FACEBOOK_APP_SECRET`            | secret        | 32 chars, hex                                                             | shared?  | Pairs with `FACEBOOK_APP_ID`.                                                                      |
| `QUICKBOOKS_CLIENT_ID`           | secret        | `AB<base62>` (~40+ chars)                                                 | shared?  | Intuit OAuth.                                                                                      |
| `QUICKBOOKS_CLIENT_SECRET`       | secret        | base62, ~40 chars                                                         | shared?  | Pairs with `QUICKBOOKS_CLIENT_ID`.                                                                 |
| `QUICKBOOKS_API_URL`             | config        | `https://(sandbox-)?quickbooks.api.intuit.com`                            | yes      | Sandbox URL on UAT, production URL on prod.                                                        |

## "Per-env?" column

- **yes** — different value in each env. Rotating one doesn't affect
  the other.
- **shared** — same value across envs (same upstream account /
  credential). One rotation requires N parameter updates.
- **shared?** — possibly shared; not yet confirmed during the
  2026-05-06 cutover. Worth verifying before relying on the assumption.
- **both same** — value is the same string but conceptually
  per-env; the only legitimate value happens to be identical.

## Legacy / deprecated keys

| Key                  | Status                                                                 |
|----------------------|------------------------------------------------------------------------|
| `POSTGRES_DB`        | Pre-`DATABASE_URL` style; obsolete. Safe to delete from SSM.           |
| `POSTGRES_PASSWORD`  | Pre-`DATABASE_URL` style; obsolete. Safe to delete from SSM.           |
| `CLOUDFLARE_API_TOKEN` (UAT only) | Stored under metric_flow because it's a metric-flow.app DNS token. Not consumed by the runtime app. Move to `/metric_flow/_ops/CLOUDFLARE_API_TOKEN` (operator-side) when convenient. |
| `CLOUDFLARE_TUNNEL_SECRET` (UAT only) | Dev-only Cloudflare Tunnel secret for `dev.metric-flow.app`. Not consumed in UAT runtime. Same migration path as above. |

## Adding a new key

1. Add to `.env.schema` (root of repo) with `@sensitive` if it's a
   secret. This documents it for dev + LLMs.
2. Add this row to the table above.
3. `aws ssm put-parameter --name /metric_flow/<env>/<KEY> --value '...'
   --type SecureString` for each env that needs the value.
4. Read it in `config/runtime.exs` via `env!("KEY", :string!, …)`.
5. Redeploy each env (`MetricFlow.Secrets.load!/1` runs at boot).

## Rotating a key

```bash
# 1. Update value in SSM
aws ssm put-parameter --name /metric_flow/prod/SOME_KEY \
  --value 'new-value' --type SecureString --overwrite

# 2. Roll the container — it re-fetches at boot
just deploy
```

For `shared?` keys, do the put-parameter once per env that uses the
same upstream credential.

## Inventory drift

This list is hand-maintained. To diff it against reality:

```bash
aws ssm get-parameters-by-path --path /metric_flow/prod \
  --recursive --query 'Parameters[].Name' --output text \
  | tr '\t' '\n' | sort
```

If this command lists a key not documented above, add it. If a row
above isn't in SSM and isn't in "Legacy", remove it.
