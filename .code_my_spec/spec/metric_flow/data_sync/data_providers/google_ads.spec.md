# MetricFlow.DataSync.DataProviders.GoogleAds

Google Ads provider implementation using Google Ads API v16+. Fetches campaign performance metrics including impressions, clicks, cost, conversions, ctr, cpc, and conversion_rate with dimension breakdowns by campaign_name, ad_group_name, and date. Uses GAQL (Google Ads Query Language) for data retrieval. Transforms API response to unified metric format. Handles customer account selection and date range filtering. Stores metrics with provider :google_ads.

## Functions

### fetch_metrics/2

Fetches Google Ads metrics for an integration using OAuth tokens with configurable date range and customer account selection.

```elixir
@spec fetch_metrics(Integration.t(), keyword()) :: {:ok, list(map())} | {:error, term()}
```

**Process**:
1. Extract access_token from integration struct via MetricFlow.Integrations.Integration
2. Verify token is not expired using Integration.expired?/1
3. Extract customer_id from options or integration.provider_metadata
4. Return error :missing_customer_id if customer_id not found
5. Extract date_range from options, defaulting to last 30 days
6. Format date_range to YYYY-MM-DD for GAQL query
7. Build GAQL query string for campaign performance report
8. Set SELECT clause with metrics: impressions, clicks, cost_micros, conversions, ctr, average_cpc, conversions_value
9. Set SELECT clause with dimensions based on breakdown option (campaign.name, ad_group.name, segments.date)
10. Set FROM clause to campaign_performance_report or ad_group_performance_report
11. Set WHERE clause with date range filter using segments.date BETWEEN
12. Set ORDER BY clause to segments.date DESC
13. Include customer_id in request path as customers/{customer_id}/googleAds:searchStream
14. Add OAuth access_token to Authorization header with Bearer prefix
15. Add developer-token header from application config
16. Build request body with GAQL query string
17. Execute HTTP POST request to Google Ads API searchStream endpoint
18. Handle 401 unauthorized by returning error :unauthorized
19. Handle 403 forbidden by returning error :insufficient_permissions
20. Handle 404 not found by returning error :customer_not_found
21. Handle 400 bad request by returning error with GAQL error details
22. Parse successful JSON response body with streaming results
23. Iterate over results array in response
24. Transform each result row to unified metric format
25. Extract metrics from GoogleAdsRow structure
26. Convert cost_micros to dollars by dividing by 1,000,000
27. Extract ctr and average_cpc values directly
28. Build metric map with metric_type, metric_name, value, recorded_at, metadata, provider
29. Set provider to :google_ads for all metrics
30. Extract recorded_at from segments.date or current timestamp
31. Convert dimension values to metadata map with campaign_name, ad_group_name
32. Return ok tuple with list of metric maps

**Test Assertions**:
- returns ok tuple with list of metrics for valid integration and options
- extracts access_token from integration struct
- includes OAuth token in Authorization header with Bearer prefix
- includes developer-token header in request
- builds correct Google Ads API searchStream URL with customer_id
- sets customer_id from options when provided
- sets customer_id from provider_metadata when not in options
- builds valid GAQL query string
- includes impressions, clicks, cost_micros, conversions in SELECT clause
- includes ctr, average_cpc, conversions_value in SELECT clause
- includes campaign.name and segments.date dimensions by default
- includes ad_group.name dimension when breakdown is :ad_group
- sets WHERE clause with date range using segments.date BETWEEN
- defaults to last 30 days when date_range not provided
- formats dates as YYYY-MM-DD in GAQL query
- transforms Google Ads API response rows to unified metric format
- sets provider to :google_ads for all metrics
- extracts recorded_at from segments.date value
- converts cost_micros to dollars by dividing by 1,000,000
- extracts ctr as percentage value
- extracts average_cpc in dollars
- converts dimension values to metadata map with atom keys
- includes campaign_name in metadata
- includes ad_group_name in metadata when present
- converts metric values to appropriate numeric types (integer or float)
- handles conversions_value as float
- returns error :missing_customer_id when customer_id not in options or metadata
- returns error :unauthorized when token is invalid or expired
- returns error :insufficient_permissions when token lacks adwords scope
- returns error :customer_not_found when customer_id doesn't exist or user lacks access
- returns error with GAQL details when query syntax is invalid
- handles network errors gracefully with error tuple
- handles malformed JSON response with error tuple
- handles empty response with empty list
- handles API rate limiting with error :rate_limited
- respects pagination with pageToken when result set is large
- fetches multiple pages when nextPageToken present in response
- includes customer_id in each metric's metadata
- handles campaigns with zero impressions or clicks
- handles null or missing dimension values gracefully

### provider/0

Returns the provider atom identifier for this data provider.

```elixir
@spec provider() :: :google_ads
```

**Process**:
1. Return :google_ads atom

**Test Assertions**:
- returns :google_ads atom
- return value matches Integration.provider enum value

### required_scopes/0

Returns the OAuth scopes required for fetching Google Ads metrics.

```elixir
@spec required_scopes() :: list(String.t())
```

**Process**:
1. Return list containing "https://www.googleapis.com/auth/adwords"

**Test Assertions**:
- returns list with adwords scope
- scope URL is properly formatted
- returned scopes are strings not atoms
- list contains exactly one scope
- scope matches Google Ads API requirements

## Dependencies

- MetricFlow.Integrations.Integration
- HTTPoison
- Jason
