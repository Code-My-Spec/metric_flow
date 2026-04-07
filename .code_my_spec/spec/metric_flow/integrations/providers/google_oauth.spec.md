# MetricFlow.Integrations.Providers.GoogleOauth

Google OAuth provider implementation using Assent.Strategy.OAuth2. Configures OAuth with Google credentials and the "read" scope. Normalizes Google user data to the application domain model.

## Type

module

## Delegates

None

## Functions

### config/0

Returns Assent strategy configuration for Google OAuth with required credentials, redirect URI, and authorization parameters.

```elixir
@spec config() :: Keyword.t()
```

**Process**:
1. Fetch google_oauth_client_id from application config
2. Fetch google_oauth_client_secret from application config
3. Build redirect URI by concatenating Endpoint.url() with "/integrations/oauth/callback/google_oauth"
4. Return keyword list with client_id, client_secret, redirect_uri, and authorization_params with "read" scope

**Test Assertions**:
- returns keyword list with required OAuth configuration keys
- includes client_id from application config
- includes client_secret from application config
- includes redirect_uri with "/integrations/oauth/callback/google_oauth" path
- includes authorization_params with read scope

### strategy/0

Returns the Assent.Strategy.OAuth2 module for the Google OAuth flow.

```elixir
@spec strategy() :: module()
```

**Process**:
1. Return Assent.Strategy.OAuth2 module atom

**Test Assertions**:
- returns Assent.Strategy.OAuth2 module

### normalize_user/1

Transforms Google user data into the application domain model with provider_user_id, email, name, username, and avatar_url.

```elixir
@spec normalize_user(map()) :: {:ok, map()} | {:error, :invalid_user_data}
```

**Process**:
1. Guard clause returns `{:error, :invalid_user_data}` for non-map input
2. Extract provider_user_id from "sub" or "id" field, converting to string
3. Extract email, name, username (from "login" or "email"), and avatar_url (from "avatar_url" or "picture")
4. Return `{:ok, normalized_map}`

**Test Assertions**:
- returns ok tuple with normalized user data for valid input
- extracts provider_user_id from "sub" field
- falls back to "id" field for provider_user_id
- extracts email from "email" field
- returns error :invalid_user_data when input is not a map

## Dependencies

- MetricFlow.Integrations.Providers.Behaviour
- Assent.Strategy.OAuth2
