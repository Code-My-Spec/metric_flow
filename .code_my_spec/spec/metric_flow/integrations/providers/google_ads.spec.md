# MetricFlow.Integrations.Providers.GoogleAds

Google Ads OAuth provider implementation using Assent.Strategy.Google. Configures OAuth with the `adwords` scope in addition to email and profile, requesting offline access with a forced consent prompt to ensure a refresh token is issued on every authorisation. Normalizes Google user data to the application domain model by delegating to the shared Google normalization logic.

## Functions

### config/0

Returns Assent strategy configuration for Google Ads OAuth with required credentials, redirect URI, and authorization parameters including the adwords scope, offline access, and consent prompt.

```elixir
@spec config() :: Keyword.t()
```

**Process**:
1. Fetch google_client_id from application config using Application.fetch_env!/2
2. Fetch google_client_secret from application config using Application.fetch_env!/2
3. Build redirect URI by concatenating Endpoint.url() with the callback path "/integrations/oauth/callback/google_ads"
4. Return keyword list with client_id, client_secret, redirect_uri, and authorization_params
5. Authorization params include scope with email, profile, and https://www.googleapis.com/auth/adwords
6. Set access_type to "offline" for refresh token support
7. Set prompt to "consent" to force consent screen on every auth

**Test Assertions**:
- returns keyword list with required OAuth configuration keys
- includes client_id from application config
- includes client_secret from application config
- includes redirect_uri with "/integrations/oauth/callback/google_ads" path
- includes authorization_params with adwords scope
- includes email and profile scopes in addition to adwords
- includes access_type "offline" for refresh token support
- includes prompt "consent" to force consent screen
- raises ArgumentError when google_client_id is not configured
- raises ArgumentError when google_client_secret is not configured

### strategy/0

Returns the Assent.Strategy.Google module to use for the Google Ads OAuth flow.

```elixir
@spec strategy() :: module()
```

**Process**:
1. Return Assent.Strategy.Google module atom

**Test Assertions**:
- returns Assent.Strategy.Google module

### normalize_user/1

Transforms Google user data from OpenID Connect format into application domain model with provider_user_id, email, name, username, avatar_url, and hosted_domain by delegating to the shared Google provider normalization.

```elixir
@spec normalize_user(user_data :: map()) ::
        {:ok, map()}
        | {:error, :invalid_user_data}
        | {:error, :missing_provider_user_id}
        | {:error, :invalid_provider_user_id}
```

**Process**:
1. Guard clause returns error for non-map input
2. Delegate normalization to MetricFlow.Integrations.Providers.Google.normalize_user/1
3. Return the result from the delegated call

**Test Assertions**:
- returns ok tuple with normalized user data for valid Google user data
- extracts provider_user_id from "sub" field
- extracts email from "email" field
- extracts name from "name" field
- uses email as username
- extracts avatar_url from "picture" field
- extracts hosted_domain from "hd" field for Workspace accounts
- handles missing optional fields (name, picture, hd) gracefully
- returns error :missing_provider_user_id when "sub" is nil
- returns error :invalid_provider_user_id when "sub" is invalid type
- returns error :invalid_user_data when input is not a map
- converts integer provider_user_id to string
- accepts string provider_user_id as-is
- handles missing "sub" field
- normalized data has correct key types (all atoms)

## Dependencies

- Assent.Strategy.Google
- MetricFlow.Integrations.Providers.Google
- Logger
- Application
