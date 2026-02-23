# Data Provider API Integration Strategy

## Status
Accepted (Revised)

## Context

MetricFlow needs to fetch metrics from four external platforms on a scheduled and on-demand basis: Google Analytics (GA4), Google Ads, Facebook Ads, and QuickBooks Online. The `DataSync` context defines a `DataProviders.Behaviour` contract with `fetch_metrics/2`, `provider/0`, and `required_scopes/0` callbacks that all four provider implementations must satisfy.

The system already uses:
- **Assent (~> 0.2)** for OAuth flows (authorization URL generation and token exchange)
- **Req (~> 0.5)** as the HTTP client
- **Oban (~> 2.2)** for background job scheduling and retry management
- **cloak_ecto** for encrypted token storage in the `Integration` schema

### Revision Note

This decision was originally "raw Req for all four providers." It has been revised to use the
official Google API Elixir client libraries (`googleapis/elixir-google-api`) for Google Analytics,
while retaining raw Req for Google Ads, Facebook Ads, and QuickBooks where no maintained official
library exists.

---

## Decision

### Google Analytics: Official Google API Client Library

**Package:** `google_api_analytics_data ~> 0.17` (154K downloads, Nov 2024, maintained by Google Cloud)

The `googleapis/elixir-google-api` project auto-generates Elixir clients from Google's Discovery
API. The `google_api_analytics_data` package provides typed request/response structs for the GA4
Data API.

**Authentication:** The library accepts OAuth bearer tokens directly — it is NOT locked to service
accounts. Create a connection with the user's access token:

```elixir
connection = GoogleApi.AnalyticsData.V1beta.Connection.new(access_token)

GoogleApi.AnalyticsData.V1beta.Api.Properties.analyticsdata_properties_run_report(
  connection,
  "properties/#{property_id}",
  body: %GoogleApi.AnalyticsData.V1beta.Model.RunReportRequest{
    dateRanges: [%{startDate: start_date, endDate: end_date}],
    metrics: [%{name: "sessions"}, %{name: "totalUsers"}],
    dimensions: [%{name: "date"}]
  }
)
```

**Dependencies added:** `google_api_analytics_data` pulls in `google_gax` (Google API common
library). No `goth` dependency is required when using OAuth bearer tokens directly.

### Google Ads: Raw Req (REST API)

**No official Elixir Google Ads package exists.** GitHub issue #2110 on `googleapis/elixir-google-api`
proposes adding Google Ads RPC support, but it is not yet implemented. Google Ads uses a
gRPC/RPC transport incompatible with the auto-generation pipeline used for other Google APIs.

The Google Ads REST API v23+ (`customers/{id}/googleAds:searchStream`) works as plain
JSON-over-HTTPS, making raw Req a straightforward approach.

- **Endpoint:** `POST https://googleads.googleapis.com/v23/customers/{customer_id}/googleAds:searchStream`
- **Auth:** `Authorization: Bearer {access_token}` header plus `developer-token: {token}` header
- **Required OAuth scope:** `https://www.googleapis.com/auth/adwords`
- **Developer token:** App-level credential from Google Ads API Center, stored in `config/runtime.exs`
- **Query language:** GAQL (Google Ads Query Language) — queries built as plain strings
- **Pagination:** SearchStream returns the entire result set in one response; no pagination needed
- **Rate limit response:** HTTP 429 with `RESOURCE_EXHAUSTED`

### Facebook Ads: Raw Req (Marketing API)

No maintained Elixir library exists for the Facebook Marketing API. The `facebook` package
(0.24.0, Aug 2019) is unmaintained for 5+ years. The `metaex` package (0.1.0, 115 downloads)
is unproven.

- **Endpoint:** `GET https://graph.facebook.com/v20.0/act_{ad_account_id}/insights`
- **Auth:** `access_token` as a query parameter (Facebook's standard pattern)
- **Required scopes:** `ads_read`, `ads_management`
- **Pagination:** Cursor-based via `paging.next` URL
- **Rate limit headers:** `X-App-Usage` and `X-Ad-Account-Usage` — parse in a custom Req response step
- **Token type:** Long-lived tokens (60 days), no standard refresh token. Log warnings near expiry.

### QuickBooks Online: Raw Req (Accounting API v3)

No maintained Elixir library exists. `exquickbooks` (0.8.0, Oct 2017) and `quickbooks` (0.1.1,
Jan 2017) both use deprecated HTTP clients and predate QuickBooks' OAuth 2.0 migration.

- **Endpoints:** `GET .../v3/company/{realm_id}/reports/ProfitAndLoss` and `BalanceSheet`
- **Auth:** `Authorization: Bearer {access_token}` header
- **Required scope:** `com.intuit.quickbooks.accounting`
- **Pagination:** Reports returned in single responses; no pagination needed
- **Token lifecycle:** 1-hour access tokens with long-lived refresh tokens (rotate on each refresh)

---

### Token Refresh Strategy

Token refresh is handled at the `Integrations` context level, not inside provider modules.
Provider modules return `{:error, :unauthorized}` on 401 responses. The `SyncWorker` catches
this and calls `Integrations.refresh_token/2` before retrying.

**Pre-flight expiry check:** Provider modules call `Integration.expired?/1` at the start of
`fetch_metrics/2`. If expired (or within 5-minute buffer), return `{:error, :token_expired}`
immediately.

**Facebook exception:** Facebook tokens cannot be programmatically refreshed. Return
`{:error, :token_expired}` and mark the sync as `requires_reauth`.

**Token refresh race condition:** Use database-level `select ... for update` in
`IntegrationRepository.update_integration/3` to prevent concurrent refresh writes.

---

### Req Configuration Pattern (for non-Google-library providers)

```elixir
defp build_req(access_token) do
  Req.new(
    auth: {:bearer, access_token},
    retry: :safe_transient,
    max_retries: 3,
    retry_delay: fn n -> trunc(Integer.pow(2, n) * 1_000) end,
    receive_timeout: 30_000
  )
end
```

For Google Ads, add the developer token header. For Facebook Ads, use `params:` instead of
`auth:` since the access token travels as a query parameter.

---

### Error Normalization

All provider modules normalize HTTP errors to atoms:

| HTTP Status / API Error      | Returned Error Atom              |
|------------------------------|----------------------------------|
| 401 Unauthorized             | `:unauthorized`                  |
| 403 Forbidden                | `:insufficient_permissions`      |
| 404 Not Found                | `:resource_not_found`            |
| 429 Too Many Requests        | `:rate_limited`                  |
| Network timeout / exception  | `:network_error`                 |
| Malformed JSON               | `:parse_error`                   |

---

### Testing Strategy

- **Google Analytics:** Mock at the `Connection` level or use `Req.Test` plug injection on the
  underlying HTTP calls
- **Google Ads, Facebook Ads, QuickBooks:** Accept an optional `:req` option in `fetch_metrics/2`
  for test injection via `Req.new(plug: MyFakePlug)`
- **VCR recording:** HTTP interactions will be recorded and replayed using a VCR library (see
  `testing_strategy.md`) for integration-level tests

---

## Consequences

**Dependencies added:**
- `{:google_api_analytics_data, "~> 0.17"}` — adds `google_gax` as a transitive dependency

**Dependencies NOT added:**
- No `goth` (service account auth not needed — OAuth bearer tokens used directly)
- No Facebook or QuickBooks client libraries (none are maintained)

**Follow-up actions:**
- Add `google_api_analytics_data` to `mix.exs`
- Add `google_ads_developer_token` to `config/runtime.exs` and secrets
- Add `quickbooks_env` config for sandbox/production switching
- Begin Google Ads developer token application process early (requires Google review)
- Update the Google Analytics provider module to use the official client library instead of raw Req
- Facebook long-lived token expiry (60 days) needs a future user notification mechanism

**Trade-offs accepted:**
- Mixed approach: official library for GA4, raw Req for the other three. This is pragmatic —
  use official libraries where they exist and are maintained, fall back to raw HTTP where they don't.
- Google Ads has no official Elixir package and none is planned. Raw REST is the only path.
- Each raw Req provider module is ~100-150 lines covering request construction, response parsing,
  and pagination.
