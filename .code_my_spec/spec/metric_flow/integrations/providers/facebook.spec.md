# MetricFlow.Integrations.Providers.Facebook

Facebook OAuth provider implementation using Assent.Strategy.Facebook. Configures OAuth with `ads_read` scope for accessing Facebook Ads data. Normalizes Facebook user data to the application domain model including provider_user_id, email, name, username, and avatar_url.

## Functions

### config/0

Returns Assent strategy configuration for Facebook OAuth with required credentials, redirect URI, and authorization parameters including the ads_read scope.

```elixir
@spec config() :: Keyword.t()
```

**Process**:
1. Fetch facebook_app_id from application config using Application.fetch_env!/2
2. Fetch facebook_app_secret from application config using Application.fetch_env!/2
3. Build redirect URI by calling build_redirect_uri/0 helper
4. Log configuration values for debugging (client_id, redirect_uri)
5. Return keyword list with client_id, client_secret, redirect_uri, and authorization_params
6. Authorization params include scope with ads_read

**Test Assertions**:
- returns keyword list with required OAuth configuration keys
- includes client_id from application config
- includes client_secret from application config
- includes redirect_uri pointing to the facebook_ads callback path
- includes authorization_params with ads_read scope
- raises ArgumentError when facebook_app_id is not configured
- raises ArgumentError when facebook_app_secret is not configured

### strategy/0

Returns the Assent.Strategy.Facebook module to use for OAuth flow.

```elixir
@spec strategy() :: module()
```

**Process**:
1. Return Assent.Strategy.Facebook module atom

**Test Assertions**:
- returns Assent.Strategy.Facebook module

### normalize_user/1

Transforms Facebook user data into the application domain model with provider_user_id, email, name, username, and avatar_url.

```elixir
@spec normalize_user(map()) :: {:ok, map()} | {:error, :invalid_user_data} | {:error, :missing_provider_user_id}
```

**Process**:
1. Guard clause returns error for non-map input
2. Extract provider_user_id from "sub" field using extract_provider_user_id/1
3. Return error tuple if provider_user_id extraction fails
4. Extract email from "email" field
5. Extract name from "name" field
6. Use email as username
7. Extract avatar_url from "picture" field
8. Return ok tuple with normalized map using atom keys

**Test Assertions**:
- returns ok tuple with normalized user data for valid Facebook user data
- extracts provider_user_id from "sub" field as string
- converts integer "sub" to string provider_user_id
- extracts email from "email" field
- extracts name from "name" field
- uses email as username
- extracts avatar_url from "picture" field
- handles missing optional fields (name, picture, email) gracefully with nil
- returns error :missing_provider_user_id when "sub" is missing
- returns error :missing_provider_user_id when "sub" is nil
- returns error :invalid_user_data when input is not a map
- normalized data has correct key types (all atoms)
- handles minimal user data with only required "sub" field
- normalizes multiple different Facebook users independently

## Dependencies

- Assent.Strategy.Facebook
- Logger
- Application
- MetricFlowWeb.Endpoint
