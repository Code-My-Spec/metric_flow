# MetricFlow.Integrations.Providers.QuickBooks

QuickBooks Online OAuth provider implementation using Assent.Strategy.OAuth2. Configures OAuth with the `com.intuit.quickbooks.accounting` scope using the Intuit OAuth 2.0 endpoints. Normalizes QuickBooks user data to the domain model including provider_user_id, email, name, username, avatar_url, and realm_id for the connected company.

## Functions

### config/0

Returns Assent strategy configuration for QuickBooks OAuth with required credentials, redirect URI, base URL, authorization and token endpoints, auth method, and authorization parameters including the accounting scope.

```elixir
@spec config() :: Keyword.t()
```

**Process**:
1. Fetch quickbooks_client_id from application config using Application.fetch_env!/2
2. Fetch quickbooks_client_secret from application config using Application.fetch_env!/2
3. Build redirect URI by calling build_redirect_uri/0 helper
4. Log configuration values for debugging (client_id, client_secret presence, redirect_uri)
5. Return keyword list with client_id, client_secret, redirect_uri, base_url, authorize_url, token_url, auth_method, and authorization_params
6. Set base_url to "https://oauth.platform.intuit.com"
7. Set authorize_url to "https://appcenter.intuit.com/connect/oauth2"
8. Set token_url to "https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer"
9. Set auth_method to :client_secret_basic
10. Authorization params include scope "com.intuit.quickbooks.accounting"

**Test Assertions**:
- returns keyword list with required OAuth configuration keys
- includes client_id from application config
- includes client_secret from application config
- includes redirect_uri built from endpoint URL
- includes base_url pointing to Intuit OAuth platform
- includes authorize_url pointing to Intuit app center
- includes token_url pointing to Intuit token endpoint
- sets auth_method to :client_secret_basic
- includes authorization_params with com.intuit.quickbooks.accounting scope
- raises ArgumentError when quickbooks_client_id is not configured
- raises ArgumentError when quickbooks_client_secret is not configured

### strategy/0

Returns the Assent.Strategy.OAuth2 module to use for the QuickBooks OAuth flow.

```elixir
@spec strategy() :: module()
```

**Process**:
1. Return Assent.Strategy.OAuth2 module atom

**Test Assertions**:
- returns Assent.Strategy.OAuth2 module

### normalize_user/1

Transforms QuickBooks user data from the OAuth2 token response into the application domain model with provider_user_id, email, name, username, avatar_url, and realm_id for the connected company.

```elixir
@spec normalize_user(user_data :: map()) ::
        {:ok, map()}
        | {:error, :invalid_user_data}
        | {:error, :missing_provider_user_id}
        | {:error, :invalid_provider_user_id}
```

**Process**:
1. Guard clause returns error for non-map input
2. Extract provider_user_id from "sub" field using extract_provider_user_id/1
3. Return error tuple if provider_user_id extraction fails
4. Build normalized user map with atom keys
5. Set provider_user_id from extracted value
6. Extract email from "email" field
7. Extract name from "name" field, falling back to "givenName" if absent
8. Use email as username
9. Set avatar_url to nil (QuickBooks does not provide avatar URLs)
10. Extract realm_id from "realmId" field identifying the connected company
11. Return ok tuple with normalized map

**Test Assertions**:
- returns ok tuple with normalized user data for valid QuickBooks user data
- extracts provider_user_id from "sub" field
- extracts email from "email" field
- extracts name from "name" field
- falls back to "givenName" when "name" is absent
- uses email as username
- sets avatar_url to nil
- extracts realm_id from "realmId" field
- handles missing optional fields (name, givenName, email, realmId) gracefully
- returns error :missing_provider_user_id when "sub" is nil
- returns error :invalid_provider_user_id when "sub" is invalid type
- returns error :invalid_user_data when input is not a map
- converts integer provider_user_id to string
- accepts string provider_user_id as-is
- handles missing "sub" field
- handles minimal user data with only required fields
- normalized data has correct key types (all atoms)
- returns error tuple for empty map

### revoke_token/1

Revokes an access or refresh token using the Intuit OAuth revocation endpoint with Basic Auth (client_id:client_secret).

```elixir
@spec revoke_token(String.t()) :: :ok | {:error, term()}
```

**Process**:
1. Fetch quickbooks_client_id from application config using Application.fetch_env!/2
2. Fetch quickbooks_client_secret from application config using Application.fetch_env!/2
3. Build Basic Auth credentials by Base64-encoding "client_id:client_secret"
4. Set Authorization, Accept, and Content-Type headers
5. Encode request body as JSON with the token to revoke
6. POST to "https://developer.api.intuit.com/v2/oauth2/tokens/revoke" using Assent.Strategy.http_request/5
7. Return :ok on HTTP 200 response
8. Return {:error, {:revocation_failed, status}} for non-200 HTTP responses
9. Return {:error, reason} for network or request errors

**Test Assertions**:
- returns :ok when revocation endpoint responds with 200
- returns error tuple when endpoint responds with non-200 status
- returns error tuple when request fails due to network error
- sends Authorization header with Base64-encoded client_id:client_secret
- sends token in request body as JSON
- posts to the correct Intuit revocation URL

## Dependencies

- Assent.Strategy.OAuth2
- Logger
- Application
- Jason
- MetricFlowWeb.Endpoint
