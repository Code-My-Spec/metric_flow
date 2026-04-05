# MetricFlow.DataSync.DataProviders.GoogleBusiness

Google Business Profile data provider implementing the DataProviders.Behaviour contract. Fetches two categories of data per selected location: performance metrics from the Business Profile Performance API v1 (impressions, conversations, direction requests, call clicks, website clicks, bookings, food orders, food menu clicks) and reviews from the My Business v4 API (individual review records with star ratings, reviewer info, and comments). Iterates all configured locations from integration provider_metadata and returns a flat list of unified metric maps. Accepts an `http_plug` option for dependency injection during tests.

## Functions

### fetch_metrics/2

Fetches GBP performance metrics and reviews for all configured locations using OAuth tokens with configurable date range.

```elixir
@spec fetch_metrics(Integration.t(), keyword()) :: {:ok, list(map())} | {:error, term()}
```

**Process**:
1. Check integration token is not expired using Integration.expired?/1; return {:error, :unauthorized} if expired
2. Resolve location IDs from integration.provider_metadata["included_locations"]
3. Return {:error, :no_locations_configured} if included_locations is missing or empty
4. Extract date_range from options, defaulting to last 548 days ending yesterday
5. For each location_id, fetch performance metrics and review metrics
6. Fetch performance metrics: extract location path from "accounts/X/locations/Y" to "locations/Y"
7. Build Performance API URL with dailyMetrics query params and date range fields
8. Execute GET request to Business Profile Performance API with Bearer token Authorization header
9. Parse performance response: extract multiDailyMetricTimeSeries entries and flatten to dated data points
10. Transform each data point to unified metric map with metric_type "business_profile" and normalized metric_name
11. Fetch reviews: paginate through My Business v4 reviews endpoint up to 50 pages of 100 reviews each
12. For each page, execute GET request with Bearer token Authorization header
13. Handle review pagination using nextPageToken from response body
14. For each review, emit two metric maps: one for review_rating with star value and one for review_count with value 1.0
15. Set provider to :google_business for all metrics
16. Combine performance and review metrics for each location and flatten to a single list
17. Return {:ok, metrics} with all metrics from all locations
18. On Performance API failure, log warning and return empty list for that location (partial success)
19. On Reviews API failure, log warning and return empty list for that location (partial success)

**Test Assertions**:
- returns ok tuple with list of metrics for valid integration with locations configured
- returns error :unauthorized when integration token is expired
- returns error :no_locations_configured when included_locations is missing from provider_metadata
- returns error :no_locations_configured when included_locations is an empty list
- includes OAuth token in Authorization header for performance API request
- includes OAuth token in Authorization header for reviews API request
- builds performance URL with correct location path stripping accounts prefix
- builds performance URL with all 11 daily metric query params
- sets date range from date_range option in performance API URL
- defaults to last 548 days ending yesterday when date_range not provided
- returns metrics from multiple locations when integration has multiple location IDs
- transforms performance response to unified metric format with metric_type "business_profile"
- sets provider to :google_business for all performance metrics
- normalizes metric names by downcasing and stripping "business_" prefix
- extracts recorded_at from date map fields year/month/day in performance response
- converts performance values to float
- sets location_id and date in dimensions for performance metrics
- emits review_rating metric with float star value (0.0-5.0) for each review
- emits review_count metric with value 1.0 for each review
- sets metric_type "reviews" for review metrics
- sets provider to :google_business for all review metrics
- includes location_id, review_id, reviewer, and comment in review_rating dimensions
- includes location_id and date in review_count dimensions
- parses star rating ONE as 1, TWO as 2, THREE as 3, FOUR as 4, FIVE as 5
- uses 0 for unrecognized or unspecified star rating
- paginates reviews using nextPageToken up to 50 pages
- stops pagination when nextPageToken is absent in response
- handles 401 response from reviews API with error :unauthorized
- handles 403 response from reviews API with error :insufficient_permissions
- handles 404 response from reviews API with error :location_not_found
- handles network errors from performance API by logging warning and returning empty list for that location
- handles network errors from reviews API by logging warning and returning empty list for that location
- handles empty reviews response with empty list

### provider/0

Returns the provider atom identifier for this data provider.

```elixir
@spec provider() :: :google_business
```

**Process**:
1. Return :google_business atom

**Test Assertions**:
- returns :google_business atom
- return value matches Integration.provider enum value

### required_scopes/0

Returns the OAuth scopes required for accessing Google Business Profile data.

```elixir
@spec required_scopes() :: list(String.t())
```

**Process**:
1. Return list containing "https://www.googleapis.com/auth/business.manage"

**Test Assertions**:
- returns list with business.manage scope
- scope URL is properly formatted
- returned scopes are strings not atoms
- list contains exactly one scope
- scope matches Google Business Profile API requirements

## Dependencies

- MetricFlow.Integrations.Integration
- Req
- Jason
- Logger
