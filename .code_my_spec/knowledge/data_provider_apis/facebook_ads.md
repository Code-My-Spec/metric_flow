# Facebook Ads Marketing API

Reference for the `MetricFlow.DataSync.DataProviders.FacebookAds` module.

No maintained Elixir library exists for the Facebook Marketing API — see
`docs/architecture/decisions/data_provider_apis.md` for the reasoning. The API is
handled with raw Req.

---

## API Version and Base URL

The decision record targets v20.0:

```
https://graph.facebook.com/v20.0/
```

Facebook versioning is date-based. v20.0 was released in 2024 and has at least a 2-year
support window. Upgrades are non-breaking for fields used here.

---

## Ad Insights Endpoint

```
GET https://graph.facebook.com/v20.0/act_{ad_account_id}/insights
```

The `act_` prefix is required in the path. If the stored value in
`provider_metadata["ad_account_id"]` already includes `act_`, do not double-prepend.

```elixir
defp normalize_account_id("act_" <> _ = id), do: id
defp normalize_account_id(id), do: "act_#{id}"
```

---

## Authentication

Facebook's standard pattern sends the `access_token` as a **query parameter**, not as
an `Authorization` header. Do not use `auth: {:bearer, ...}` in `Req.new/1` for Facebook.

```elixir
defp build_req do
  Req.new(
    retry: :safe_transient,
    max_retries: 3,
    retry_delay: fn n -> trunc(Integer.pow(2, n) * 1_000) end,
    receive_timeout: 30_000
  )
end
```

The token is included in the `params` list on each individual request:

```elixir
Req.get(req, url: url, params: [access_token: access_token, ...other params...])
```

---

## Request Parameters

| Parameter      | Description                                          | Example Value                         |
|----------------|------------------------------------------------------|---------------------------------------|
| `access_token` | User access token (query param)                      | `"EAAB..."`                           |
| `fields`       | Comma-separated fields to return                     | `"impressions,clicks,spend,cpm,cpc,ctr,actions,date_start,campaign_name"` |
| `time_range`   | JSON-encoded object with `since` and `until` dates   | `{"since":"2025-01-01","until":"2025-01-31"}` |
| `level`        | Aggregation level                                    | `"campaign"` or `"adset"` or `"ad"`  |
| `limit`        | Results per page                                     | `100`                                 |
| `after`        | Cursor for pagination (subsequent pages only)        | `"AQDZ..."` from previous response   |

### Building the Request

```elixir
defp build_params(access_token, start_date, end_date, after_cursor) do
  base = [
    access_token: access_token,
    fields: "campaign_name,impressions,clicks,spend,cpm,cpc,ctr,actions,date_start",
    time_range: Jason.encode!(%{since: start_date, until: end_date}),
    level: "campaign",
    limit: 100
  ]

  if after_cursor, do: Keyword.put(base, :after, after_cursor), else: base
end
```

---

## Cursor Pagination

The Facebook Ads API uses cursor-based pagination. Check for a `paging.next` field in
the response. If it is present and non-empty, there are more pages.

```elixir
defp fetch_all_pages(req, account_id, access_token, start_date, end_date) do
  fetch_pages(req, account_id, access_token, start_date, end_date, nil, [])
end

defp fetch_pages(req, account_id, access_token, start_date, end_date, cursor, acc) do
  url = "https://graph.facebook.com/v20.0/#{normalize_account_id(account_id)}/insights"
  params = build_params(access_token, start_date, end_date, cursor)

  case Req.get(req, url: url, params: params) do
    {:ok, %{status: 200, body: %{"data" => data} = body}} ->
      next_cursor =
        case body do
          %{"paging" => %{"cursors" => %{"after" => c}, "next" => next}}
          when is_binary(next) and next != "" -> c
          _ -> nil
        end

      if next_cursor do
        fetch_pages(req, account_id, access_token, start_date, end_date, next_cursor, acc ++ data)
      else
        {:ok, acc ++ data}
      end

    {:ok, %{status: 401}} -> {:error, :unauthorized}
    {:ok, %{status: 403}} -> {:error, :insufficient_permissions}
    {:ok, %{status: 429}} -> {:error, :rate_limited}
    {:ok, %{body: %{"error" => %{"code" => 190}}}} -> {:error, :token_expired}
    {:ok, _} -> {:error, :network_error}
    {:error, _} -> {:error, :network_error}
  end
end
```

---

## Token Lifecycle

Facebook issues two types of tokens:

| Type            | Lifetime  | Refresh Mechanism                             |
|-----------------|-----------|-----------------------------------------------|
| Short-lived     | 1–2 hours | Exchange for long-lived using app credentials |
| Long-lived      | 60 days   | No standard programmatic refresh              |

MetricFlow stores long-lived tokens. When a long-lived token expires or returns error
code 190, the provider returns `{:error, :token_expired}`. The `SyncWorker` marks the
sync job as `requires_reauth`. A future notification mechanism will prompt the user
to reconnect.

Do not attempt token refresh for Facebook tokens in `MetricFlow.Integrations.refresh_token/2`.
The context-level refresh logic should check `has_refresh_token?/1` — Facebook integrations
will not have a `refresh_token`.

---

## Rate Limit Headers

Facebook surfaces rate limit state in response headers rather than always returning 429.
Two headers are relevant:

- `X-App-Usage` — app-level rate limit (JSON string)
- `X-Ad-Account-Usage` — per-account rate limit (JSON string)

Parse and log these for observability. Do not gate requests on them — let Req's
`:safe_transient` retry handle actual 429 responses:

```elixir
defp log_rate_limit_state(response_headers) do
  headers = Map.new(response_headers)

  if app_usage = headers["x-app-usage"] do
    Logger.debug("Facebook app usage: #{app_usage}")
  end

  if account_usage = headers["x-ad-account-usage"] do
    Logger.debug("Facebook ad account usage: #{account_usage}")
  end
end
```

---

## Response Structure

```json
{
  "data": [
    {
      "campaign_name": "Brand Awareness Q1",
      "impressions": "50000",
      "clicks": "1200",
      "spend": "450.50",
      "cpm": "9.01",
      "cpc": "0.38",
      "ctr": "2.4",
      "date_start": "2025-01-15",
      "actions": [
        {"action_type": "link_click", "value": "1200"},
        {"action_type": "purchase", "value": "23"}
      ]
    }
  ],
  "paging": {
    "cursors": {
      "before": "MQZDZD",
      "after": "AQDZ"
    },
    "next": "https://graph.facebook.com/..."
  }
}
```

Key points:
- All numeric values arrive as strings.
- `ctr` is a percentage (0–100), not a ratio.
- `spend` is in the account's currency; typically USD.
- `actions` is an array of typed events.

---

## Parsing the Actions Array

Conversions are encoded inside the `actions` array keyed by `action_type`.
The types to sum for conversion counts:

```elixir
@conversion_action_types ~w[purchase offsite_conversion.fb_pixel_purchase]

defp extract_conversions(nil), do: 0
defp extract_conversions([]), do: 0
defp extract_conversions(actions) do
  actions
  |> Enum.filter(fn a -> a["action_type"] in @conversion_action_types end)
  |> Enum.reduce(0, fn a, acc -> acc + to_integer(a["value"]) end)
end
```

---

## Parsing Insights

```elixir
defp parse_insights(data, ad_account_id) do
  Enum.flat_map(data, fn insight ->
    campaign_name = insight["campaign_name"]
    date_str      = insight["date_start"]
    conversions   = extract_conversions(insight["actions"])

    dims = %{
      date: date_str,
      campaign_name: campaign_name,
      ad_account_id: ad_account_id
    }

    recorded_at = parse_date_to_datetime(date_str)

    [
      metric(:impressions,  "impressions",  to_integer(insight["impressions"]),  recorded_at, dims),
      metric(:clicks,       "clicks",       to_integer(insight["clicks"]),       recorded_at, dims),
      metric(:spend,        "spend",        to_float(insight["spend"]),          recorded_at, dims),
      metric(:cpm,          "cpm",          to_float(insight["cpm"]),            recorded_at, dims),
      metric(:cpc,          "cpc",          to_float(insight["cpc"]),            recorded_at, dims),
      metric(:ctr,          "ctr",          to_float(insight["ctr"]),            recorded_at, dims),
      metric(:conversions,  "conversions",  conversions,                         recorded_at, dims)
    ]
  end)
end

defp metric(type, name, value, recorded_at, dimensions) do
  %{
    metric_type: type,
    metric_name: name,
    value: value,
    recorded_at: recorded_at,
    dimensions: dimensions,
    provider: :facebook_ads
  }
end
```

---

## provider_metadata

Store `ad_account_id` in `integration.provider_metadata["ad_account_id"]`.

```elixir
defp extract_ad_account_id(integration, opts) do
  case Keyword.get(opts, :ad_account_id) ||
       get_in(integration.provider_metadata, ["ad_account_id"]) do
    nil -> {:error, :missing_ad_account_id}
    id  -> {:ok, to_string(id)}
  end
end
```

---

## required_scopes/0

```elixir
def required_scopes, do: ["ads_read", "ads_management"]
```

Unlike Google OAuth scopes (which are full URLs), Facebook scopes are short identifiers.
Both are required — `ads_read` for data access, `ads_management` for account enumeration.
