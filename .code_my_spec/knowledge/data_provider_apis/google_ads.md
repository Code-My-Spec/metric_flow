# Google Ads API

Reference for the `MetricFlow.DataSync.DataProviders.GoogleAds` module.

No official Elixir Google Ads client exists — see the decision record at
`docs/architecture/decisions/data_provider_apis.md` for context. The REST API works
as plain JSON over HTTPS and is handled with raw Req.

---

## API Version and Endpoint

The decision record targets v23. The REST endpoint for streaming search results:

```
POST https://googleads.googleapis.com/v23/customers/{customer_id}/googleAds:searchStream
```

`searchStream` returns the complete result set in a single response body (a JSON array).
There is no cursor or continuation token — the entire query result arrives at once.

---

## Authentication Headers

Two headers are required on every request:

| Header             | Value                                | Where It Comes From             |
|--------------------|--------------------------------------|---------------------------------|
| `Authorization`    | `Bearer {access_token}`              | `integration.access_token`      |
| `developer-token`  | `{token}`                            | `config/runtime.exs` env var    |

The developer token is an application-level credential. It is not per-user. Every request
from the MetricFlow application uses the same developer token regardless of which user's
account is being queried.

### Req Configuration

```elixir
defp build_req(access_token) do
  developer_token = Application.fetch_env!(:metric_flow, :google_ads_developer_token)

  Req.new(
    auth: {:bearer, access_token},
    headers: [{"developer-token", developer_token}],
    retry: :safe_transient,
    max_retries: 3,
    retry_delay: fn n -> trunc(Integer.pow(2, n) * 1_000) end,
    receive_timeout: 30_000
  )
end
```

### config/runtime.exs

```elixir
config :metric_flow, :google_ads_developer_token,
  System.get_env("GOOGLE_ADS_DEVELOPER_TOKEN")
```

The `GOOGLE_ADS_DEVELOPER_TOKEN` environment variable must be set in production and
development. Obtaining a developer token requires:
1. Creating a Google Ads manager account
2. Applying via the API Center in Google Ads UI
3. Waiting for Google's review (can take several weeks)

Start the application process early.

---

## GAQL (Google Ads Query Language)

GAQL queries are plain strings. They follow a SQL-like syntax with fixed resource
targets in the `FROM` clause.

### Campaign Performance Query

```elixir
defp build_gaql(start_date, end_date) do
  """
  SELECT
    campaign.id,
    campaign.name,
    campaign.status,
    segments.date,
    metrics.impressions,
    metrics.clicks,
    metrics.cost_micros,
    metrics.conversions,
    metrics.ctr,
    metrics.average_cpc,
    metrics.conversions_value
  FROM campaign
  WHERE segments.date BETWEEN '#{start_date}' AND '#{end_date}'
    AND campaign.status != 'REMOVED'
  ORDER BY segments.date DESC
  """
end
```

Key GAQL rules:
- `FROM` clause names a resource (`campaign`, `ad_group`, `keyword_view`, etc.)
- `WHERE` clause filters; date ranges use `BETWEEN 'YYYY-MM-DD' AND 'YYYY-MM-DD'`
- You cannot mix resources from different resource type hierarchies in a single query
- Segments (`segments.date`, etc.) are added to SELECT to break down results by time

### Value Types

| Field                   | Unit                  | Conversion                          |
|-------------------------|-----------------------|-------------------------------------|
| `metrics.cost_micros`   | Micros (1/1,000,000)  | Divide by 1,000,000 for dollars     |
| `metrics.average_cpc`   | Micros                | Divide by 1,000,000 for dollars     |
| `metrics.ctr`           | Ratio (0.0–1.0)       | Multiply by 100 for percentage      |
| `metrics.impressions`   | Integer               | No conversion                       |
| `metrics.clicks`        | Integer               | No conversion                       |
| `metrics.conversions`   | Float                 | No conversion                       |

---

## Making the Request

```elixir
defp fetch_from_api(req, customer_id, gaql_query) do
  url = "https://googleads.googleapis.com/v23/customers/#{customer_id}/googleAds:searchStream"

  case Req.post(req, url: url, json: %{query: gaql_query}) do
    {:ok, %{status: 200, body: body}} when is_list(body) ->
      {:ok, body}

    {:ok, %{status: 401}} ->
      {:error, :unauthorized}

    {:ok, %{status: 403}} ->
      {:error, :insufficient_permissions}

    {:ok, %{status: 404}} ->
      {:error, :resource_not_found}

    {:ok, %{status: 429}} ->
      {:error, :rate_limited}

    {:ok, %{body: %{"error" => %{"status" => "RESOURCE_EXHAUSTED"}}}} ->
      {:error, :rate_limited}

    {:ok, _} ->
      {:error, :network_error}

    {:error, _exception} ->
      {:error, :network_error}
  end
end
```

---

## Response Structure

The searchStream response body is a JSON array. Each element represents a batch of
results. Each batch has a `results` key containing a list of `GoogleAdsRow` objects,
where field names match the GAQL SELECT clause in camelCase:

```json
[
  {
    "results": [
      {
        "campaign": {"id": "123", "name": "Brand Campaign"},
        "segments": {"date": "2025-01-15"},
        "metrics": {
          "impressions": "5000",
          "clicks": "200",
          "costMicros": "150000000",
          "conversions": "12.0",
          "ctr": "0.04",
          "averageCpc": "750000"
        }
      }
    ],
    "fieldMask": "campaign.id,campaign.name,segments.date,metrics.impressions,..."
  }
]
```

Note: all numeric values arrive as strings.

---

## Response Parsing

```elixir
defp parse_ads_response(body, customer_id) when is_list(body) do
  body
  |> Enum.flat_map(fn batch -> batch["results"] || [] end)
  |> Enum.flat_map(fn row -> row_to_metrics(row, customer_id) end)
end

defp row_to_metrics(row, customer_id) do
  campaign_name = get_in(row, ["campaign", "name"])
  campaign_id   = get_in(row, ["campaign", "id"])
  date_str      = get_in(row, ["segments", "date"])
  m             = row["metrics"] || %{}

  base_dims = %{
    date: date_str,
    campaign_name: campaign_name,
    campaign_id: campaign_id,
    customer_id: customer_id
  }

  recorded_at = parse_date_to_datetime(date_str)

  [
    metric(:impressions, "impressions", to_integer(m["impressions"]), recorded_at, base_dims),
    metric(:clicks, "clicks", to_integer(m["clicks"]), recorded_at, base_dims),
    metric(:cost, "cost", micros_to_dollars(m["costMicros"]), recorded_at, base_dims),
    metric(:conversions, "conversions", to_float(m["conversions"]), recorded_at, base_dims),
    metric(:ctr, "ctr", to_float(m["ctr"]), recorded_at, base_dims),
    metric(:average_cpc, "average_cpc", micros_to_dollars(m["averageCpc"]), recorded_at, base_dims)
  ]
end

defp metric(type, name, value, recorded_at, dimensions) do
  %{
    metric_type: type,
    metric_name: name,
    value: value,
    recorded_at: recorded_at,
    dimensions: dimensions,
    provider: :google_ads
  }
end
```

---

## Customer ID Format

Google Ads customer IDs are displayed as `123-456-7890` in the UI but passed to the API
without dashes: `1234567890`. Normalize if needed:

```elixir
defp normalize_customer_id(id) when is_binary(id),
  do: String.replace(id, "-", "")
defp normalize_customer_id(id) when is_integer(id),
  do: to_string(id)
```

---

## provider_metadata

The `customer_id` for Google Ads is stored in `integration.provider_metadata["customer_id"]`.

```elixir
defp extract_customer_id(integration, opts) do
  case Keyword.get(opts, :customer_id) ||
       get_in(integration.provider_metadata, ["customer_id"]) do
    nil -> {:error, :missing_customer_id}
    id  -> {:ok, normalize_customer_id(id)}
  end
end
```

---

## required_scopes/0

```elixir
def required_scopes, do: ["https://www.googleapis.com/auth/adwords"]
```

This scope must be requested during the OAuth flow for the Google provider. The existing
`MetricFlow.Integrations.Providers.Google` module will need its scope list updated to
include `adwords` when the Google Ads integration is wired up.

---

## Notes on MCC (Manager) Accounts

If a user's Google Ads account is a manager account (MCC) with sub-accounts, queries
against `customers/{mcc_id}/googleAds:searchStream` will only return data for the MCC
itself, not sub-accounts. To fetch sub-account data, use the sub-account's `customer_id`.

The `login-customer-id` header is required when accessing a sub-account through a manager
account. Add it to the Req configuration if needed:

```elixir
headers: [
  {"developer-token", developer_token},
  {"login-customer-id", manager_account_id}
]
```
