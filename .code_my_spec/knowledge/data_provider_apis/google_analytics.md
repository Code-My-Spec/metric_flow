# Google Analytics Data API (GA4)

Reference for the `MetricFlow.DataSync.DataProviders.GoogleAnalytics` module.
The decision to use the official `google_api_analytics_data` library over raw Req is
documented in `docs/architecture/decisions/data_provider_apis.md`.

---

## Library

**Package:** `google_api_analytics_data ~> 0.17`
**Source:** https://github.com/googleapis/elixir-google-api (auto-generated from Discovery API)
**Hex.pm:** https://hex.pm/packages/google_api_analytics_data
**Downloads:** ~154K, last release November 2024, maintained by Google Cloud.

Add to `mix.exs`:

```elixir
{:google_api_analytics_data, "~> 0.17"}
```

This pulls in `google_gax` as a transitive dependency. No `goth` needed — the library
accepts a user OAuth bearer token directly via `Connection.new/1`.

---

## Key Modules

```elixir
alias GoogleApi.AnalyticsData.V1beta.Connection
alias GoogleApi.AnalyticsData.V1beta.Api.Properties
alias GoogleApi.AnalyticsData.V1beta.Model.RunReportRequest
alias GoogleApi.AnalyticsData.V1beta.Model.DateRange
alias GoogleApi.AnalyticsData.V1beta.Model.Metric
alias GoogleApi.AnalyticsData.V1beta.Model.Dimension
```

---

## Connection

`Connection.new/1` accepts a plain OAuth access token string and creates a Tesla client
configured with the bearer token:

```elixir
connection = Connection.new(access_token)
```

This is all that is needed. There is no session, no state, and no process to start.

---

## RunReportRequest

The primary API call is `Properties.analyticsdata_properties_run_report/3`:

```elixir
defp run_report(connection, property_id, start_date, end_date) do
  request = %RunReportRequest{
    dateRanges: [
      %DateRange{startDate: start_date, endDate: end_date}
    ],
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

The `property_id` is the numeric GA4 property ID (e.g. `"123456789"`), not the UA
tracking ID. It is stored in `integration.provider_metadata["property_id"]`.

### Date Format

GA4 accepts dates as `"YYYY-MM-DD"` strings, as well as the special values `"today"`,
`"yesterday"`, and `"NdaysAgo"` (e.g. `"30daysAgo"`).

### Metric Names

GA4 metric names use camelCase as strings. Common names:

| API Name                    | Meaning                              |
|-----------------------------|--------------------------------------|
| `sessions`                  | Number of sessions                   |
| `totalUsers`                | Total unique users                   |
| `newUsers`                  | First-time users                     |
| `screenPageViews`           | Total page views                     |
| `bounceRate`                | Ratio 0.0–1.0; multiply by 100 for % |
| `averageSessionDuration`    | Seconds as float                     |
| `engagedSessions`           | Sessions with >10s engagement        |
| `conversions`               | Conversion event count               |

Full list: https://developers.google.com/analytics/devguides/reporting/data/v1/api-schema

### Dimension Names

Common dimensions:

| API Name          | Meaning                            |
|-------------------|------------------------------------|
| `date`            | YYYYMMDD string                    |
| `sessionSource`   | Traffic source (google, direct)    |
| `sessionMedium`   | Traffic medium (organic, cpc)      |
| `pagePath`        | URL path of the page               |
| `country`         | ISO country code                   |
| `deviceCategory`  | desktop, mobile, tablet            |

---

## Response Structure

The response body is a map with parallel header and value arrays:

```json
{
  "dimensionHeaders": [{"name": "date"}],
  "metricHeaders": [{"name": "sessions", "type": "TYPE_INTEGER"}],
  "rows": [
    {
      "dimensionValues": [{"value": "20250115"}],
      "metricValues": [{"value": "1234"}]
    }
  ],
  "rowCount": 1
}
```

Key points:
- All values arrive as strings, even numerics.
- `bounceRate` arrives as a string like `"0.4523"` — a ratio, not a percentage.
- `date` dimension arrives as `"YYYYMMDD"` (no dashes).

---

## Parsing Example

```elixir
defp parse_response({:ok, %{body: body}}, property_id) do
  rows = body["rows"] || []
  metric_headers = Enum.map(body["metricHeaders"] || [], & &1["name"])
  dimension_headers = Enum.map(body["dimensionHeaders"] || [], & &1["name"])

  metrics =
    Enum.flat_map(rows, fn row ->
      dimension_values = Enum.map(row["dimensionValues"], & &1["value"])
      metric_values = Enum.map(row["metricValues"], & &1["value"])

      dimensions =
        dimension_headers
        |> Enum.zip(dimension_values)
        |> Map.new()
        |> Map.put("property_id", property_id)

      date_str = ga4_date_to_iso(dimensions["date"])

      metric_headers
      |> Enum.zip(metric_values)
      |> Enum.map(fn {name, value} ->
        %{
          metric_type: String.to_atom(Macro.underscore(name)),
          metric_name: name,
          value: parse_metric_value(name, value),
          recorded_at: parse_date_to_datetime(date_str),
          dimensions: dimensions,
          provider: :google_analytics
        }
      end)
    end)

  {:ok, metrics}
end

defp parse_response({:error, %Tesla.Env{status: 401}}, _), do: {:error, :unauthorized}
defp parse_response({:error, %Tesla.Env{status: 403}}, _), do: {:error, :insufficient_permissions}
defp parse_response({:error, %Tesla.Env{status: 404}}, _), do: {:error, :resource_not_found}
defp parse_response({:error, %Tesla.Env{status: 429}}, _), do: {:error, :rate_limited}
defp parse_response({:error, _}, _), do: {:error, :network_error}

# GA4 date dimension is YYYYMMDD — convert to YYYY-MM-DD
defp ga4_date_to_iso(nil), do: nil
defp ga4_date_to_iso(<<y::binary-4, m::binary-2, d::binary-2>>), do: "#{y}-#{m}-#{d}"
defp ga4_date_to_iso(date), do: date

# bounceRate is a ratio; keep as float. Others coerce by header type.
defp parse_metric_value("bounceRate", v), do: to_float(v)
defp parse_metric_value("averageSessionDuration", v), do: to_float(v)
defp parse_metric_value(_name, v), do: to_integer_or_float(v)
```

---

## Pagination

The GA4 runReport endpoint supports pagination via `limit` and `offset` on
`RunReportRequest`. The response includes `rowCount` for the total across all pages.

```elixir
# Add to RunReportRequest if needed
%RunReportRequest{
  ...,
  limit: 10_000,
  offset: 0
}
```

For typical MetricFlow syncs (30-day window, daily dimension), the result set is at most
30 rows per metric combination and does not require pagination.

---

## Scope

The Google OAuth provider (`MetricFlow.Integrations.Providers.Google`) already includes
`https://www.googleapis.com/auth/analytics.edit` in its authorization scope string.
The DataProvider behaviour requires `required_scopes/0` to return the read-only variant:

```elixir
def required_scopes, do: ["https://www.googleapis.com/auth/analytics.readonly"]
```

Note: `analytics.edit` is a superset that includes `analytics.readonly`. Tokens authorized
with `analytics.edit` will work for read-only data fetches.

---

## provider_metadata

Stored on the `Integration` struct under `provider_metadata["property_id"]`. This is set
during the OAuth callback when the user selects or we detect their GA4 property.

Extraction pattern:

```elixir
defp extract_property_id(integration, opts) do
  case Keyword.get(opts, :property_id) ||
       get_in(integration.provider_metadata, ["property_id"]) do
    nil -> {:error, :missing_property_id}
    id  -> {:ok, to_string(id)}
  end
end
```
