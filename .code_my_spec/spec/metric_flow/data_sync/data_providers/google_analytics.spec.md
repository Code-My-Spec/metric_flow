# MetricFlow.DataSync.DataProviders.GoogleAnalytics

Google Analytics provider implementation using Google Analytics Data API (GA4). Fetches website traffic metrics including sessions, pageviews, users, bounce_rate, average_session_duration, and new_users with dimension breakdowns by date, source/medium, and page path. Transforms GA4 API response to unified metric format. Handles property selection and date range filtering. Stores metrics with provider :google_analytics.

## Functions

### fetch_metrics/2

Fetches GA4 metrics for an integration using OAuth tokens with configurable date range and property selection.

```elixir
@spec fetch_metrics(Integration.t(), keyword()) :: {:ok, list(map())} | {:error, term()}
```

**Process**:
1. Extract access_token from integration struct via MetricFlow.Integrations.Integration
2. Verify token is not expired using Integration.expired?/1
3. Extract property_id from options or integration.provider_metadata
4. Return error :missing_property_id if property_id not found
5. Extract date_range from options, defaulting to last 30 days
6. Build GA4 Data API request with runReport endpoint
7. Set dateRanges parameter from date_range option
8. Set metrics parameter to sessions, pageviews, users, bounceRate, averageSessionDuration, newUsers
9. Set dimensions parameter based on breakdown option (date, source/medium, page)
10. Include property_id in request path as properties/{property_id}
11. Add OAuth access_token to Authorization header
12. Execute HTTP POST request to GA4 Data API
13. Handle 401 unauthorized by returning error :unauthorized
14. Handle 403 forbidden by returning error :insufficient_permissions
15. Handle 404 not found by returning error :property_not_found
16. Parse successful JSON response body
17. Transform each row in response to unified metric format
18. Build metric map with metric_type, metric_name, value, recorded_at, dimensions, provider
19. Set provider to :google_analytics for all metrics
20. Extract recorded_at from date dimension or current timestamp
21. Convert dimension values to metadata map
22. Return ok tuple with list of metric maps

**Test Assertions**:
- returns ok tuple with list of metrics for valid integration and options
- extracts access_token from integration struct
- includes OAuth token in Authorization header
- builds correct GA4 Data API request URL with property_id
- sets dateRanges parameter from date_range option
- defaults to last 30 days when date_range not provided
- requests sessions, pageviews, users, bounceRate, averageSessionDuration, newUsers metrics
- includes date dimension by default
- includes source and medium dimensions when breakdown is :source
- includes pagePath dimension when breakdown is :page
- transforms GA4 response rows to unified metric format
- sets provider to :google_analytics for all metrics
- extracts recorded_at from date dimension value
- converts dimension values to metadata map with atom keys
- converts metric values to appropriate numeric types (integer or float)
- handles bounceRate as percentage value
- handles averageSessionDuration in seconds
- returns error :missing_property_id when property_id not in options or metadata
- returns error :unauthorized when token is invalid or expired
- returns error :insufficient_permissions when token lacks analytics.readonly scope
- returns error :property_not_found when property_id doesn't exist
- handles network errors gracefully with error tuple
- handles malformed JSON response with error tuple
- handles empty response with empty list
- handles partial API failures with available metrics
- respects pagination with pageToken when result set is large
- fetches multiple pages when nextPageToken present in response

### provider/0

Returns the provider atom identifier for this data provider.

```elixir
@spec provider() :: :google_analytics
```

**Process**:
1. Return :google_analytics atom

**Test Assertions**:
- returns :google_analytics atom
- return value matches Integration.provider enum value

### required_scopes/0

Returns the OAuth scopes required for fetching Google Analytics metrics.

```elixir
@spec required_scopes() :: list(String.t())
```

**Process**:
1. Return list containing "https://www.googleapis.com/auth/analytics.readonly"

**Test Assertions**:
- returns list with analytics.readonly scope
- scope URL is properly formatted
- returned scopes are strings not atoms
- list contains exactly one scope
- scope matches Google Analytics Data API requirements

## Dependencies

- MetricFlow.Integrations.Integration
- HTTPoison
- Jason

