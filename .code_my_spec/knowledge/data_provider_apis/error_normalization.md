# Error Normalization

All four data provider modules normalize errors to atoms before returning from
`fetch_metrics/2`. This allows the `SyncWorker` to handle errors uniformly without
knowing provider-specific HTTP status codes or error body formats.

---

## Normalization Table

| HTTP Status / API Signal                   | Returned Atom               | Notes                                                    |
|--------------------------------------------|-----------------------------|----------------------------------------------------------|
| Token expired before request (pre-flight)  | `:token_expired`            | Checked via `Integration.expired?/1`, no HTTP call made  |
| 401 Unauthorized                           | `:unauthorized`             | All providers                                            |
| 403 Forbidden                              | `:insufficient_permissions` | All providers                                            |
| 404 Not Found                              | `:resource_not_found`       | All providers                                            |
| 429 Too Many Requests                      | `:rate_limited`             | All providers; Req retries before this is returned       |
| Network error / timeout / Req exception    | `:network_error`            | All providers; also returned after Req exhausts retries  |
| Malformed response / unexpected JSON shape | `:parse_error`              | All providers; raised by a failed pattern match or Jason |
| Facebook error code 190 in body            | `:token_expired`            | Facebook Ads only; 190 = invalid/expired OAuth token     |
| Google Ads `RESOURCE_EXHAUSTED` status     | `:rate_limited`             | Google Ads only; in response body not HTTP status        |
| Missing provider config (no ID)            | `:missing_{config_key}`     | All providers; see below                                 |

### Missing Config Key Atoms

| Provider         | Missing Config Error          |
|------------------|-------------------------------|
| Google Analytics | `:missing_property_id`        |
| Google Ads       | `:missing_customer_id`        |
| Facebook Ads     | `:missing_ad_account_id`      |
| QuickBooks       | `:missing_realm_id`           |

---

## How SyncWorker Uses These Atoms

```elixir
case provider.fetch_metrics(integration, opts) do
  {:ok, metrics} ->
    persist_and_complete(metrics, sync_job)

  {:error, :token_expired} ->
    attempt_token_refresh_and_retry(integration, sync_job)

  {:error, :unauthorized} ->
    attempt_token_refresh_and_retry(integration, sync_job)

  {:error, :rate_limited} ->
    # Oban will snooze/retry this job
    {:error, :rate_limited}

  {:error, reason} ->
    fail_sync_job(sync_job, inspect(reason))
end
```

The `:token_expired` and `:unauthorized` atoms both trigger a token refresh attempt.
The distinction matters for logging (`:token_expired` means the pre-flight check caught
it; `:unauthorized` means the API returned 401 despite a non-expired token).

---

## Pre-flight Token Check

Every provider begins `fetch_metrics/2` with an expiry check before making any HTTP
requests. The check uses a 5-minute buffer so tokens that would expire mid-request are
refreshed proactively:

```elixir
defp token_valid?(%Integration{expires_at: expires_at}) do
  buffer = DateTime.add(DateTime.utc_now(), 5 * 60, :second)
  DateTime.compare(buffer, expires_at) == :lt
end
```

Or using the existing `Integration.expired?/1` helper (which does not include the buffer):

```elixir
def fetch_metrics(%Integration{} = integration, opts) do
  with false <- Integration.expired?(integration) do
    # ... proceed
  else
    true -> {:error, :token_expired}
  end
end
```

If a tighter buffer is needed, add a separate `expiring_soon?/1` function to the
`Integration` module rather than adding buffer logic inside each provider.

---

## Google Analytics Error Shape

The `google_api_analytics_data` library returns Tesla errors, not Req errors.
Map them in the provider before returning:

```elixir
defp normalize_ga4_error(error) do
  case error do
    %Tesla.Env{status: 401} -> {:error, :unauthorized}
    %Tesla.Env{status: 403} -> {:error, :insufficient_permissions}
    %Tesla.Env{status: 404} -> {:error, :resource_not_found}
    %Tesla.Env{status: 429} -> {:error, :rate_limited}
    _other -> {:error, :network_error}
  end
end
```

Call this in the error arm of the pattern match on the library result:

```elixir
case Properties.analyticsdata_properties_run_report(connection, property_path, body: request) do
  {:ok, response} -> parse_ga4_response(response)
  {:error, error} -> normalize_ga4_error(error)
end
```

---

## Facebook: Error Code 190

Facebook embeds OAuth errors in the response body rather than using HTTP 401. Error
code 190 specifically means the token is invalid or expired. It appears as:

```json
{
  "error": {
    "message": "Invalid OAuth access token.",
    "type": "OAuthException",
    "code": 190,
    "fbtrace_id": "..."
  }
}
```

This should be matched before the general error fallback:

```elixir
case Req.get(req, url: url, params: params) do
  {:ok, %{status: 200, body: body}} ->
    {:ok, body}

  {:ok, %{body: %{"error" => %{"code" => 190}}}} ->
    {:error, :token_expired}

  {:ok, %{status: 401}} ->
    {:error, :unauthorized}

  # ... other cases
end
```

---

## Google Ads: RESOURCE_EXHAUSTED

The Google Ads API can return 429 as HTTP status, but rate limit errors also appear as
a 200 response with an error body containing `"status": "RESOURCE_EXHAUSTED"`.
Handle both forms:

```elixir
case Req.post(req, url: url, json: %{query: gaql}) do
  {:ok, %{status: 200, body: body}} when is_list(body) ->
    {:ok, body}

  {:ok, %{status: 200, body: %{"error" => %{"status" => "RESOURCE_EXHAUSTED"}}}} ->
    {:error, :rate_limited}

  {:ok, %{status: 429}} ->
    {:error, :rate_limited}

  # ... other cases
end
```

---

## Parse Errors

JSON parsing happens automatically via Req (when `Content-Type` is `application/json`).
If the response body arrives as an unexpected shape (e.g., an empty string, non-JSON body,
or a map missing expected keys), the parse error typically surfaces as a `MatchError` or
a `KeyError` inside the response parsing functions.

Wrap the parsing step to convert these to `:parse_error`:

```elixir
defp safe_parse(body, parser_fn) do
  try do
    {:ok, parser_fn.(body)}
  rescue
    _ -> {:error, :parse_error}
  end
end
```

Or use pattern matching with a fallback:

```elixir
defp parse_response(%{"rows" => rows} = body, property_id) do
  # ... normal path
end

defp parse_response(_unexpected, _), do: {:error, :parse_error}
```
