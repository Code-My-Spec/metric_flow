# MetricFlow.Integrations.GoogleSearchConsoleSites

Fetches verified sites from the Google Search Console API using the Webmasters API v3 sites endpoint. Lists all sites the authenticated user has access to in Search Console. Returns a flat list of site maps with `:id`, `:name`, and `:account` keys where `:id` is the raw `siteUrl`, `:name` is the hostname extracted from the URL (falling back to the raw URL when parsing yields no host), and `:account` is always `"Google Search Console"`. Falls back gracefully with `{:error, :api_disabled}` on a 403 response, which indicates the Search Console API is not enabled or the token lacks sufficient permissions. Accepts an `:http_plug` option for dependency injection during tests.

## Functions

### list_sites/2

Lists Search Console sites accessible to the integration's OAuth token by querying the Webmasters API v3 sites endpoint.

```elixir
@spec list_sites(Integration.t(), keyword()) ::
        {:ok, list(map())} | {:error, term()}
```

**Process**:
1. Build an Authorization header using `integration.access_token` as a Bearer token
2. Assemble Req request options with `:get` method, the Webmasters API URL, and the Authorization header
3. When `:http_plug` is present in opts, inject it into the Req options as `:plug` for test dependency injection
4. Call `Req.request!/1` with the assembled options inside a try/rescue block
5. On a 200 response with a map body, pass to site extraction directly
6. On a 200 response with a binary body, JSON-decode it then pass to site extraction
7. Return `{:error, :malformed_response}` when binary body cannot be decoded as JSON
8. Return `{:error, :unauthorized}` on a 401 response
9. Log a warning and return `{:error, :api_disabled}` on a 403 response
10. Log a warning and return `{:error, :bad_request}` on any other HTTP status
11. Rescue any exception, log the error with `Logger.error/1`, and return `{:error, {:network_error, message}}`
12. Site extraction maps each entry in `"siteEntry"`: take `"siteUrl"` as `:id`, parse the URL host as `:name` (falling back to the raw `siteUrl` when host is nil or absent), and hardcode `:account` to `"Google Search Console"`
13. Return `{:ok, sites}` where sites is the list of site maps
14. Return `{:ok, []}` when the response body lacks a `"siteEntry"` key or when the key is present but not a list

**Test Assertions**:
- returns `{:ok, sites}` with a list of site maps on a 200 response with valid JSON body
- each returned site map has `:id`, `:name`, and `:account` keys
- extracts `:id` from the `"siteUrl"` field
- extracts `:name` as the hostname portion of `"siteUrl"`
- sets `:account` to `"Google Search Console"` for every site
- returns `{:ok, []}` when `"siteEntry"` is present but empty
- returns `{:ok, []}` when the response body has no `"siteEntry"` key
- falls back `:name` to the raw `siteUrl` when hostname cannot be parsed from the URL
- returns `{:error, :api_disabled}` on a 403 response
- returns `{:error, :unauthorized}` on a 401 response
- returns `{:error, :bad_request}` on an unexpected HTTP status code
- returns `{:error, :malformed_response}` on a 200 response with a non-JSON binary body
- returns `{:error, {:network_error, message}}` when the HTTP request raises an exception
- accepts an `:http_plug` option for test injection without making real HTTP calls
- handles 200 response with binary JSON body by decoding before extracting sites

## Dependencies

- MetricFlow.Integrations.Integration
- Req
- Jason
- Logger
