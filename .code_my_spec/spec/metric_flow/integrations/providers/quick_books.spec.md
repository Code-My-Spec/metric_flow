# MetricFlow.Integrations.Providers.QuickBooks

QuickBooks Online OAuth provider implementation using Assent.Strategy.OAuth2. Configures OAuth with the `com.intuit.quickbooks.accounting` scope using the Intuit OAuth 2.0 endpoints. Normalizes QuickBooks user data to the domain model including provider_user_id, email, name, username, avatar_url, and realm_id for the connected company.

## Delegates

None.

## Functions

### config/0

Returns the Assent strategy configuration keyword list for QuickBooks OAuth with required credentials, redirect URI, Intuit base URL, authorization and token endpoints, auth method, and authorization parameters including the accounting scope.

```elixir
@spec config() :: Keyword.t()
```

**Process**:
1. Fetch `:quickbooks_client_id` from application config under `:metric_flow` using `Application.fetch_env!/2`
2. Fetch `:quickbooks_client_secret` from application config under `:metric_flow` using `Application.fetch_env!/2`
3. Build redirect URI by calling the private `build_redirect_uri/0` helper, which concatenates `MetricFlowWeb.Endpoint.url()` with `"/integrations/oauth/callback/quickbooks"`
4. Log configuration values at debug level (client_id value, whether client_secret is set, redirect_uri value)
5. Return keyword list with the following keys:
   - `client_id`: fetched from application config
   - `client_secret`: fetched from application config
   - `redirect_uri`: built from endpoint URL
   - `base_url`: `"https://oauth.platform.intuit.com"`
   - `authorize_url`: `"https://appcenter.intuit.com/connect/oauth2"`
   - `token_url`: `"https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer"`
   - `auth_method`: `:client_secret_basic`
   - `authorization_params`: `[scope: "com.intuit.quickbooks.accounting"]`

**Test Assertions**:
- returns a keyword list with all required OAuth configuration keys
- includes client_id from application config
- includes client_secret from application config
- includes redirect_uri built from the endpoint URL and the callback path
- includes base_url pointing to the Intuit OAuth platform
- includes authorize_url pointing to the Intuit AppCenter OAuth endpoint
- includes token_url pointing to the Intuit OAuth token endpoint
- sets auth_method to :client_secret_basic
- includes authorization_params with the QuickBooks accounting scope
- raises ArgumentError when :quickbooks_client_id is not configured
- raises ArgumentError when :quickbooks_client_secret is not configured

### strategy/0

Returns the Assent strategy module to use for the QuickBooks OAuth flow.

```elixir
@spec strategy() :: module()
```

**Process**:
1. Return the `Assent.Strategy.OAuth2` module atom

**Test Assertions**:
- returns Assent.Strategy.OAuth2

### normalize_user/1

Transforms QuickBooks user data from the OAuth2 token response into the application domain model. QuickBooks OAuth2 token responses include a `realmId` field identifying the connected company. The `sub` claim is mandatory; all other fields are optional.

```elixir
@spec normalize_user(user_data :: map()) ::
        {:ok, map()}
        | {:error, :invalid_user_data}
        | {:error, :missing_provider_user_id}
        | {:error, :invalid_provider_user_id}
```

**Process**:
1. Guard clause matches non-map input and returns `{:error, :invalid_user_data}`
2. Extract `provider_user_id` from the `"sub"` field using the private `extract_provider_user_id/1` helper
3. Return the error tuple from `extract_provider_user_id/1` if extraction fails
4. Extract `email` from the `"email"` field (may be nil if absent)
5. Extract `name` from the `"name"` field, falling back to `"givenName"` when `"name"` is absent or nil
6. Set `username` to the extracted email value
7. Set `avatar_url` to `nil` (QuickBooks does not provide avatar URLs)
8. Extract `realm_id` from the `"realmId"` field identifying the connected QuickBooks company (may be nil)
9. Return `{:ok, normalized_map}` with atom keys

**Test Assertions**:
- returns ok map with normalized user data for valid QuickBooks user data
- extracts provider_user_id from the sub field
- accepts a string sub value as-is
- converts an integer sub value to string
- extracts email from the email field
- extracts name from the name field
- falls back to givenName when name is absent
- sets username to the email value
- sets avatar_url to nil
- extracts realm_id from the realmId field
- handles missing optional fields gracefully returning nil for each
- handles minimal user data containing only the sub field
- returns error missing_provider_user_id when sub is nil
- returns error missing_provider_user_id when sub field is absent
- returns error missing_provider_user_id for an empty map
- returns error invalid_provider_user_id when sub is a non-string non-integer type
- returns error invalid_user_data when input is not a map
- normalized map uses only atom keys

### revoke_token/1

Revokes an access or refresh token using the Intuit OAuth revocation endpoint, authenticating with Basic Auth built from client_id and client_secret. Uses Erlang's `:httpc` HTTP client directly because the Intuit revocation endpoint returns plain text rather than JSON, bypassing Assent's JSON-decoding layer.

```elixir
@spec revoke_token(String.t()) :: :ok | {:error, term()}
```

**Process**:
1. Fetch `:quickbooks_client_id` from application config under `:metric_flow` using `Application.fetch_env!/2`
2. Fetch `:quickbooks_client_secret` from application config under `:metric_flow` using `Application.fetch_env!/2`
3. Build Basic Auth credentials by Base64-encoding the string `"client_id:client_secret"` using `Base.encode64/1`
4. Build request headers as charlists: `Authorization: Basic <credentials>`, `Accept: application/json`, `Content-Type: application/json`
5. Encode request body as JSON `{"token": "<token>"}` using `Jason.encode!/1`
6. POST to `"https://developer.api.intuit.com/v2/oauth2/tokens/revoke"` using `:httpc.request/4` with the charlist URL and headers
7. On HTTP 200 response, log success at info level and return `:ok`
8. On non-200 HTTP response, log warning with status and body, return `{:error, {:revocation_failed, status}}`
9. On request failure, log warning with reason, return `{:error, reason}`

**Test Assertions**:
- returns :ok when the revocation endpoint responds with HTTP 200
- returns error revocation_failed when the endpoint responds with a non-200 status
- returns error reason when the HTTP request fails due to a network or transport error
- sends an Authorization header with Basic base64 encoded credentials
- sends the token in the request body as a JSON-encoded object with a token key
- posts to the Intuit OAuth revocation endpoint

## Dependencies

- Assent.Strategy.OAuth2
- Logger
- Application
- Jason
- MetricFlowWeb.Endpoint
