# MetricFlow.Integrations.FacebookAdsAccounts

Fetches accessible Facebook Ad accounts for a Facebook Ads OAuth integration using the Facebook Graph API (`graph.facebook.com`). Queries the `me/adaccounts` endpoint to list ad accounts the authenticated user can access. Returns a flat list of active account maps with `:id`, `:name`, and `:account` keys, filtering out inactive accounts (those without `account_status == 1`). Falls back gracefully with `{:error, :api_disabled}` when the Graph API returns 403 due to insufficient permissions, allowing callers to handle this case explicitly. Accepts an `:http_plug` option for dependency injection during tests.

## Functions

### list_accounts/2

Lists Facebook Ad accounts accessible to the integration's OAuth token by querying the Facebook Graph API `me/adaccounts` endpoint.

```elixir
@spec list_accounts(Integration.t(), keyword()) ::
        {:ok, list(map())} | {:error, term()}
```

**Process**:
1. Build query params with `access_token` from `integration.access_token` and `fields` set to `"name,account_id,account_status"`
2. Assemble Req request options with `:get` method, the Graph API URL, and the query params
3. When `:http_plug` is present in opts, inject it into the Req options as `:plug` for test dependency injection
4. Call `Req.request!/1` with the assembled options inside a try/rescue block
5. On a 200 response with a map body containing a `"data"` key that is a list, pass to account extraction directly
6. On a 200 response with a binary body, JSON-decode it then pass to account extraction
7. On a 200 response with any other body shape, return `{:ok, []}`
8. Return `{:error, :unauthorized}` on a 400 or 401 response
9. Log a warning and return `{:error, :api_disabled}` on a 403 response
10. Log a warning and return `{:error, :bad_request}` on any other HTTP status
11. Rescue any exception, log the error with `Logger.error/1`, and return `{:error, {:network_error, message}}`
12. Account extraction filters accounts to only those where `"account_status"` equals `1`, then maps each to `%{id: account_id, name: name, account: "Facebook Ads"}` using `"account_id"` for `:id` and `"name"` for `:name` (defaulting to `"Ad Account #{account_id}"` when name is absent)
13. Return `{:ok, accounts}` where accounts is the filtered and mapped list

**Test Assertions**:
- returns `{:ok, accounts}` with a list of account maps on a 200 response with valid JSON body
- each returned account map has `:id`, `:name`, and `:account` keys
- extracts `:id` from the `"account_id"` field
- extracts `:name` from the `"name"` field
- sets `:account` to `"Facebook Ads"` for all returned accounts
- filters out accounts where `"account_status"` is not `1`
- returns only active accounts when the response contains a mix of active and inactive accounts
- returns `{:ok, []}` when `"data"` is present but empty
- returns `{:ok, []}` when the response body does not contain a `"data"` key
- defaults `:name` to `"Ad Account #{account_id}"` when the `"name"` field is absent
- returns `{:error, :unauthorized}` on a 400 response
- returns `{:error, :unauthorized}` on a 401 response
- returns `{:error, :api_disabled}` on a 403 response
- returns `{:error, :bad_request}` on an unexpected HTTP status code
- returns `{:error, {:network_error, message}}` when the HTTP request raises an exception
- accepts an `:http_plug` option for test injection without making real HTTP calls
- handles 200 response with binary JSON body by decoding before extracting accounts

## Dependencies

- MetricFlow.Integrations.Integration
- Req
- Jason
- Logger
