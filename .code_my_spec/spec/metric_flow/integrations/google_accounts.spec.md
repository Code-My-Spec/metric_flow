# MetricFlow.Integrations.GoogleAccounts

Fetches available GA4 properties for a Google OAuth integration using the Google Analytics Admin API (`analyticsadmin.googleapis.com`). Lists account summaries and their GA4 properties from the API response. Returns a flat list of property maps with `:id`, `:name`, and `:account` keys. Falls back gracefully with `{:error, :api_disabled}` when the Admin API is not enabled in the GCP project (403/SERVICE_DISABLED), allowing callers to offer manual property ID entry. Accepts an `:http_plug` option for dependency injection during tests.

## Functions

### list_ga4_properties/2

Lists GA4 properties accessible to the integration's OAuth token by querying the Google Analytics Admin API account summaries endpoint.

```elixir
@spec list_ga4_properties(Integration.t(), keyword()) ::
        {:ok, list(map())} | {:error, term()}
```

**Process**:
1. Build an Authorization header using `integration.access_token` as a Bearer token
2. Assemble Req request options with `:get` method, the Admin API URL, and the Authorization header
3. When `:http_plug` is present in opts, inject it into the Req options as `:plug` for test dependency injection
4. Call `Req.request!/1` with the assembled options inside a try/rescue block
5. On a 200 response with a map body, pass to property extraction directly
6. On a 200 response with a binary body, JSON-decode it then pass to property extraction
7. Return `{:error, :malformed_response}` when binary body cannot be decoded as JSON
8. Return `{:error, :unauthorized}` on a 401 response
9. Log a warning and return `{:error, :api_disabled}` on a 403 response
10. Log a warning and return `{:error, :bad_request}` on any other HTTP status
11. Rescue any exception, log the error with `Logger.error/1`, and return `{:error, {:network_error, message}}`
12. Property extraction flattens all account summaries: for each account, take its `"displayName"` (defaulting to `"Unknown Account"`) and each property's `"property"` and `"displayName"` (defaulting to `"Unnamed Property"`) into a map `%{id: _, name: _, account: _}`
13. Return `{:ok, properties}` where properties is the flat list of property maps

**Test Assertions**:
- returns `{:ok, properties}` with a list of property maps on a 200 response with valid JSON body
- each returned property map has `:id`, `:name`, and `:account` keys
- extracts `:id` from the property `"property"` field
- extracts `:name` from the property `"displayName"` field
- extracts `:account` from the account summary `"displayName"` field
- flattens properties across multiple account summaries into a single list
- returns `{:ok, []}` when `"accountSummaries"` is present but empty
- returns `{:ok, []}` when a summary has no `"propertySummaries"` key
- defaults `:name` to `"Unnamed Property"` when property displayName is absent
- defaults `:account` to `"Unknown Account"` when account summary displayName is absent
- returns `{:error, :api_disabled}` on a 403 response
- returns `{:error, :unauthorized}` on a 401 response
- returns `{:error, :bad_request}` on an unexpected HTTP status code
- returns `{:error, :malformed_response}` on a 200 response with a non-JSON binary body
- returns `{:error, {:network_error, message}}` when the HTTP request raises an exception
- accepts an `:http_plug` option for test injection without making real HTTP calls
- handles 200 response with binary JSON body by decoding before extracting properties
- handles missing `"accountSummaries"` key in response body by returning empty list

## Dependencies

- MetricFlow.Integrations.Integration
- Req
- Jason
- Logger
