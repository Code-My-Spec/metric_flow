# OAuth Token Refresh Strategy

**Status:** Proposed
**Date:** 2026-02-21

## Context

MetricFlow syncs data from four external providers — Google Analytics, Google Ads, Facebook Ads,
and QuickBooks — all of which use OAuth 2.0 access tokens stored encrypted in the `Integration`
schema. Access tokens for Google and QuickBooks expire in one hour. Facebook tokens last 60 days
but have no standard refresh mechanism. GitHub tokens do not expire.

The "Handle Expired or Invalid OAuth Credentials" story requires:
- Detecting expiration before or during a sync
- Automatically refreshing access tokens using stored refresh tokens
- Gracefully degrading when refresh fails (revoked access, changed scopes)
- Notifying users when re-authorization is required
- Tracking integration status (active, expired, needs re-auth)

The project already has all necessary infrastructure in place: Assent (~> 0.2) for OAuth flows,
CloakEcto for encrypted token storage, Oban (~> 2.2) for background jobs, and `Integration.expired?/1`
plus `Integration.has_refresh_token?/1` helpers on the schema.

A `refresh_token/2` function exists in `MetricFlow.Integrations` but its implementation is
incorrect — it calls `strategy.callback/2` with fake params including `grant_type`, which is
the authorization-code exchange endpoint, not the token refresh endpoint.

The `data_provider_apis.md` decision documents the high-level token refresh policy (reactive
on 401, pre-flight expiry check, Facebook exception). This record specifies the Assent API,
the correct implementation pattern, and the choice between proactive and reactive refresh.

---

## Options Considered

### Option A: Reactive Refresh (Repair on Failure)

Refresh tokens only when an expired or unauthorized error is encountered during a sync job.
The `SyncWorker` checks `Integration.expired?/1` before calling a provider. If expired and a
refresh token is available, it calls `Integrations.refresh_token/2` and retries the fetch.
A 401 from the provider API during the fetch also triggers the same refresh-and-retry path.

**Pros:**
- Simple control flow — refresh happens in one place (SyncWorker)
- No extra scheduled jobs or queries needed
- Tokens are only refreshed when they are actually needed

**Cons:**
- The first sync attempt after expiry always fails before refreshing, adding latency to the job
- If refresh fails mid-job, the SyncJob status must be updated to `requires_reauth` with an
  informative error — adds error-path complexity
- A failed pre-flight check still counts as a job execution against Oban's retry budget

### Option B: Proactive Refresh (Refresh Before Expiry)

An Oban cron job (`TokenRefreshWorker`) runs periodically (e.g., every 45 minutes) and
refreshes tokens for all integrations where `expires_at` is within a buffer window of the
current time (e.g., 10 minutes). SyncWorker still performs a pre-flight check as a defensive
fallback but should rarely trigger because tokens are kept fresh.

**Pros:**
- Sync jobs always have a valid token at the start — no per-job refresh latency
- Refresh failures are discovered independently of sync jobs, enabling user notification
  without blocking or failing a sync
- Better separation: token lifecycle management is decoupled from data fetching

**Cons:**
- An additional Oban worker and Oban queue configuration is required
- Tokens can still expire between the proactive refresh and the sync execution (e.g., if the
  refresh job misses a window), so SyncWorker still needs the defensive check
- Slightly more infrastructure complexity for a relatively small latency benefit

### Option C: Hybrid — Proactive Refresh as Primary, Reactive as Fallback

Run a proactive `TokenRefreshWorker` that keeps tokens fresh. SyncWorker retains its pre-flight
expiry check as a fallback but does not implement its own refresh — it returns
`{:error, :token_expired}` if the token is still expired at job execution time, causing Oban
to reschedule the job (which gives the refresh worker time to catch up).

**Pros:**
- Combines the latency benefit of proactive refresh with defense-in-depth from the reactive check
- Clear responsibility boundaries: refresh worker owns token lifecycle, sync worker owns sync

**Cons:**
- Two workers to maintain
- Oban retry reschedule adds delay if the proactive refresh has not yet run

---

## Decision

**Use reactive refresh (Option A) as the implementation strategy.**

The reactive approach is chosen because:

1. **The sync cadence is daily.** The `Scheduler` spec documents that syncs run once per day. A
   one-time refresh latency at the start of a daily job is not user-visible in a meaningful way.
   The latency benefit of proactive refresh is most valuable in interactive or high-frequency
   contexts, which MetricFlow does not have.

2. **The infrastructure is already specified.** The `SyncWorker` spec (step 5–7) already calls
   for exactly this pattern: check `expired?`, call `refresh_token/2` if a refresh token is
   available, return `:token_expired` if not. No new worker is needed.

3. **Facebook tokens do not fit a proactive model.** Facebook's long-lived tokens cannot be
   refreshed programmatically via a standard OAuth refresh flow. A proactive refresh worker
   would need a special code path for Facebook anyway, making it more complex without benefit
   for that provider.

4. **Complexity should be deferred.** A proactive worker can be added later if sync latency
   becomes a problem or if near-real-time sync is added. For now, reactive is sufficient.

### Correct Assent API for Refresh

The existing `refresh_token/2` implementation in `MetricFlow.Integrations` calls
`strategy.callback/2`, which is the authorization-code exchange endpoint and is incorrect for
token refresh. The correct function is `Assent.Strategy.OAuth2.refresh_access_token/3`.

**Function signature (from Assent source):**

```elixir
@spec refresh_access_token(Keyword.t(), map(), Keyword.t()) :: {:ok, map()} | {:error, term()}
def refresh_access_token(config, token, params \\ []) do
  with {:ok, refresh_token} <- fetch_from_token(token, "refresh_token") do
    grant_access_token(
      config,
      "refresh_token",
      Keyword.put(params, :refresh_token, refresh_token)
    )
  end
end
```

It expects:
- `config` — the same provider config keyword list used for `authorize_url/1` and `callback/3`
- `token` — a map with at least a `"refresh_token"` key (the raw unencrypted string)
- `params` — optional extra params (rarely needed)

It returns `{:ok, new_token_map}` where `new_token_map` includes `"access_token"`,
`"expires_in"`, and possibly a rotated `"refresh_token"`.

**Corrected `refresh_token/2` implementation:**

```elixir
def refresh_token(%Scope{} = scope, %Integration{} = integration) do
  with {:ok, provider_module} <- get_provider_module(integration.provider),
       config <- provider_module.config(),
       token_map = %{"refresh_token" => integration.refresh_token},
       {:ok, new_token} <- Assent.Strategy.OAuth2.refresh_access_token(config, token_map) do
    attrs = %{
      access_token: new_token["access_token"],
      refresh_token: new_token["refresh_token"] || integration.refresh_token,
      expires_at: calculate_expires_at(new_token)
    }

    IntegrationRepository.update_integration(scope, integration.provider, attrs)
  end
end
```

Note: `Assent.Strategy.Google` uses `Assent.Strategy.OIDC.Base` which delegates to
`Assent.Strategy.OAuth2` for token operations. `refresh_access_token/3` must be called
directly on `Assent.Strategy.OAuth2`, not on the provider strategy module, since `refresh_access_token`
is not part of the `Assent.Strategy` behaviour and is not delegated by OIDC.Base.

### Provider-Specific Behavior

**Google (Analytics, Ads):**
- Access tokens expire in 1 hour. Refresh tokens are long-lived.
- Requires `access_type: "offline"` and `prompt: "consent"` at authorization time to receive a
  refresh token. Both are already set in `Providers.Google.config/0`.
- `Assent.Strategy.OAuth2.refresh_access_token/3` works directly — Google's token endpoint
  (`https://oauth2.googleapis.com/token`) is standard.
- Google does not rotate the refresh token on each use; the existing refresh token can be
  reused indefinitely until revoked.
- Note: apps in "Testing" mode in Google Cloud Console receive refresh tokens that expire after
  7 days. Move to production publishing before launch.

**Facebook Ads:**
- Facebook issues long-lived user tokens valid for 60 days. There is no standard
  `refresh_token` grant. Tokens must be exchanged using a provider-specific
  `fb_exchange_token` grant — this is not supported by Assent's OAuth2 strategy.
- Facebook tokens can also be silently extended by 60 days if the user actively uses the app
  within the validity window, but this is not reliable for background sync.
- Strategy: treat Facebook tokens as non-refreshable. When expired or within a 7-day warning
  window, set integration status to `requires_reauth` and notify the user via email/UI banner.
  Do not attempt a programmatic refresh.

**QuickBooks Online:**
- Access tokens expire in 1 hour. Refresh tokens are valid for 100 days (rolling).
- QuickBooks **rotates the refresh token** on each successful refresh — the response includes a
  new `refresh_token` value. The old refresh token is immediately invalidated.
- The `refresh_token` field in the response must always be persisted, even if nil-checking
  with `|| integration.refresh_token` as a fallback. A missing refresh token in the response
  is an error condition, not a case for falling back to the old token.
- `Assent.Strategy.OAuth2.refresh_access_token/3` works with QuickBooks' standard token
  endpoint, but a QuickBooks provider module must be added with the correct `base_url`
  (`https://oauth.platform.intuit.com`) and `token_url` (`/op/v1/token`).

**GitHub:**
- GitHub tokens do not expire unless the OAuth app is configured with token expiration (opt-in
  feature). The `expires_at` fallback in `calculate_expires_at/1` sets a 365-day expiry, which
  is appropriate.
- No refresh action is needed for GitHub integrations in normal operation.

### Integration Status Tracking

The `Integration` schema does not currently have a `status` field. The "Handle Expired or
Invalid OAuth Credentials" story requires tracking whether an integration needs re-authorization.
A `status` field should be added to the `Integration` schema as a follow-up:

```elixir
field :status, Ecto.Enum, values: [:active, :expired, :requires_reauth], default: :active
```

- `active` — token is valid or auto-refreshable
- `expired` — token is expired but a refresh token is available (refresh will be attempted)
- `requires_reauth` — refresh failed or no refresh token available; user action required

### Error Classification

When `refresh_token/2` returns an error, the SyncWorker must classify it to decide whether to
retry or require user action:

| Error returned by Assent           | Meaning                            | Action                          |
|------------------------------------|------------------------------------|---------------------------------|
| `{:error, "No \`refresh_token\`..."}` | No refresh token stored         | Mark `requires_reauth`, notify  |
| `{:error, %InvalidResponseError{response: %{status: 400}}}` | Invalid/expired refresh token | Mark `requires_reauth`, notify  |
| `{:error, %InvalidResponseError{response: %{status: 401}}}` | Revoked credentials           | Mark `requires_reauth`, notify  |
| `{:error, %RequestError{}}` or `{:error, %UnexpectedResponseError{}}` | Network or provider error | Oban retry (transient) |

Errors with HTTP 400 from Google's token endpoint indicate an expired or revoked refresh token
(`invalid_grant` error code in the response body). These must be treated as permanent failures
requiring re-authorization, not transient errors to be retried.

---

## Consequences

**Trade-offs accepted:**
- Reactive refresh means the first sync after token expiry incurs a refresh round-trip before
  fetching data. For a daily batch sync this is acceptable overhead.
- Facebook tokens require out-of-band user action to renew. The system must surface this clearly
  in the UI (integration status banner) and via email notification — this is deferred to the
  notification story.
- QuickBooks refresh token rotation means a failed write after a successful refresh (e.g., DB
  crash) would permanently invalidate the token. The update operation should be wrapped in a
  database transaction with the refresh call treated as idempotent where possible.

**Follow-up actions required:**
1. Fix `Integrations.refresh_token/2` to call `Assent.Strategy.OAuth2.refresh_access_token/3`
   instead of `strategy.callback/2`.
2. Add a `status` field to the `Integration` schema (migration required).
3. Add `IntegrationRepository.mark_requires_reauth/2` for updating status without a full
   changeset.
4. Add a QuickBooks provider module (`Providers.QuickBooks`) with the correct Assent config so
   `refresh_token/2` can look it up via `@providers`.
5. Add a Facebook Ads provider module (`Providers.FacebookAds`) that returns
   `{:error, :not_refreshable}` from a `refresh_token/1` callback so the SyncWorker can handle
   it distinctly.
6. Update `SyncWorker` error handling to distinguish retryable network errors from permanent
   re-auth errors when `refresh_token/2` fails.
7. Ensure `update_integration/3` in `IntegrationRepository` uses a database lock (e.g.,
   `select_for_update` or optimistic concurrency) to prevent concurrent refresh writes on
   the same integration.

**Related decisions:**
- `data_provider_apis.md` — documents the high-level refresh policy and per-provider HTTP behavior
- `docs/spec/metric_flow/data_sync/sync_worker.spec.md` — specifies the SyncWorker refresh steps
