# MetricFlow.Integrations.Providers.Codemyspec

CodeMySpec OAuth provider implementation using Assent.Strategy.OAuth2. Connects to the CodeMySpec platform for issue reporting and feedback. Configures OAuth with read/write scope using CodeMySpec's OAuth2 endpoints. Normalizes user data to the application domain model using the user's email as both name and username.

## Functions

### config/0

Returns Assent strategy configuration for CodeMySpec OAuth with required credentials, redirect URI, and authorization parameters.

```elixir
@spec config() :: Keyword.t()
```

**Process**:
1. Fetch codemyspec_url from application config
2. Fetch codemyspec_client_id from application config
3. Fetch codemyspec_client_secret from application config
4. Build redirect URI from endpoint URL and callback path
5. Return keyword list with client_id, client_secret, redirect_uri, base_url, authorize_url, token_url, user_url, auth_method, and authorization_params
6. Authorization params include scope with "read write"

**Test Assertions**:
- returns keyword list with required OAuth configuration keys
- includes client_id from application config
- includes redirect_uri pointing to the codemyspec callback path
- includes authorize_url and token_url derived from base_url
- includes auth_method of :client_secret_post
- raises when codemyspec_url is not configured

### strategy/0

Returns the Assent.Strategy.OAuth2 module to use for OAuth flow.

```elixir
@spec strategy() :: module()
```

**Process**:
1. Return Assent.Strategy.OAuth2 module atom

**Test Assertions**:
- returns Assent.Strategy.OAuth2 module

### normalize_user/1

Transforms CodeMySpec user data into the application domain model with provider_user_id, email, name, username, and avatar_url.

```elixir
@spec normalize_user(map()) :: {:ok, map()} | {:error, :invalid_user_data}
```

**Process**:
1. Guard clause returns error for non-map input
2. Extract provider_user_id from "id" field, converted to string
3. Extract email from "email" field
4. Use email as both name and username
5. Set avatar_url to nil
6. Return ok tuple with normalized map

**Test Assertions**:
- returns ok tuple with normalized user data for valid input
- extracts provider_user_id from "id" field as string
- uses email as name and username
- sets avatar_url to nil
- returns error :invalid_user_data when input is not a map

## Dependencies

- Assent.Strategy.OAuth2
- Logger
- Application
- MetricFlowWeb.Endpoint
