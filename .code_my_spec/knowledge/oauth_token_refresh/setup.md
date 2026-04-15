# OAuth Token Refresh in MetricFlow

This document is the primary reference for implementing and maintaining OAuth token refresh across all providers in MetricFlow. It covers the correct Assent API, provider-specific behavior, integration status tracking, error classification, and the two provider edge cases that require special handling (QuickBooks refresh token rotation and Facebook's non-refreshable tokens).

See `docs/architecture/decisions/oauth_token_refresh.md` for the decision record that selected the reactive refresh strategy and explains why proactive refresh was not adopted.

---

## The Correct Assent API

### What NOT to call

The existing `refresh_token/2` in `MetricFlow.Integrations` is incorrect. It calls `strategy.callback/2` with a `"grant_type"` param:

```elixir
# WRONG — callback/2 is the authorization-code exchange endpoint
case strategy.callback(config, %{"grant_type" => "refresh_token", "refresh_token" => integration.refresh_token}) do
```

`strategy.callback/2` (or `callback/3` depending on Assent version) handles the second leg of the authorization code flow — exchanging a short-lived code for tokens. Passing `grant_type: "refresh_token"` to it does not trigger an OAuth token refresh; it either errors or silently makes the wrong request.

### The correct function

```elixir
Assent.Strategy.OAuth2.refresh_access_token(config, token_map, params \\ [])
```

**Signature from Assent source:**

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

**Arguments:**

| Argument | Type | Description |
|---|---|---|
| `config` | `Keyword.t()` | The same config keyword list used for `authorize_url/1` and `callback/3` — produced by `provider_module.config()` |
| `token` | `map()` | A map with at least a `"refresh_token"` key. This is NOT the `Integration` struct — it is a plain map with string keys. |
| `params` | `Keyword.t()` | Optional extra params, rarely needed in MetricFlow |

**Return value:** `{:ok, new_token_map}` where `new_token_map` is a plain map with string keys: `"access_token"`, `"expires_in"`, and optionally a rotated `"refresh_token"`. Or `{:error, reason}` on failure.

### Important: call OAuth2 directly, not the provider strategy

`Assent.Strategy.Google` is built on `Assent.Strategy.OIDC.Base`, which delegates to `Assent.Strategy.OAuth2` for token operations internally — but `refresh_access_token/3` is NOT part of the `Assent.Strategy` behaviour and is NOT delegated by OIDC.Base. You must call `Assent.Strategy.OAuth2.refresh_access_token/3` directly regardless of which provider you are refreshing.

```elixir
# CORRECT — always use the OAuth2 module directly
Assent.Strategy.OAuth2.refresh_access_token(config, token_map)

# WRONG — Google's strategy module does not expose refresh_access_token
Assent.Strategy.Google.refresh_access_token(config, token_map)
```

---

## Corrected `refresh_token/2` Implementation

The `MetricFlow.Integrations.refresh_token/2` function needs to be rewritten. The corrected version:

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

Key points in this implementation:

- `integration.refresh_token` is already decrypted by CloakEcto when loaded from the database — pass it directly as a string.
- The token map uses string keys (`"refresh_token"`), not atom keys, because Assent's internal `fetch_from_token/2` expects string keys.
- `new_token["refresh_token"] || integration.refresh_token` handles providers that do NOT rotate the refresh token (Google, GitHub). For QuickBooks, see the special handling section below.
- `calculate_expires_at/1` already exists in `MetricFlow.Integrations` and handles the `"expires_in"` integer field correctly.

---

## Provider-Specific Token Behavior

### Google (Analytics, Ads)

- **Token lifetime:** Access tokens expire in 1 hour. Refresh tokens are long-lived and do not expire under normal circumstances.
- **Refresh token issued:** Only if the OAuth authorization request includes `access_type: "offline"` AND `prompt: "consent"`. Both are already set in `Providers.Google.config/0`.
- **Refresh token rotation:** Google does NOT rotate the refresh token. The same refresh token can be used indefinitely until it is manually revoked by the user or the app loses access.
- **Token endpoint:** `https://oauth2.googleapis.com/token` — standard OAuth2, works with `Assent.Strategy.OAuth2.refresh_access_token/3` without any special configuration.
- **`refresh_token` in response:** The response from Google's token endpoint does NOT include a `refresh_token` field when refreshing. The `|| integration.refresh_token` fallback in the corrected implementation handles this correctly — keep using the stored token.
- **Testing mode caveat:** Google Cloud Console apps in "Testing" mode issue refresh tokens that expire after 7 days. This will cause refresh failures in development if the OAuth app is not moved to production publishing before going live.

**Expected flow:**

```
Assent.Strategy.OAuth2.refresh_access_token(google_config, %{"refresh_token" => "1//..."})
# => {:ok, %{"access_token" => "ya29.new...", "expires_in" => 3599, "token_type" => "Bearer"}}
# Note: no "refresh_token" key in the response — keep the old one
```

### GitHub

- **Token lifetime:** GitHub tokens do NOT expire by default. Expiry is an opt-in feature in GitHub OAuth app settings.
- **MetricFlow handling:** `calculate_expires_at/1` falls through to the default clause for GitHub tokens (no `"expires_in"` in the OAuth response) and sets `expires_at` to 365 days from now. `Integration.expired?/1` will therefore return `false` for all GitHub integrations in normal operation.
- **Refresh flow:** No refresh is needed. The `SyncWorker` pre-flight check (`Integration.expired?/1` returns true → attempt refresh) will not trigger for GitHub integrations.
- **Action required:** None. GitHub integrations do not need a refresh code path.

### Facebook Ads

- **Token lifetime:** Facebook issues long-lived user tokens valid for 60 days. There is no standard `refresh_token` grant in the OAuth 2.0 sense.
- **Facebook's "refresh" mechanism:** Facebook uses a proprietary `fb_exchange_token` grant type — not a standard `refresh_token` grant. `Assent.Strategy.OAuth2.refresh_access_token/3` will fail because the stored token has no `"refresh_token"` key.
- **Silent extension:** Facebook can silently extend a token by 60 days if the user actively uses the app within the validity window, but this is not reliable for background sync scenarios.
- **MetricFlow strategy:** Treat Facebook tokens as non-refreshable. When the token is expired or within a 7-day warning window, set the integration status to `:requires_reauth` and notify the user. Do not attempt a programmatic refresh.

**Required provider module behavior:**

The planned `Providers.FacebookAds` module should return a distinct error so `SyncWorker` can handle Facebook without falling through to the generic refresh path:

```elixir
defmodule MetricFlow.Integrations.Providers.FacebookAds do
  @behaviour MetricFlow.Integrations.Providers.Behaviour

  # Returns a sentinel error before any Assent call is attempted.
  # SyncWorker pattern-matches on :not_refreshable to set requires_reauth
  # without treating it as a transient network error.
  def refresh_token(_integration), do: {:error, :not_refreshable}

  # ... config/0, strategy/0, normalize_user/1 as normal
end
```

**SyncWorker handling for Facebook:**

```elixir
case MetricFlow.Integrations.refresh_token(scope, integration) do
  {:ok, updated_integration} ->
    # proceed with sync
  {:error, :not_refreshable} ->
    # mark requires_reauth, notify user, do not retry
    mark_requires_reauth(integration)
    {:error, :requires_reauth}
  {:error, reason} ->
    classify_and_handle_error(reason, integration)
end
```

### QuickBooks Online

- **Token lifetime:** Access tokens expire in 1 hour. Refresh tokens are valid for 100 days on a rolling window — each successful refresh resets the 100-day clock.
- **Refresh token rotation:** QuickBooks ALWAYS rotates the refresh token on each successful refresh. The response includes a new `refresh_token` value. The old refresh token is immediately invalidated by Intuit's servers.
- **Consequence of losing the new token:** If the database write fails after a successful refresh API call, the old token stored in the database is now invalid and the new token is lost. The integration will require re-authorization by the user.

**QuickBooks-specific provider config (not yet implemented):**

The `@providers` map in `MetricFlow.Integrations` currently does not include a QuickBooks entry. The planned `Providers.QuickBooks` module must supply the correct Assent config for Intuit's token endpoint:

```elixir
defmodule MetricFlow.Integrations.Providers.QuickBooks do
  @behaviour MetricFlow.Integrations.Providers.Behaviour

  @impl true
  def config do
    [
      client_id: Application.fetch_env!(:metric_flow, :quickbooks_client_id),
      client_secret: Application.fetch_env!(:metric_flow, :quickbooks_client_secret),
      redirect_uri: build_redirect_uri(),
      base_url: "https://oauth.platform.intuit.com",
      token_url: "/op/v1/token",
      authorization_params: [
        scope: "com.intuit.quickbooks.accounting"
      ]
    ]
  end

  @impl true
  def strategy, do: Assent.Strategy.OAuth2

  # ...
end
```

**Handling refresh token rotation — do NOT use the fallback:**

The generic `refresh_token/2` implementation uses `new_token["refresh_token"] || integration.refresh_token` as a fallback. For QuickBooks this fallback is dangerous:

```elixir
# WRONG for QuickBooks — if new_token["refresh_token"] is nil, it means
# the refresh failed silently or the response is malformed. Falling back
# to the old token will cause all future refreshes to fail with 400 invalid_grant.
refresh_token: new_token["refresh_token"] || integration.refresh_token,
```

For QuickBooks, the presence of `"refresh_token"` in the response must be treated as required, not optional. A missing refresh token in the response indicates an error condition:

```elixir
# CORRECT for QuickBooks — treat missing refresh token as an error
case new_token do
  %{"refresh_token" => new_rt, "access_token" => new_at} ->
    attrs = %{
      access_token: new_at,
      refresh_token: new_rt,
      expires_at: calculate_expires_at(new_token)
    }
    IntegrationRepository.update_integration(scope, integration.provider, attrs)

  _ ->
    {:error, :missing_refresh_token_in_response}
end
```

**Transaction safety for QuickBooks:**

Because losing the new refresh token is unrecoverable, the refresh API call and the database write should be as close together as possible. Ideally, wrap the update in a transaction. If the DB write fails, the integration will need re-authorization — this is an accepted trade-off documented in the decision record.

---

## Integration Status Tracking

The `Integration` schema currently does NOT have a `status` field. A migration and schema update are required to track integration lifecycle state.

### Planned schema addition

```elixir
# In the Integration schema
field :status, Ecto.Enum, values: [:active, :expired, :requires_reauth], default: :active
```

### Status meanings

| Status | Meaning | Next action |
|---|---|---|
| `:active` | Token is valid or was successfully auto-refreshed | Normal sync |
| `:expired` | Token is past `expires_at` but a refresh token is available | `SyncWorker` will attempt `refresh_token/2` before syncing |
| `:requires_reauth` | Refresh failed or no refresh token is available; user action required | Show UI banner and send notification email; no sync attempted |

### Planned `mark_requires_reauth/2`

A targeted update function is needed in `IntegrationRepository` to avoid loading and re-saving a full changeset just to flip the status:

```elixir
def mark_requires_reauth(%Scope{user: user}, provider) do
  Integration
  |> where([i], i.user_id == ^user.id and i.provider == ^provider)
  |> Repo.update_all(set: [status: :requires_reauth, updated_at: DateTime.utc_now()])
end
```

### Current helper functions on `Integration`

These already exist and are used by `SyncWorker`:

```elixir
# Returns true if DateTime.utc_now() > integration.expires_at
Integration.expired?(integration)

# Returns false if refresh_token is nil, true otherwise
Integration.has_refresh_token?(integration)
```

---

## Error Classification

When `Assent.Strategy.OAuth2.refresh_access_token/3` returns an error, `SyncWorker` must distinguish errors that require user action from errors that should be retried by Oban.

### Error classification table

| Error from Assent | Meaning | Classification | Action |
|---|---|---|---|
| `{:error, "No \`refresh_token\` in token map"}` | No refresh token was stored at authorization time | Permanent | Mark `:requires_reauth`, notify user |
| `{:error, %Assent.InvalidResponseError{response: %{status: 400}}}` | Expired or revoked refresh token (`invalid_grant` from Google/Intuit) | Permanent | Mark `:requires_reauth`, notify user |
| `{:error, %Assent.InvalidResponseError{response: %{status: 401}}}` | Revoked credentials or scope change | Permanent | Mark `:requires_reauth`, notify user |
| `{:error, %Assent.RequestError{}}` | Network error, DNS failure, timeout | Transient | Allow Oban to retry |
| `{:error, %Assent.UnexpectedResponseError{}}` | Provider returned unexpected format | Transient (usually) | Allow Oban to retry; log for monitoring |
| `{:error, :not_refreshable}` | Facebook Ads (no standard refresh flow) | Permanent | Mark `:requires_reauth`, notify user |

### HTTP 400 from Google is a permanent failure

Google's token endpoint returns HTTP 400 (not 401) for expired or revoked refresh tokens. The response body contains `"error": "invalid_grant"`. This is a common source of confusion — 400 from Google's `/token` endpoint means the refresh token is bad, not that the request was malformed. Treat it as permanent.

### Pattern matching for classification

```elixir
defp classify_refresh_error({:error, "No `refresh_token`" <> _}), do: :requires_reauth
defp classify_refresh_error({:error, %Assent.InvalidResponseError{response: %{status: s}}})
     when s in [400, 401], do: :requires_reauth
defp classify_refresh_error({:error, :not_refreshable}), do: :requires_reauth
defp classify_refresh_error({:error, %Assent.RequestError{}}), do: :transient
defp classify_refresh_error({:error, %Assent.UnexpectedResponseError{}}), do: :transient
defp classify_refresh_error(_), do: :transient  # default: retry unknown errors
```

---

## SyncWorker Refresh Flow (Reactive Strategy)

MetricFlow uses reactive refresh — tokens are refreshed on-demand inside `SyncWorker` when a token is found to be expired. The `SyncWorker` spec (steps 5-7) defines this flow:

```
5. Check if tokens are expired using Integration.expired?/1
6. If expired and has_refresh_token?/1 returns true, attempt token refresh via MetricFlow.Integrations.refresh_token/2
7. Return error :token_expired if expired and no refresh token available
```

A complete implementation sketch:

```elixir
defp maybe_refresh_token(scope, integration) do
  cond do
    not Integration.expired?(integration) ->
      {:ok, integration}

    Integration.has_refresh_token?(integration) ->
      case MetricFlow.Integrations.refresh_token(scope, integration) do
        {:ok, refreshed} ->
          {:ok, refreshed}

        {:error, :not_refreshable} ->
          mark_requires_reauth(scope, integration)
          {:error, :requires_reauth}

        {:error, reason} ->
          case classify_refresh_error({:error, reason}) do
            :requires_reauth ->
              mark_requires_reauth(scope, integration)
              {:error, :requires_reauth}

            :transient ->
              {:error, reason}  # Oban will retry
          end
      end

    true ->
      {:error, :token_expired}  # no refresh token available
  end
end
```

---

## Follow-Up Actions Required

These are the concrete implementation tasks identified in the decision record:

1. Fix `Integrations.refresh_token/2` to call `Assent.Strategy.OAuth2.refresh_access_token/3` instead of `strategy.callback/2`. The current implementation in `lib/metric_flow/integrations.ex` line 171 is incorrect.

2. Add a `status` field to the `Integration` schema and create a migration. Default is `:active`.

3. Add `IntegrationRepository.mark_requires_reauth/2` for updating status without a full changeset load.

4. Add `Providers.QuickBooks` module with the correct Assent config (`base_url: "https://oauth.platform.intuit.com"`, `token_url: "/op/v1/token"`). Register it in the `@providers` map in `MetricFlow.Integrations`.

5. Add `Providers.FacebookAds` module that returns `{:error, :not_refreshable}` from a provider-level refresh callback so `SyncWorker` can distinguish it from a generic Assent failure.

6. Update `SyncWorker` error handling to distinguish retryable (transient) errors from permanent re-auth errors when `refresh_token/2` fails.

7. Add a database lock or optimistic concurrency check to `update_integration/3` in `IntegrationRepository` to prevent concurrent refresh writes on the same integration — especially important for QuickBooks where the old refresh token is invalidated immediately on successful refresh.

---

## Related Files

- Decision record: `docs/architecture/decisions/oauth_token_refresh.md`
- Current (buggy) implementation: `lib/metric_flow/integrations.ex` — `refresh_token/2` at line 166
- Repository layer: `lib/metric_flow/integrations/integration_repository.ex` — `update_integration/3`
- Integration schema and helpers: `lib/metric_flow/integrations/integration.ex` — `expired?/1`, `has_refresh_token?/1`
- Google provider config: `lib/metric_flow/integrations/providers/google.ex` — `config/0`
- SyncWorker spec: `docs/spec/metric_flow/data_sync/sync_worker.spec.md`
- Data provider specs: `docs/spec/metric_flow/data_sync/data_providers/`
