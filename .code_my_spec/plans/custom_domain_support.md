# Custom Domain Support for White-Label Agencies

## Context

Agencies currently get a subdomain like `anderson.metric-flow.app`. The goal is to also support fully custom domains like `analytics.andersonthefish.com`. Both approaches work side by side. The DNS verification button in the settings UI is already stubbed — this implements it for real.

---

## Implementation Steps

### 1. Migration

**New file:** `priv/repo/migrations/YYYYMMDDHHMMSS_add_custom_domain_to_white_label_configs.exs`

- `custom_domain :string` — nullable
- `custom_domain_verified_at :utc_datetime` — nullable
- `subdomain_verified_at :utc_datetime` — nullable
- Partial unique index on `custom_domain` (`WHERE custom_domain IS NOT NULL`)

### 2. Schema

**File:** `lib/metric_flow/agencies/white_label_config.ex`

- Add 3 fields to schema + `@type t`
- Add `:custom_domain` to `cast/4` (not `validate_required`)
- Validate: hostname format `^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}$`, max 253 chars, reject `*.metric-flow.app`
- `unique_constraint(:custom_domain)`
- New `dns_verification_changeset/2` for `*_verified_at` timestamps only

### 3. Repository

**File:** `lib/metric_flow/agencies/agencies_repository.ex`

- `get_white_label_config_by_custom_domain/1` — query by `custom_domain` WHERE `custom_domain_verified_at IS NOT NULL`
- `update_dns_verification/2` — uses `dns_verification_changeset`
- Fix `upsert_white_label_config/2` — add `custom_domain_verified_at` and `subdomain_verified_at` to `replace_all_except` list so saves don't clobber verification timestamps

### 4. Context

**File:** `lib/metric_flow/agencies.ex`

- `get_white_label_config_by_custom_domain/1` — public, no auth (used by plug)
- `verify_dns/2` — requires admin scope, performs DNS lookup, updates `*_verified_at`
- Update `update_white_label_config/3` — clear `custom_domain_verified_at` when `custom_domain` value changes
- DNS lookup via configurable module (see testing section) defaulting to `:inet_res`

### 5. WhiteLabel Plug

**File:** `lib/metric_flow_web/plugs/white_label.ex`

Rewrite `call/2`:
1. If host does NOT end with `.metric-flow.app`, try `get_white_label_config_by_custom_domain(conn.host)`
2. Fall back to subdomain extraction (existing logic)
3. Add `custom_domain` to session map

### 6. Settings UI

**File:** `lib/metric_flow_web/live/agency_live/settings.ex`

- Add "Custom Domain" text input after subdomain field
- Update DNS verification section: per-domain status badges (verified/pending) for both subdomain and custom domain
- Help text with CNAME instructions

**File:** `lib/metric_flow_web/live/agency_live/agency_settings.ex`

- Add `custom_domain` to attrs in `save_white_label` handler
- Implement `verify_dns` handler — call `Agencies.verify_dns/2`, reload config, flash results

### 7. Production Config

**File:** `config/runtime.exs` (~line 120)

- Add `check_origin: :conn` to endpoint config so LiveView WebSockets accept connections from any custom domain

---

## What Does NOT Change

- **Session cookies** — `same_site: "Lax"` with default domain scoping works per-origin
- **CSP headers** — `'self'` adapts to serving origin automatically
- **Dev config** — already `check_origin: false`

## Infrastructure (out of scope, needed for production)

- TLS for custom domains: Caddy `on_demand_tls` or Cloudflare for SaaS
- Optional `/api/tls/check` endpoint for Caddy's `ask` directive

---

## Test Strategy

### DNS Lookup Stub

The project uses `Application.put_env` + `on_exit` for stubbing (no Mox/Mimic). For DNS verification:

- Extract DNS lookup to a configurable module via app env:
  ```elixir
  # In agencies.ex
  defp dns_client, do: Application.get_env(:metric_flow, :dns_client, MetricFlow.Agencies.DnsClient)
  ```
- Default `DnsClient` module wraps `:inet_res.lookup/3`
- Test stub replaces it with a module that returns canned responses
- Create `test/support/dns_stub.ex` following the `OAuthStub`/`AiStub` pattern

### Unit Tests

**1. Schema changeset** (`test/metric_flow/agencies/white_label_config_test.exs`)

Add to existing test file:
- Valid custom_domain accepted (e.g. `analytics.example.com`)
- Rejects invalid hostnames (no dots, trailing dot, uppercase, special chars)
- Rejects `*.metric-flow.app` domains
- Allows nil/empty custom_domain (optional field)
- Max length 253
- Unique constraint on custom_domain
- `dns_verification_changeset` accepts only timestamp fields

**2. Repository queries** (new or extend existing)

- `get_white_label_config_by_custom_domain/1` returns config when domain matches AND verified
- Returns nil when domain matches but NOT verified
- Returns nil when no match
- `update_dns_verification/2` sets timestamps correctly
- `upsert_white_label_config/2` preserves `*_verified_at` on re-save

**3. DNS verification logic** (new test file or in agencies_test.exs)

Using the DNS stub:
- Returns `:verified` when CNAME points to `app.metricflow.io`
- Returns `:not_found` when no CNAME exists
- Returns `{:wrong_target, actual}` when CNAME points elsewhere
- Sets `custom_domain_verified_at` on success
- Sets `subdomain_verified_at` on success
- Handles nil/empty custom_domain as `:not_configured`

### Plug Tests

**File:** `test/metric_flow_web/plugs/white_label_test.exs`

Add to existing test file:
- Custom domain host resolves to correct config (with verified domain in DB)
- Unverified custom domain returns nil config
- Custom domain takes priority over subdomain extraction
- Subdomain extraction still works for `*.metric-flow.app` hosts
- `metric-flow.app` hosts skip custom domain lookup entirely

### LiveView Tests

**File:** extend or add to agency settings tests

- Custom domain field renders in the form
- Saving with valid custom_domain persists it
- Saving with invalid custom_domain shows validation error
- Verify DNS button triggers verification and shows results
- Changing custom_domain clears verified status in UI

### Spex (BDD)

Existing criterion_4158 covers DNS verification — update/extend it:
- Scenario: agency sets custom domain, sees "Pending" badge
- Scenario: agency clicks Verify DNS, sees "Verified" badge (with DNS stub)
- Scenario: agency changes custom domain, verification resets to "Pending"

---

## File Summary

| File | Action |
|------|--------|
| `priv/repo/migrations/*_add_custom_domain.exs` | Create |
| `lib/metric_flow/agencies/white_label_config.ex` | Edit |
| `lib/metric_flow/agencies/agencies_repository.ex` | Edit |
| `lib/metric_flow/agencies.ex` | Edit |
| `lib/metric_flow/agencies/dns_client.ex` | Create |
| `lib/metric_flow_web/plugs/white_label.ex` | Edit |
| `lib/metric_flow_web/live/agency_live/settings.ex` | Edit |
| `lib/metric_flow_web/live/agency_live/agency_settings.ex` | Edit |
| `config/runtime.exs` | Edit |
| `test/support/dns_stub.ex` | Create |
| `test/metric_flow/agencies/white_label_config_test.exs` | Edit |
| `test/metric_flow_web/plugs/white_label_test.exs` | Edit |
