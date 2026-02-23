# Data Provider APIs: Setup and Patterns

This file is the primary reference for implementing the four external data provider modules
in the `MetricFlow.DataSync.DataProviders` namespace. Each provider implements the
`MetricFlow.DataSync.DataProviders.Behaviour` contract with `fetch_metrics/2`, `provider/0`,
and `required_scopes/0`.

See `docs/architecture/decisions/data_provider_apis.md` for the decision record that
established this approach.

---

## Project Context

The four provider modules sit inside the `MetricFlow.DataSync` context. The `SyncWorker`
(an Oban worker) calls them after loading an `Integration` from the database. The
`Integration` struct carries the encrypted `access_token`, `refresh_token`, `expires_at`,
and a `provider_metadata` map that holds provider-specific identifiers (property IDs,
customer IDs, etc.).

Key supporting modules:

- `MetricFlow.Integrations.Integration.expired?/1` — check before every API call
- `MetricFlow.Integrations.Integration.has_refresh_token?/1` — used by `SyncWorker` to
  decide whether to attempt a refresh
- `MetricFlow.Integrations` — handles token refresh at the context level; providers do not
  refresh tokens themselves
- `Req ~> 0.5` — HTTP client for Google Ads, Facebook Ads, and QuickBooks
- `google_api_analytics_data ~> 0.17` — official Google client for GA4

---

## The Behaviour Contract

Every provider module must declare `@behaviour MetricFlow.DataSync.DataProviders.Behaviour`
and implement:

```elixir
@callback fetch_metrics(Integration.t(), keyword()) ::
  {:ok, list(map())} | {:error, term()}

@callback provider() :: atom()

@callback required_scopes() :: list(String.t())
```

The unified metric map returned by `fetch_metrics/2` must contain these keys:

```elixir
%{
  metric_type: :sessions,          # atom — categorises the measurement
  metric_name: "sessions",         # string — display label
  value: 1234,                     # integer or float
  recorded_at: ~U[2025-01-15 00:00:00Z],  # UTC DateTime
  dimensions: %{date: "2025-01-15"},       # string-keyed or atom-keyed map
  provider: :google_analytics      # atom matching Integration.provider enum
}
```

---

## Common Pre-flight Pattern

All four providers share the same opening sequence in `fetch_metrics/2`:

```elixir
def fetch_metrics(%Integration{} = integration, opts) do
  with false <- Integration.expired?(integration),
       {:ok, config_id} <- extract_required_id(integration, opts) do
    # ... build and execute request
  else
    true -> {:error, :token_expired}
    {:error, reason} -> {:error, reason}
  end
end
```

The `SyncWorker` catches `{:error, :token_expired}` and delegates token refresh to
`MetricFlow.Integrations.refresh_token/2` before retrying. Providers never call
`refresh_token/2` themselves.

---

## 1. Google Analytics (GA4) — Official Client Library

The decision record chose the `googleapis/elixir-google-api` generated client
(`google_api_analytics_data ~> 0.17`) for GA4 because it provides typed request/response
structs, reducing the surface area for request-construction bugs.

### Adding to mix.exs

```elixir
{:google_api_analytics_data, "~> 0.17"}
```

This pulls in `google_gax` as a transitive dependency. No `goth` needed — the library
accepts a bearer token directly.

### Connection and RunReportRequest

```elixir
alias GoogleApi.AnalyticsData.V1beta.Api.Properties
alias GoogleApi.AnalyticsData.V1beta.Connection
alias GoogleApi.AnalyticsData.V1beta.Model.RunReportRequest
alias GoogleApi.AnalyticsData.V1beta.Model.DateRange
alias GoogleApi.AnalyticsData.V1beta.Model.Metric
alias GoogleApi.AnalyticsData.V1beta.Model.Dimension

defp run_report(access_token, property_id, start_date, end_date) do
  connection = Connection.new(access_token)

  request = %RunReportRequest{
    dateRanges: [%DateRange{startDate: start_date, endDate: end_date}],
    metrics: [
      %Metric{name: "sessions"},
      %Metric{name: "totalUsers"},
      %Metric{name: "newUsers"},
      %Metric{name: "screenPageViews"},
      %Metric{name: "bounceRate"},
      %Metric{name: "averageSessionDuration"}
    ],
    dimensions: [
      %Dimension{name: "date"}
    ]
  }

  Properties.analyticsdata_properties_run_report(
    connection,
    "properties/#{property_id}",
    body: request
  )
end
```

### Response Structure

The GA4 response has parallel `dimensionHeaders`, `metricHeaders`, `rows` arrays.
Each row has `dimensionValues` and `metricValues` lists indexed to match the headers.

```elixir
defp parse_ga4_response(%{"rows" => rows} = response, property_id) do
  metric_headers =
    response
    |> get_in(["metricHeaders"])
    |> Enum.map(& &1["name"])

  dimension_headers =
    response
    |> get_in(["dimensionHeaders"])
    |> Enum.map(& &1["name"])

  Enum.flat_map(rows, fn row ->
    dimensions =
      dimension_headers
      |> Enum.zip(row["dimensionValues"])
      |> Map.new(fn {k, v} -> {k, v["value"]} end)

    metric_values = Enum.map(row["metricValues"], & &1["value"])

    metric_headers
    |> Enum.zip(metric_values)
    |> Enum.map(fn {name, value} ->
      %{
        metric_type: String.to_atom(Macro.underscore(name)),
        metric_name: name,
        value: parse_numeric(value),
        recorded_at: parse_ga4_date(dimensions["date"]),
        dimensions: Map.put(dimensions, "property_id", property_id),
        provider: :google_analytics
      }
    end)
  end)
end
```

### Error Handling

The `google_gax` library wraps HTTP errors in `{:error, %Tesla.Env{status: status}}`.
Map these to normalized atoms:

```elixir
defp normalize_ga4_error(%Tesla.Env{status: 401}), do: {:error, :unauthorized}
defp normalize_ga4_error(%Tesla.Env{status: 403}), do: {:error, :insufficient_permissions}
defp normalize_ga4_error(%Tesla.Env{status: 404}), do: {:error, :resource_not_found}
defp normalize_ga4_error(%Tesla.Env{status: 429}), do: {:error, :rate_limited}
defp normalize_ga4_error(_), do: {:error, :network_error}
```

### provider_metadata key

The `property_id` for GA4 is stored in `integration.provider_metadata["property_id"]`.
Extract it with a fallback to `opts[:property_id]`:

```elixir
defp extract_property_id(integration, opts) do
  case Keyword.get(opts, :property_id) || get_in(integration.provider_metadata, ["property_id"]) do
    nil -> {:error, :missing_property_id}
    id -> {:ok, to_string(id)}
  end
end
```

### required_scopes/0

```elixir
def required_scopes, do: ["https://www.googleapis.com/auth/analytics.readonly"]
```

---

## 2. Google Ads — Raw Req (REST/searchStream)

No official Elixir client exists. The Google Ads REST API v23+ accepts JSON over HTTPS.

### Endpoint

```
POST https://googleads.googleapis.com/v23/customers/{customer_id}/googleAds:searchStream
```

The `searchStream` endpoint returns all results in a single response with no pagination
cursor. The response body is a JSON array where each element has a `results` key.

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

The developer token is an app-level credential from the Google Ads API Center. It must be
stored in `config/runtime.exs` under the key `:google_ads_developer_token` and populated
from an environment variable. It is not user-specific.

### GAQL Query

GAQL is a SQL-like language. Queries are plain strings:

```elixir
defp build_gaql(start_date, end_date) do
  """
  SELECT
    campaign.name,
    segments.date,
    metrics.impressions,
    metrics.clicks,
    metrics.cost_micros,
    metrics.conversions,
    metrics.ctr,
    metrics.average_cpc
  FROM campaign
  WHERE segments.date BETWEEN '#{start_date}' AND '#{end_date}'
  ORDER BY segments.date DESC
  """
end
```

Key GAQL rules:
- Dates use `YYYY-MM-DD` format
- `cost_micros` is the cost in micros (divide by 1,000,000 to get dollars)
- `ctr` is a ratio (0.0–1.0), multiply by 100 to get a percentage
- `average_cpc` is in micros; divide by 1,000,000 for dollars

### Making the Request

```elixir
defp fetch_from_api(req, customer_id, gaql_query) do
  url = "https://googleads.googleapis.com/v23/customers/#{customer_id}/googleAds:searchStream"

  case Req.post(req, url: url, json: %{query: gaql_query}) do
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

    {:ok, %{status: _}} ->
      {:error, :network_error}

    {:error, _exception} ->
      {:error, :network_error}
  end
end
```

### Response Parsing

The searchStream response is a JSON array. Each element has a `results` key containing
a list of `GoogleAdsRow` objects:

```elixir
defp parse_ads_response(body, customer_id) when is_list(body) do
  body
  |> Enum.flat_map(fn %{"results" => results} -> results end)
  |> Enum.flat_map(fn row -> row_to_metrics(row, customer_id) end)
end

defp row_to_metrics(row, customer_id) do
  campaign_name = get_in(row, ["campaign", "name"])
  date_str = get_in(row, ["segments", "date"])
  metrics = row["metrics"]

  [
    make_metric(:impressions, "impressions", to_integer(metrics["impressions"]),
      date_str, campaign_name, customer_id),
    make_metric(:clicks, "clicks", to_integer(metrics["clicks"]),
      date_str, campaign_name, customer_id),
    make_metric(:cost, "cost", micros_to_dollars(metrics["costMicros"]),
      date_str, campaign_name, customer_id),
    make_metric(:conversions, "conversions", to_float(metrics["conversions"]),
      date_str, campaign_name, customer_id),
    make_metric(:ctr, "ctr", to_float(metrics["ctr"]),
      date_str, campaign_name, customer_id),
    make_metric(:average_cpc, "average_cpc", micros_to_dollars(metrics["averageCpc"]),
      date_str, campaign_name, customer_id)
  ]
end

defp make_metric(type, name, value, date_str, campaign_name, customer_id) do
  %{
    metric_type: type,
    metric_name: name,
    value: value,
    recorded_at: parse_date_to_datetime(date_str),
    dimensions: %{date: date_str, campaign_name: campaign_name, customer_id: customer_id},
    provider: :google_ads
  }
end

defp micros_to_dollars(nil), do: 0.0
defp micros_to_dollars(micros) when is_binary(micros),
  do: String.to_integer(micros) / 1_000_000
defp micros_to_dollars(micros) when is_integer(micros), do: micros / 1_000_000
```

### config/runtime.exs

```elixir
config :metric_flow, :google_ads_developer_token,
  System.get_env("GOOGLE_ADS_DEVELOPER_TOKEN")
```

Note: obtaining a developer token requires applying to Google and undergoing a review process.
Apply early — approval can take several weeks.

### provider_metadata key

Store `customer_id` in `integration.provider_metadata["customer_id"]`.

### required_scopes/0

```elixir
def required_scopes, do: ["https://www.googleapis.com/auth/adwords"]
```

---

## 3. Facebook Ads — Raw Req (Marketing API)

No maintained Elixir client exists. Facebook's Marketing API uses `access_token` as a
query parameter rather than an `Authorization` header.

### Endpoint

```
GET https://graph.facebook.com/v20.0/act_{ad_account_id}/insights
```

The `act_` prefix is required. If the stored `ad_account_id` already has the prefix, do
not add it again.

### Req Configuration

Facebook tokens travel as query params, not in the `Authorization` header. Do not use
`auth: {:bearer, ...}` for Facebook — it would generate a conflicting header:

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

The `access_token` is passed as part of `params:` on each request, not on the `Req.new/1`
base configuration, since the token is user-specific.

### Making the Request (first page)

```elixir
defp fetch_page(req, ad_account_id, access_token, start_date, end_date, after_cursor \\ nil) do
  account_path = normalize_account_id(ad_account_id)
  url = "https://graph.facebook.com/v20.0/#{account_path}/insights"

  params =
    [
      access_token: access_token,
      fields: "campaign_name,impressions,clicks,spend,cpm,cpc,ctr,actions,date_start",
      time_range: Jason.encode!(%{since: start_date, until: end_date}),
      level: "campaign",
      limit: 100
    ]
    |> then(fn p ->
      if after_cursor, do: Keyword.put(p, :after, after_cursor), else: p
    end)

  case Req.get(req, url: url, params: params) do
    {:ok, %{status: 200, body: body}} -> {:ok, body}
    {:ok, %{status: 401}} -> {:error, :unauthorized}
    {:ok, %{status: 403}} -> {:error, :insufficient_permissions}
    {:ok, %{status: 429}} -> {:error, :rate_limited}
    {:ok, %{body: %{"error" => %{"code" => 190}}}} -> {:error, :token_expired}
    {:ok, _} -> {:error, :network_error}
    {:error, _} -> {:error, :network_error}
  end
end

defp normalize_account_id("act_" <> _ = id), do: id
defp normalize_account_id(id), do: "act_#{id}"
```

### Cursor Pagination

Facebook uses cursor-based pagination. The response includes a `paging` key with a
`next` URL and a `cursors.after` value:

```elixir
defp fetch_all_pages(req, account_id, token, start_date, end_date) do
  fetch_all_pages(req, account_id, token, start_date, end_date, nil, [])
end

defp fetch_all_pages(req, account_id, token, start_date, end_date, cursor, acc) do
  case fetch_page(req, account_id, token, start_date, end_date, cursor) do
    {:ok, %{"data" => data, "paging" => %{"cursors" => %{"after" => next_cursor}, "next" => next}}}
    when is_binary(next) and next != "" ->
      fetch_all_pages(req, account_id, token, start_date, end_date, next_cursor, acc ++ data)

    {:ok, %{"data" => data}} ->
      {:ok, acc ++ data}

    {:error, reason} ->
      {:error, reason}
  end
end
```

### Response Parsing

```elixir
defp parse_insights(data, ad_account_id) do
  Enum.flat_map(data, fn insight ->
    campaign_name = insight["campaign_name"]
    date_str = insight["date_start"]
    conversions = extract_conversions(insight["actions"])

    base_dimensions = %{
      date: date_str,
      campaign_name: campaign_name,
      ad_account_id: ad_account_id
    }

    [
      %{metric_type: :impressions, metric_name: "impressions",
        value: to_integer(insight["impressions"]),
        recorded_at: parse_date_to_datetime(date_str),
        dimensions: base_dimensions, provider: :facebook_ads},
      %{metric_type: :clicks, metric_name: "clicks",
        value: to_integer(insight["clicks"]),
        recorded_at: parse_date_to_datetime(date_str),
        dimensions: base_dimensions, provider: :facebook_ads},
      %{metric_type: :spend, metric_name: "spend",
        value: to_float(insight["spend"]),
        recorded_at: parse_date_to_datetime(date_str),
        dimensions: base_dimensions, provider: :facebook_ads},
      %{metric_type: :ctr, metric_name: "ctr",
        value: to_float(insight["ctr"]),
        recorded_at: parse_date_to_datetime(date_str),
        dimensions: base_dimensions, provider: :facebook_ads},
      %{metric_type: :conversions, metric_name: "conversions",
        value: conversions,
        recorded_at: parse_date_to_datetime(date_str),
        dimensions: base_dimensions, provider: :facebook_ads}
    ]
  end)
end

# Facebook encodes conversions in the "actions" array keyed by action_type
defp extract_conversions(nil), do: 0
defp extract_conversions([]), do: 0
defp extract_conversions(actions) do
  purchase_types = ["purchase", "offsite_conversion.fb_pixel_purchase"]

  actions
  |> Enum.filter(fn action -> action["action_type"] in purchase_types end)
  |> Enum.reduce(0, fn action, acc -> acc + to_integer(action["value"]) end)
end
```

### Token Expiry Warning

Facebook long-lived tokens expire after 60 days and cannot be programmatically refreshed
via standard OAuth. When a Facebook token is close to expiry, the provider should return
`{:error, :token_expired}` and the `SyncWorker` marks the sync as `requires_reauth`.
A future user notification mechanism will prompt the user to reconnect.

Facebook API error code `190` in the response body signals an expired or invalid token:

```elixir
# In the response handler
{:ok, %{body: %{"error" => %{"code" => 190}}}} -> {:error, :token_expired}
```

### Rate Limit Headers

Facebook surfaces rate limit state in response headers rather than always returning 429.
Parse these for observability (logging), but let `Req`'s `:safe_transient` retry handle
the actual 429 cases:

```elixir
defp log_rate_limit_headers(headers) do
  case List.keyfind(headers, "x-app-usage", 0) do
    {_, value} -> Logger.debug("Facebook app usage: #{value}")
    nil -> :ok
  end

  case List.keyfind(headers, "x-ad-account-usage", 0) do
    {_, value} -> Logger.debug("Facebook ad account usage: #{value}")
    nil -> :ok
  end
end
```

### provider_metadata key

Store `ad_account_id` in `integration.provider_metadata["ad_account_id"]`.

### required_scopes/0

```elixir
def required_scopes, do: ["ads_read", "ads_management"]
```

---

## 4. QuickBooks Online — Raw Req (Accounting API v3)

No maintained Elixir client exists. QuickBooks uses standard Bearer token auth. QuickBooks
tokens expire after 1 hour and have long-lived refresh tokens that rotate on each refresh.
Token refresh is handled by `MetricFlow.Integrations.refresh_token/2`.

### Endpoints

Two report endpoints are needed, both returning single-response JSON (no pagination):

```
GET https://quickbooks.api.intuit.com/v3/company/{realm_id}/reports/ProfitAndLoss
GET https://quickbooks.api.intuit.com/v3/company/{realm_id}/reports/BalanceSheet
```

For sandbox testing use `https://sandbox-quickbooks.api.intuit.com` as the base.

### Req Configuration

```elixir
defp build_req(access_token) do
  Req.new(
    auth: {:bearer, access_token},
    headers: [{"Accept", "application/json"}],
    retry: :safe_transient,
    max_retries: 3,
    retry_delay: fn n -> trunc(Integer.pow(2, n) * 1_000) end,
    receive_timeout: 30_000
  )
end
```

QuickBooks defaults to XML responses. The `Accept: application/json` header is required
to receive JSON.

### Making the Request

```elixir
defp base_url do
  case Application.get_env(:metric_flow, :quickbooks_env, :production) do
    :sandbox -> "https://sandbox-quickbooks.api.intuit.com"
    :production -> "https://quickbooks.api.intuit.com"
  end
end

defp fetch_report(req, realm_id, report_type, start_date, end_date, accounting_method) do
  url = "#{base_url()}/v3/company/#{realm_id}/reports/#{report_type}"

  params = [
    start_date: start_date,
    end_date: end_date,
    accounting_method: accounting_method
  ]

  case Req.get(req, url: url, params: params) do
    {:ok, %{status: 200, body: body}} -> {:ok, body}
    {:ok, %{status: 401}} -> {:error, :unauthorized}
    {:ok, %{status: 403}} -> {:error, :insufficient_permissions}
    {:ok, %{status: 404}} -> {:error, :resource_not_found}
    {:ok, _} -> {:error, :network_error}
    {:error, _} -> {:error, :network_error}
  end
end
```

### QuickBooks Report JSON Structure

QuickBooks reports use a deeply nested `Rows` structure. Each row has a `type` field
(`Section`, `Data`, `Summary`) and a `ColData` array for values:

```
Header
Rows
  Row (type: "Section", group: "Income")
    Header (ColData: ["Income", ""])
    Rows
      Row (type: "Data")
        ColData: ["Service Revenue", "50000.00"]
      Row (type: "Data")
        ColData: ["Product Revenue", "30000.00"]
    Summary
      ColData: ["Total Income", "80000.00"]
  Row (type: "Section", group: "NetIncome")
    ColData: ["Net Income", "25000.00"]
```

### Parsing Strategy

Navigate to summary rows of named sections rather than summing individual data rows.
This avoids double-counting when QuickBooks includes both detail and summary lines:

```elixir
defp extract_profit_and_loss(body, realm_id, end_date) do
  rows = get_in(body, ["Rows", "Row"]) || []

  revenue = find_section_total(rows, "Income")
  expenses = find_section_total(rows, "Expenses")
  net_income = find_net_income(rows)
  cogs = find_section_total(rows, "CostOfGoodsSold")
  gross_profit = if cogs > 0, do: revenue - cogs, else: revenue - expenses

  metadata = %{realm_id: realm_id, report_type: :profit_and_loss, accounting_method: "Accrual"}
  recorded_at = parse_date_to_datetime(end_date)

  [
    %{metric_type: :revenue, metric_name: "revenue",
      value: revenue, recorded_at: recorded_at, dimensions: metadata, provider: :quickbooks},
    %{metric_type: :expenses, metric_name: "expenses",
      value: expenses, recorded_at: recorded_at, dimensions: metadata, provider: :quickbooks},
    %{metric_type: :net_income, metric_name: "net_income",
      value: net_income, recorded_at: recorded_at, dimensions: metadata, provider: :quickbooks},
    %{metric_type: :gross_profit, metric_name: "gross_profit",
      value: gross_profit, recorded_at: recorded_at, dimensions: metadata, provider: :quickbooks}
  ]
end

defp find_section_total(rows, group_name) do
  rows
  |> Enum.find(fn row -> row["group"] == group_name end)
  |> case do
    nil -> 0.0
    section ->
      # Prefer the Summary row's ColData total over summing detail rows
      summary_rows = get_in(section, ["Rows", "Row"]) || []
      summary = Enum.find(summary_rows, fn r -> r["type"] == "Summary" end)

      if summary do
        summary |> get_in(["ColData"]) |> Enum.at(1) |> parse_currency()
      else
        0.0
      end
  end
end

defp find_net_income(rows) do
  rows
  |> Enum.find(fn row -> row["group"] == "NetIncome" end)
  |> case do
    nil -> 0.0
    row -> row |> get_in(["Summary", "ColData"]) |> Enum.at(1) |> parse_currency()
  end
end

defp parse_currency(nil), do: 0.0
defp parse_currency(val) when is_binary(val), do: String.to_float(val)
defp parse_currency(val) when is_float(val), do: val
defp parse_currency(val) when is_integer(val), do: val / 1.0
```

### config/runtime.exs

```elixir
config :metric_flow, :quickbooks_env, :production  # or :sandbox for development
```

### provider_metadata key

Store `realm_id` (QuickBooks company ID) in `integration.provider_metadata["realm_id"]`.

### required_scopes/0

```elixir
def required_scopes, do: ["com.intuit.quickbooks.accounting"]
```

---

## Common Req Configuration Pattern

Providers using raw Req (Google Ads, Facebook Ads, QuickBooks) share the same base
configuration with exponential backoff. The pattern from the decision record:

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

Breakdown:
- `auth: {:bearer, access_token}` — adds `Authorization: Bearer {token}` header. Do not
  use this for Facebook Ads where the token is a query param.
- `retry: :safe_transient` — Req's built-in policy that retries on network errors and
  5xx responses, but not on 4xx (which are not transient). This prevents retrying a 401
  (which would just fail again).
- `max_retries: 3` — up to 3 retry attempts after the initial request.
- `retry_delay: fn n -> trunc(Integer.pow(2, n) * 1_000) end` — exponential backoff:
  1s after first failure, 2s after second, 4s after third.
- `receive_timeout: 30_000` — 30 second timeout on reading the response body. External
  API calls can be slow; this is a reasonable ceiling.

### Injecting a Test Req

Providers should accept an optional `:req` keyword argument for testing:

```elixir
def fetch_metrics(%Integration{} = integration, opts) do
  req = Keyword.get(opts, :req, build_req(integration.access_token))
  # ...
end
```

In tests, pass `req: Req.new(plug: MyFakePlug)` to intercept HTTP calls without
hitting the real API.

---

## Error Normalization Table

All provider modules normalize HTTP errors and API-level errors to the same atoms so
the `SyncWorker` can handle them uniformly:

| HTTP Status / API Signal              | Normalized Atom               | Provider Notes |
|---------------------------------------|-------------------------------|----------------|
| 401 Unauthorized                      | `:unauthorized`               | All providers  |
| 403 Forbidden                         | `:insufficient_permissions`   | All providers  |
| 404 Not Found                         | `:resource_not_found`         | All providers  |
| 429 Too Many Requests                 | `:rate_limited`               | All providers  |
| Network error / Req exception         | `:network_error`              | All providers  |
| Malformed / unexpected JSON           | `:parse_error`                | All providers  |
| Pre-flight expiry check               | `:token_expired`              | All providers  |
| Facebook error code 190 in body       | `:token_expired`              | Facebook Ads   |
| Google Ads `RESOURCE_EXHAUSTED`       | `:rate_limited`               | Google Ads     |
| Missing provider config (no ID)       | `:missing_{config_key}`       | All providers  |

The `:missing_{config_key}` atoms are provider-specific:
- `:missing_property_id` — Google Analytics
- `:missing_customer_id` — Google Ads
- `:missing_ad_account_id` — Facebook Ads
- `:missing_realm_id` — QuickBooks

---

## Shared Utility Functions

These helpers are used across all four provider modules. Consider placing them in a
shared `MetricFlow.DataSync.DataProviders.Helpers` module:

```elixir
defmodule MetricFlow.DataSync.DataProviders.Helpers do
  @moduledoc "Shared utility functions for data provider implementations."

  @doc "Converts a YYYY-MM-DD string to a UTC DateTime at midnight."
  def parse_date_to_datetime(nil), do: DateTime.utc_now()
  def parse_date_to_datetime(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} ->
        date |> DateTime.new!(~T[00:00:00], "Etc/UTC")
      {:error, _} ->
        DateTime.utc_now()
    end
  end

  @doc "Returns a {start_date, end_date} tuple in YYYY-MM-DD format."
  def default_date_range(opts) do
    end_date = Keyword.get(opts, :end_date, Date.utc_today())
    start_date = Keyword.get(opts, :start_date, Date.add(end_date, -30))
    {Date.to_iso8601(start_date), Date.to_iso8601(end_date)}
  end

  @doc "Parses a string or number to integer, returning 0 on failure."
  def to_integer(nil), do: 0
  def to_integer(val) when is_integer(val), do: val
  def to_integer(val) when is_float(val), do: round(val)
  def to_integer(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> 0
    end
  end

  @doc "Parses a string or number to float, returning 0.0 on failure."
  def to_float(nil), do: 0.0
  def to_float(val) when is_float(val), do: val
  def to_float(val) when is_integer(val), do: val / 1.0
  def to_float(val) when is_binary(val) do
    case Float.parse(val) do
      {f, _} -> f
      :error -> 0.0
    end
  end

  @doc "Converts micros (1/1,000,000 of a currency unit) to the base unit."
  def micros_to_dollars(val), do: to_float(val) / 1_000_000.0
end
```

---

## Testing Each Provider

### Google Analytics

Mock at the HTTP level using `Req.Test`:

```elixir
# In test setup
Req.Test.stub(:ga4_api, fn conn ->
  Req.Test.json(conn, ga4_fixture_response())
end)

# In provider, make the underlying Tesla/Req client use the stub
# (google_gax uses Tesla internally — see note in ga4_testing.md)
```

Alternatively, wrap `analyticsdata_properties_run_report/3` in a module attribute or
a function head that accepts an injected connection or mock module.

### Google Ads, Facebook Ads, QuickBooks

All three accept an optional `:req` in `opts`:

```elixir
# In test
fake_req = Req.new(plug: fn conn ->
  Req.Test.json(conn, %{"results" => [...]})
end)

GoogleAds.fetch_metrics(integration, req: fake_req, customer_id: "123")
```

This lets tests verify the full parsing and normalization logic without network calls.

### Shared Test Patterns

```elixir
# Expired token short-circuit
test "returns :token_expired when integration is expired" do
  expired = %Integration{expires_at: ~U[2020-01-01 00:00:00Z], access_token: "tok"}
  assert {:error, :token_expired} = GoogleAds.fetch_metrics(expired, [])
end

# Missing config short-circuit
test "returns :missing_customer_id when no customer_id" do
  integration = %Integration{expires_at: future(), provider_metadata: %{}}
  assert {:error, :missing_customer_id} = GoogleAds.fetch_metrics(integration, [])
end
```
