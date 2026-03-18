# MetricFlow.Integrations.GoogleAdsAccounts

Fetches accessible Google Ads customer accounts for a Google Ads OAuth integration. Uses the Google Ads API `customers:listAccessibleCustomers` endpoint to discover which customer accounts the authenticated user can access, then queries each customer's descriptive name via `googleAds:searchStream`. Returns a flat list of customer maps with `:id`, `:name`, and `:account` keys. Falls back gracefully with `{:error, :api_disabled}` when the Google Ads API returns 403 (insufficient permissions), allowing callers to surface a meaningful error. Accepts an `:http_plug` option for dependency injection during tests.

## Functions

### list_customers/2

Lists Google Ads customer accounts accessible to the integration's OAuth token.

```elixir
@spec list_customers(Integration.t(), keyword()) ::
        {:ok, list(map())} | {:error, term()}
```

**Process**:
1. Read `google_ads_developer_token` and `google_ads_login_customer_id` from application config
2. Build request headers using `integration.access_token` as a Bearer token, the developer token, and optionally the login customer ID header when it is non-nil and non-empty
3. Call the private `fetch_accessible_customers/2` function with the headers and opts
4. On success, call `fetch_customer_names/3` for each returned customer ID to resolve descriptive names
5. Return `{:ok, customers}` where each customer is a map with `:id`, `:name`, and `:account` keys
6. On error from `fetch_accessible_customers/2`, propagate the error tuple unchanged

**Test Assertions**:
- returns `{:ok, customers}` with a list of customer maps on a successful API response
- each returned customer map has `:id`, `:name`, and `:account` keys
- sets `:account` to `"Google Ads"` for every customer
- extracts `:id` from the `"resourceNames"` list by stripping the `"customers/"` prefix
- resolves `:name` by querying each customer's `googleAds:searchStream` endpoint
- defaults `:name` to `"Account <id>"` when the searchStream request fails or returns no name
- defaults `:name` to `"Account <id>"` when the descriptive name in the response is blank
- returns `{:error, :unauthorized}` on a 401 response from listAccessibleCustomers
- returns `{:error, :api_disabled}` on a 403 response from listAccessibleCustomers
- returns `{:error, :bad_request}` on an unexpected HTTP status from listAccessibleCustomers
- returns `{:error, {:network_error, message}}` when the listAccessibleCustomers request raises an exception
- returns `{:ok, []}` when `"resourceNames"` is present but empty
- handles a 200 response with a binary JSON body by decoding before extracting customer IDs
- returns `{:ok, []}` when the binary body cannot be decoded (no resource names present)
- accepts an `:http_plug` option for test injection without making real HTTP calls
- injects the `:http_plug` plug for both the listAccessibleCustomers request and each searchStream request
- includes the `developer-token` header in all requests
- includes the `login-customer-id` header when the config value is non-nil and non-empty
- omits the `login-customer-id` header when the config value is nil
- omits the `login-customer-id` header when the config value is an empty string
- extracts `:name` from a list-style searchStream body via batch results
- extracts `:name` from a map-style searchStream body when Req auto-decodes a single object

## Dependencies

- MetricFlow.Integrations.Integration
- Req
- Jason
- Logger
