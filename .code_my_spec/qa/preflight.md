# QA Preflight Report

Date: 2026-04-06

## Compilation

- `mix compile` — **pass** (no errors, warnings only)

## Migrations

- `mix ecto.migrate` — up to date

## Server

- Phoenix server running on localhost:4070 (HTTP 200)
- Cloudflare tunnel active at dev.metric-flow.app

## Integration Verification

All verify scripts run via `.code_my_spec/qa/scripts/verify_*.sh` with `.env.dev` credentials loaded.

| Integration | Auth Type | Script | Status | Details |
|---|---|---|---|---|
| Anthropic Claude | api_token | verify_anthropic.sh | ok | API key valid — Haiku 4.5 responded successfully |
| Cloudflare Tunnel | api_token | verify_cloudflare_tunnel.sh | ok | Tunnel reachable — dev.metric-flow.app returned HTTP 200 |
| Facebook Ads | oauth2 | verify_facebook_ads.sh | ok | App access token obtained. FACEBOOK_TEST_ACCESS_TOKEN not set (optional for API testing) |
| Google OAuth | oauth2 | verify_google_oauth.sh | ok | Client ID valid (HTTP 302 from auth endpoint). GOOGLE_ADS_DEVELOPER_TOKEN not set — Ads API calls will fail |
| QuickBooks Online | oauth2 | verify_quickbooks.sh | ok | Client credentials accepted (HTTP 400 = invalid code, credentials valid). Test tokens not set |
| Resend (Email) | api_token | verify_resend.sh | ok | API key valid — domains endpoint returned HTTP 200 |
| Stripe Billing | api_token | start-stripe-listener.sh | ok | Permanent webhook endpoint registered (we_1TIvE8GkgiYxMEomtkIaDURR). sk_test key valid. stripe trigger succeeds |

## Warnings

- `GOOGLE_ADS_DEVELOPER_TOKEN` not set — Google Ads API calls will fail at runtime
- `FACEBOOK_TEST_ACCESS_TOKEN` / `QUICKBOOKS_TEST_ACCESS_TOKEN` not set — needed for full API integration testing only

## Issues

No blocking issues found during preflight.

## Overall Status

**PASS** — all 7 integrations verified (including Stripe), app compiles and serves cleanly.
