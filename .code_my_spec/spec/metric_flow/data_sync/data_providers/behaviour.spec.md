# MetricFlow.DataSync.DataProviders.Behaviour

Behaviour contract defining callbacks all data provider implementations must implement. Providers implement fetch_metrics/2 to retrieve data from external APIs using OAuth tokens, transform provider-specific data formats to unified metric structures, and return ok tuple with metrics list or error tuple with failure reason. Enables separation of concerns between sync orchestration and provider-specific API integration.

## Functions

### fetch_metrics/2

Retrieves metrics from an external provider API using OAuth tokens, transforming provider-specific data to unified metric format.

```elixir
@spec fetch_metrics(Integration.t(), keyword()) :: {:ok, list(map())} | {:error, term()}
```

**Process**:

1. Extract access_token from integration struct via MetricFlow.Integrations.Integration
2. Verify token is not expired using Integration.expired?/1
3. Extract provider-specific configuration from options or integration.provider_metadata (e.g., property_id, customer_id, account_id)
4. Return error if required provider configuration is missing
5. Extract date_range from options, defaulting to provider-appropriate range (typically last 30 days)
6. Build provider-specific API request with appropriate endpoint and parameters
7. Include OAuth access_token in Authorization header
8. Include any provider-specific headers (e.g., developer-token for Google Ads)
9. Execute HTTP request to provider API endpoint
10. Handle common HTTP error responses (401, 403, 404, 400) with appropriate error atoms
11. Parse successful JSON response body according to provider schema
12. Transform each data point in response to unified metric format
13. Build metric maps with required keys: metric_type, metric_name, value, recorded_at, dimensions, provider
14. Set provider field to appropriate atom matching Integration.provider enum
15. Extract or calculate recorded_at timestamp from response data or current time
16. Convert provider-specific dimension values to metadata map with atom keys
17. Convert metric values to appropriate numeric types (integer or float)
18. Handle pagination when provider returns large result sets with continuation tokens
19. Return ok tuple with complete list of metric maps, or error tuple with failure reason

**Test Assertions**:

- returns ok tuple with list of metric maps for valid integration and options
- extracts access_token from integration struct
- includes OAuth token in Authorization header
- builds correct provider API request URL with required parameters
- extracts provider-specific configuration from options when provided
- extracts provider-specific configuration from provider_metadata as fallback
- defaults to appropriate date range when not provided in options
- transforms provider response data to unified metric format
- each metric map contains required keys: metric_type, metric_name, value, recorded_at, dimensions, provider
- sets provider field to atom matching Integration.provider enum
- extracts or calculates recorded_at timestamp correctly
- converts dimension values to metadata map with atom keys
- converts metric values to appropriate numeric types
- handles provider-specific value transformations (e.g., micros to dollars, percentages)
- returns error when required provider configuration is missing
- returns error :unauthorized when token is invalid or expired
- returns error :insufficient_permissions when token lacks required scopes
- returns error when provider-specific resource not found (e.g., property, customer, account)
- handles network errors gracefully with error tuple
- handles malformed JSON response with error tuple
- handles empty response with empty list
- handles partial API failures appropriately
- respects pagination with continuation tokens when result set is large
- fetches multiple pages when provider indicates more data available
- includes provider-specific metadata in each metric
- handles null or missing values gracefully

### provider/0

Returns the provider atom identifier for this data provider implementation.

```elixir
@spec provider() :: atom()
```

**Process**:

1. Return the provider atom that matches the Integration.provider enum value for this implementation (e.g., :google_analytics, :google_ads, :facebook_ads, :quickbooks)

**Test Assertions**:

- returns atom matching one of Integration.provider enum values
- return value is consistent across all calls
- returned atom matches the provider type this implementation handles

### required_scopes/0

Returns the list of OAuth scope strings required for this provider to fetch metrics successfully.

```elixir
@spec required_scopes() :: list(String.t())
```

**Process**:

1. Return list of OAuth scope URIs or scope identifiers required by this provider's API
2. Scopes should be sufficient for read-only metric data access
3. Format scopes according to provider's OAuth specification (URLs for Google, identifiers for Facebook)

**Test Assertions**:

- returns list of scope strings
- returned scopes are strings not atoms
- list is not empty
- scopes are properly formatted according to provider specification
- scopes match provider API documentation requirements
- scopes are sufficient for read-only metric access
- no write or administrative scopes are included unless required for metric retrieval

## Dependencies

- MetricFlow.Integrations.Integration
