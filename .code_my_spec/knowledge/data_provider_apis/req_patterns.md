# Req Configuration Patterns for Data Providers

Reference for how `Req ~> 0.5` is configured across the three raw-HTTP providers
(Google Ads, Facebook Ads, QuickBooks). The decision record at
`docs/architecture/decisions/data_provider_apis.md` established these patterns.

---

## Base Configuration Pattern

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

### Option Breakdown

**`auth: {:bearer, access_token}`**

Adds `Authorization: Bearer {access_token}` to every request made with this Req struct.
Use this for Google Ads and QuickBooks. Do not use it for Facebook Ads — Facebook expects
the token as a query parameter, not a header.

**`retry: :safe_transient`**

Req's built-in retry policy. Retries automatically on:
- Network errors (connection refused, DNS failure, etc.)
- HTTP 408, 429, 500, 502, 503, 504 responses

Does NOT retry on:
- 4xx responses (except 408 and 429) — these are not transient (a 401 will still be 401)
- Successful responses (2xx, 3xx)

This is the correct policy for provider API calls. A 401 or 403 should propagate
immediately without burning retries.

**`max_retries: 3`**

Three retry attempts after the initial request, for a total of up to four attempts.

**`retry_delay: fn n -> trunc(Integer.pow(2, n) * 1_000) end`**

Exponential backoff in milliseconds:
- After 1st failure: 1,000ms (1s)
- After 2nd failure: 2,000ms (2s)
- After 3rd failure: 4,000ms (4s)

`n` is 1-based in Req's retry callback. `Integer.pow(2, 1) = 2`, but `Integer.pow(2, 0) = 1`
for the first call... confirm behavior in your Elixir version. `trunc/1` ensures an integer
is returned as required by the option.

**`receive_timeout: 30_000`**

Milliseconds to wait for the response body after the connection is established. External
provider APIs can be slow, especially on large datasets. 30 seconds is a reasonable ceiling.
Oban's job timeout is separate and should be set higher (e.g. 5 minutes per job).

---

## Provider-Specific Variations

### Google Ads: Adding the Developer Token Header

```elixir
defp build_req(access_token) do
  developer_token = Application.fetch_env!(:metric_flow, :google_ads_developer_token)

  Req.new(
    auth: {:bearer, access_token},
    headers: [{"developer-token", developer_token}],   # <-- added
    retry: :safe_transient,
    max_retries: 3,
    retry_delay: fn n -> trunc(Integer.pow(2, n) * 1_000) end,
    receive_timeout: 30_000
  )
end
```

The `developer-token` header is app-level (not per-user). It is fetched from config, not
from the integration. All Google Ads requests from the application use the same token.

### Facebook Ads: Token as Query Parameter

For Facebook, do not use `auth:` on `Req.new/1`. The access token travels in `params:`
on each request:

```elixir
defp build_req do
  Req.new(
    # No auth: here
    retry: :safe_transient,
    max_retries: 3,
    retry_delay: fn n -> trunc(Integer.pow(2, n) * 1_000) end,
    receive_timeout: 30_000
  )
end

defp fetch_page(req, url, access_token, other_params) do
  Req.get(req, url: url, params: [{:access_token, access_token} | other_params])
end
```

### QuickBooks: Accept: application/json Header

```elixir
defp build_req(access_token) do
  Req.new(
    auth: {:bearer, access_token},
    headers: [{"Accept", "application/json"}],         # <-- added
    retry: :safe_transient,
    max_retries: 3,
    retry_delay: fn n -> trunc(Integer.pow(2, n) * 1_000) end,
    receive_timeout: 30_000
  )
end
```

Without `Accept: application/json`, QuickBooks returns XML. The `headers:` option on
`Req.new/1` sets base headers included in every request made from that struct.

---

## Test Injection

The standard pattern for injecting a fake Req in tests. Each provider's `fetch_metrics/2`
accepts an optional `:req` keyword argument:

```elixir
def fetch_metrics(%Integration{} = integration, opts) do
  req = Keyword.get(opts, :req, build_req(integration.access_token))
  # ... rest of implementation uses req
end
```

In tests, pass a `Req` struct with a plug that intercepts the request:

```elixir
defmodule FakeGoogleAdsPlug do
  def init(opts), do: opts

  def call(conn, _opts) do
    Req.Test.json(conn, %{
      "results" => [
        %{
          "campaign" => %{"id" => "1", "name" => "Test Campaign"},
          "segments" => %{"date" => "2025-01-15"},
          "metrics" => %{
            "impressions" => "1000",
            "clicks" => "50",
            "costMicros" => "25000000",
            "conversions" => "5.0",
            "ctr" => "0.05",
            "averageCpc" => "500000"
          }
        }
      ]
    })
  end
end

# In the test
fake_req = Req.new(plug: FakeGoogleAdsPlug)
integration = build_integration(:google_ads)

assert {:ok, metrics} = GoogleAds.fetch_metrics(integration, req: fake_req, customer_id: "123")
assert length(metrics) == 6  # 6 metric types per row
```

For simpler cases, use `Req.Test.stub/2` directly:

```elixir
test "returns metrics on success" do
  Req.Test.stub(:test_adapter, fn conn ->
    Req.Test.json(conn, quickbooks_profit_and_loss_fixture())
  end)

  req = Req.new(plug: :test_adapter)
  assert {:ok, metrics} = QuickBooks.fetch_metrics(integration, req: req, realm_id: "123")
end
```

---

## Error Handling Shape

All three raw-Req providers follow the same case statement shape for handling the
`Req.get/2` or `Req.post/2` return value:

```elixir
case Req.post(req, url: url, json: body) do
  {:ok, %{status: 200, body: body}} ->
    {:ok, body}

  {:ok, %{status: 401}} ->
    {:error, :unauthorized}

  {:ok, %{status: 403}} ->
    {:error, :insufficient_permissions}

  {:ok, %{status: 404}} ->
    {:error, :resource_not_found}

  {:ok, %{status: 429}} ->
    {:error, :rate_limited}

  {:ok, _other} ->
    {:error, :network_error}

  {:error, _exception} ->
    # Network failure, timeout, DNS error, etc.
    {:error, :network_error}
end
```

Note: Req's `:safe_transient` retry policy means that by the time the 429 clause is
reached, Req has already retried up to `max_retries` times. The 429 atom is returned
only if all retries are exhausted.

Req decodes JSON response bodies automatically (when `Content-Type: application/json`
is present). The `body` in a successful match is already a parsed Elixir map or list —
not a raw string.

---

## Req vs Tesla

The `google_api_analytics_data` library uses Tesla internally (via `google_gax`).
This means the GA4 provider's error handling uses `%Tesla.Env{}` structs, not Req
response maps. This is an intentional inconsistency — the GA4 provider is the only one
using the Google library, and the error shape is normalized to the same atoms before
returning from `fetch_metrics/2`.

Do not use Req for GA4 calls. Do not use Tesla for Google Ads, Facebook, or QuickBooks.
