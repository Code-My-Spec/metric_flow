# MetricFlow.DataSync.DataProviders.GoogleSearchConsole

Google Search Console data provider implementing the DataProviders.Behaviour contract. Fetches search performance metrics from the Search Console API (Webmasters v3 searchAnalytics/query endpoint), including clicks, impressions, CTR, and average position. Queries are scoped to a verified site URL and segmented by date dimension only. Paginates results using offset-based row fetching up to a configurable maximum number of pages. Transforms API rows to the unified metric format with provider :google_search_console.

## Type

module

## Functions

### fetch_metrics/2

Fetches Search Console metrics for an integration, paginating through all available results within the configured date range.

```elixir
@spec fetch_metrics(Integration.t(), keyword()) :: {:ok, list(map())} | {:error, term()}
```

**Process**:
1. Check integration token is not expired using Integration.expired?/1; return {:error, :unauthorized} if expired
2. Resolve site_url from opts[:site_url] or integration.provider_metadata["site_url"]; return {:error, :missing_site_url} if absent or empty
3. Resolve date_range from opts[:date_range] tuple; default to last 548 days ending yesterday when not provided
4. Begin paginated fetch loop starting at offset 0 with accumulated results empty and max_pages countdown set to 10
5. Build request URL by URL-encoding the site_url and constructing path: /webmasters/v3/sites/{encoded_site}/searchAnalytics/query
6. Build JSON request body with startDate, endDate (ISO8601), dimensions ["date"], rowLimit 25000, startRow offset
7. Add Authorization header with Bearer token from integration.access_token
8. Apply http_plug option to request if provided for test injection
9. Execute HTTP POST request using Req; catch exceptions and return {:error, {:network_error, message}}
10. Handle 200 response with rows list: transform rows and continue pagination if row count equals 25000 and pages remain
11. Handle 200 response with rows list smaller than 25000 or missing rows key: transform rows and return accumulated results
12. Handle 200 response with binary body: attempt JSON decode, extract rows or return empty
13. Handle 401 response: return {:error, :unauthorized}
14. Handle 403 response: return {:error, :insufficient_permissions}
15. Handle 404 response: return {:error, :site_not_found}
16. Handle other non-200 responses: log warning and return {:error, :bad_request}
17. For each row, extract date string from keys[0] and parse to DateTime at midnight UTC
18. Emit one metric map per metric name (clicks, impressions, ctr, position) present in the row
19. Set metric_type to "search", provider to :google_search_console, dimensions to %{date: date_str}
20. Round ctr to 4 decimal places and position to 2 decimal places; keep clicks and impressions as integers
21. Return {:ok, accumulated_metrics} when all pages are collected or page limit is reached

**Test Assertions**:
- returns ok tuple with list of metrics for valid integration and site_url option
- resolves site_url from opts when provided
- resolves site_url from integration.provider_metadata when not in opts
- returns error :missing_site_url when site_url is absent from both opts and metadata
- returns error :missing_site_url when site_url is an empty string
- returns error :unauthorized when integration token is expired
- includes Bearer token in Authorization header
- builds correct searchAnalytics/query URL with URL-encoded site_url
- posts JSON body with startDate, endDate, dimensions ["date"], rowLimit, startRow
- defaults date range to last 548 days when date_range not provided
- uses date_range from opts when provided
- formats dates as YYYY-MM-DD in request body
- transforms API rows to list of metric maps
- emits one metric map per metric name per row (clicks, impressions, ctr, position)
- sets metric_type to "search" for all metrics
- sets provider to :google_search_console for all metrics
- sets recorded_at to midnight UTC DateTime from row date key
- sets dimensions map with date key on each metric
- rounds ctr to 4 decimal places
- rounds position to 2 decimal places
- returns integer values for clicks and impressions
- handles empty rows list with empty accumulated result
- handles 200 response with no rows key as empty result
- paginates by incrementing startRow when full page of 25000 rows returned
- stops pagination when page count reaches maximum of 10 pages
- returns error :unauthorized on 401 response
- returns error :insufficient_permissions on 403 response
- returns error :site_not_found on 404 response
- returns error :bad_request on non-200 non-handled status
- handles malformed JSON binary body with error :malformed_response
- handles network exceptions with error {:network_error, message}
- accepts http_plug option for test injection

### provider/0

Returns the provider atom identifier for this data provider.

```elixir
@spec provider() :: :google_search_console
```

**Process**:
1. Return :google_search_console atom

**Test Assertions**:
- returns :google_search_console atom
- return value matches a valid Integration provider atom

### required_scopes/0

Returns the OAuth scopes required for fetching Google Search Console metrics.

```elixir
@spec required_scopes() :: list(String.t())
```

**Process**:
1. Return list containing "https://www.googleapis.com/auth/webmasters.readonly"

**Test Assertions**:
- returns list containing the webmasters.readonly scope URL
- returned scopes are strings not atoms
- list contains exactly one scope
- scope URL starts with https://

## Dependencies

- MetricFlow.Integrations.Integration
- Req
- Jason
- Logger
