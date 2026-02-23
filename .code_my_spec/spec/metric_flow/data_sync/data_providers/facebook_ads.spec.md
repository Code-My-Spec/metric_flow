# MetricFlow.DataSync.DataProviders.FacebookAds

Facebook Ads provider implementation using Facebook Marketing API v18+. Fetches ad campaign performance metrics including impressions, clicks, spend, conversions, cpm, cpc, ctr, and conversion_rate with dimension breakdowns by campaign_name, adset_name, and date. Uses Ad Insights endpoint for data retrieval. Transforms API response to unified metric format. Handles ad account selection, cursor-based pagination, and date range filtering. Stores metrics with provider :facebook_ads.

## Functions

### fetch_metrics/2

Fetches Facebook Ads metrics for an integration using OAuth tokens with configurable date range and ad account selection.

```elixir
@spec fetch_metrics(Integration.t(), keyword()) :: {:ok, list(map())} | {:error, term()}
```

**Process**:
1. Extract access_token from integration struct via MetricFlow.Integrations.Integration
2. Verify token is not expired using Integration.expired?/1
3. Extract ad_account_id from options or integration.provider_metadata
4. Return error :missing_ad_account_id if ad_account_id not found
5. Prepend "act_" to ad_account_id if not already present
6. Extract date_range from options, defaulting to last 30 days
7. Format date_range to YYYY-MM-DD for Facebook API date_preset or time_range
8. Build Facebook Marketing API request URL for Ad Insights endpoint
9. Set base URL to https://graph.facebook.com/v18.0/{ad_account_id}/insights
10. Add access_token as query parameter
11. Add fields parameter with metrics: impressions, clicks, spend, conversions, cpm, cpc, ctr, actions
12. Add fields parameter with dimensions based on breakdown option (campaign_name, adset_name, date_start)
13. Add time_range parameter with since and until dates from date_range option
14. Add level parameter as campaign or adset based on breakdown option
15. Add limit parameter for pagination (default 100)
16. Execute HTTP GET request to Facebook Marketing API
17. Handle 401 unauthorized by returning error :unauthorized
18. Handle 403 forbidden by returning error :insufficient_permissions
19. Handle 400 bad request by returning error with Facebook API error details
20. Handle 190 OAuth error code by returning error :invalid_token
21. Parse successful JSON response body
22. Extract data array from response
23. Transform each data object to unified metric format
24. Extract metric values from Facebook Ads object structure
25. Convert spend from cents to dollars if needed based on currency
26. Extract cpm and cpc values directly
27. Calculate conversion_rate from conversions and impressions if not provided
28. Extract conversion count from actions array by filtering action_type purchase or offsite_conversion
29. Build metric map with metric_type, metric_name, value, recorded_at, metadata, provider
30. Set provider to :facebook_ads for all metrics
31. Extract recorded_at from date_start field or current timestamp
32. Convert dimension values to metadata map with campaign_name, adset_name, ad_account_id
33. Handle pagination by checking for paging.next cursor in response
34. If paging.next exists, extract after cursor and make subsequent request
35. Append results from paginated requests to metrics list
36. Return ok tuple with complete list of metric maps from all pages

**Test Assertions**:
- returns ok tuple with list of metrics for valid integration and options
- extracts access_token from integration struct
- includes access_token as query parameter in request URL
- builds correct Facebook Marketing API URL with ad_account_id
- prepends "act_" to ad_account_id when not present
- does not double-prepend "act_" when already present
- sets ad_account_id from options when provided
- sets ad_account_id from provider_metadata when not in options
- adds fields parameter with impressions, clicks, spend, conversions to request
- adds fields parameter with cpm, cpc, ctr, actions to request
- includes campaign_name and date_start dimensions by default
- includes adset_name dimension when breakdown is :adset
- sets time_range parameter with since and until dates
- defaults to last 30 days when date_range not provided
- formats dates as YYYY-MM-DD in time_range parameter
- sets level parameter to campaign by default
- sets level parameter to adset when breakdown is :adset
- transforms Facebook API response data to unified metric format
- sets provider to :facebook_ads for all metrics
- extracts recorded_at from date_start field value
- converts spend to dollars with appropriate precision
- extracts cpm as cost per thousand impressions
- extracts cpc as cost per click
- extracts ctr as percentage value
- calculates conversion_rate from conversions and impressions when not provided
- extracts conversion count from actions array by action_type
- handles multiple action types in actions array
- filters actions to purchase or offsite_conversion types
- converts dimension values to metadata map with atom keys
- includes campaign_name in metadata
- includes adset_name in metadata when present
- includes ad_account_id in metadata
- converts metric values to appropriate numeric types (integer or float)
- handles spend as float
- returns error :missing_ad_account_id when ad_account_id not in options or metadata
- returns error :unauthorized when token is invalid or expired
- returns error :insufficient_permissions when token lacks ads_read scope
- returns error :invalid_token when API returns OAuth error code 190
- returns error with Facebook API details when request is invalid
- handles network errors gracefully with error tuple
- handles malformed JSON response with error tuple
- handles empty data array with empty list
- handles API rate limiting with error :rate_limited
- respects cursor-based pagination with after parameter
- fetches multiple pages when paging.next present in response
- appends results from all pages to single metrics list
- stops pagination when paging.next is null or absent
- handles campaigns with zero impressions or clicks
- handles null or missing dimension values gracefully
- handles missing actions array by setting conversions to zero
- handles empty actions array by setting conversions to zero
- handles date_start field as ISO 8601 date string

### provider/0

Returns the provider atom identifier for this data provider.

```elixir
@spec provider() :: :facebook_ads
```

**Process**:
1. Return :facebook_ads atom

**Test Assertions**:
- returns :facebook_ads atom
- return value matches Integration.provider enum value

### required_scopes/0

Returns the OAuth scopes required for fetching Facebook Ads metrics.

```elixir
@spec required_scopes() :: list(String.t())
```

**Process**:
1. Return list containing "ads_read" and "ads_management"

**Test Assertions**:
- returns list with ads_read scope
- returns list with ads_management scope
- returned scopes are strings not atoms
- list contains exactly two scopes
- scopes match Facebook Marketing API requirements
- ads_read scope is included for read-only access
- ads_management scope is included for full account access

## Dependencies

- MetricFlow.Integrations.Integration
- HTTPoison
- Jason
