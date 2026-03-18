# MetricFlow.Integrations.QuickBooksAccounts

Fetches income accounts from the QuickBooks Chart of Accounts API for a QuickBooks OAuth integration. Queries the QuickBooks Online REST API for accounts with `AccountType = 'Income'` so users can select which income account to track credits and debits from for correlation analysis. Returns a flat list of account maps with `:id`, `:name`, and `:account` keys. Requires a `realm_id` in the integration's `provider_metadata` to identify the connected QuickBooks company. Falls back gracefully with `{:error, :api_disabled}` when the API returns 403, and with `{:error, :missing_realm_id}` when the integration has no realm_id. Accepts an `:http_plug` option for dependency injection during tests.

## Functions

### list_income_accounts/2

Lists income accounts accessible to the integration's OAuth token by querying the QuickBooks Online Chart of Accounts API.

```elixir
@spec list_income_accounts(Integration.t(), keyword()) ::
        {:ok, list(map())} | {:error, term()}
```

**Process**:
1. Extract `realm_id` from `integration.provider_metadata["realm_id"]`
2. Return `{:error, :missing_realm_id}` immediately if `realm_id` is nil or absent
3. Build the QuickBooks SQL query: `"SELECT * FROM Account WHERE AccountType = 'Income' MAXRESULTS 100"`
4. Assemble the request URL from the configured base URL, `realm_id`, and the `/query` path segment
5. Build request options with `:get` method, the query URL, query params `[{"query", query}]`, and an `Authorization: Bearer` header plus `Accept: application/json`
6. When `:http_plug` is present in opts, inject it into the Req options as `:plug` for test dependency injection
7. Call `Req.request!/1` with the assembled options inside a try/rescue block
8. On a 200 response with a map body, pass to account extraction directly
9. On a 200 response with a binary body, JSON-decode it then pass to account extraction
10. Return `{:error, :malformed_response}` when binary body cannot be decoded as JSON
11. Return `{:error, :unauthorized}` on a 401 response
12. Log a warning and return `{:error, :api_disabled}` on a 403 response
13. Log a warning and return `{:error, :bad_request}` on any other HTTP status
14. Rescue any exception, log the error with `Logger.error/1`, and return `{:error, {:network_error, message}}`
15. Account extraction reads the `"QueryResponse" -> "Account"` path from the response body; for each account map it produces `%{id: id, name: name, account: fully_qualified_name}` where `:id` is `"Id"` coerced to string, `:name` is `"Name"` (defaulting to `"Unknown Account"`), and `:account` is `"FullyQualifiedName"` falling back to `"Name"` then `""`
16. Return `{:ok, accounts}` where accounts is the flat list of mapped account maps, or `{:ok, []}` when the `"Account"` key is absent

**Test Assertions**:
- returns `{:ok, accounts}` with a list of account maps on a 200 response with valid JSON body
- each returned account map has `:id`, `:name`, and `:account` keys
- extracts `:id` from the `"Id"` field as a string
- extracts `:name` from the `"Name"` field
- extracts `:account` from the `"FullyQualifiedName"` field
- falls back to `"Name"` for `:account` when `"FullyQualifiedName"` is absent
- defaults `:name` to `"Unknown Account"` when the `"Name"` field is absent
- returns `{:ok, []}` when `"Account"` key is absent in the QueryResponse
- returns `{:ok, []}` when `"QueryResponse"` key is absent in the response body
- returns `{:error, :missing_realm_id}` when `provider_metadata` has no `"realm_id"` key
- returns `{:error, :missing_realm_id}` when `provider_metadata` is nil
- returns `{:error, :unauthorized}` on a 401 response
- returns `{:error, :api_disabled}` on a 403 response
- returns `{:error, :bad_request}` on an unexpected HTTP status code
- returns `{:error, :malformed_response}` on a 200 response with a non-JSON binary body
- returns `{:error, {:network_error, message}}` when the HTTP request raises an exception
- accepts an `:http_plug` option for test injection without making real HTTP calls
- handles 200 response with binary JSON body by decoding before extracting accounts

## Dependencies

- MetricFlow.Integrations.Integration
- Req
- Jason
- Logger
