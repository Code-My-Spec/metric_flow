# MetricFlow.Integrations.Providers.GoogleAnalytics

Google Analytics (GA4) OAuth provider implementation using Assent.Strategy.Google. Configures OAuth with `email`, `profile`, and `analytics.readonly` scopes, requesting offline access with a forced consent prompt to ensure a refresh token is issued on every authorisation. Delegates user data normalization to the shared Google provider module.

## Delegates

- normalize_user/1: MetricFlow.Integrations.Providers.Google.normalize_user/1

## Functions

### config/0

Returns Assent strategy configuration for Google Analytics OAuth with required credentials, redirect URI, and authorization parameters scoped to `analytics.readonly`.

```elixir
@spec config() :: Keyword.t()
```

**Process**:
1. Fetch google_client_id from application config using Application.fetch_env!/2
2. Fetch google_client_secret from application config using Application.fetch_env!/2
3. Build redirect URI by appending the google_analytics callback path to MetricFlowWeb.Endpoint.url()
4. Return keyword list with client_id, client_secret, redirect_uri, and authorization_params
5. Authorization params include scope with email, profile, and analytics.readonly
6. Set access_type to "offline" for refresh token support
7. Set prompt to "consent" to force consent screen on every auth

**Test Assertions**:
- returns keyword list with required OAuth configuration keys
- includes client_id from application config
- includes client_secret from application config
- includes redirect_uri pointing to the google_analytics callback path
- includes authorization_params with email, profile, and analytics.readonly scopes
- includes access_type "offline" for refresh token support
- includes prompt "consent" to force consent screen
- raises ArgumentError when google_client_id is not configured
- raises ArgumentError when google_client_secret is not configured

### strategy/0

Returns the Assent.Strategy.Google module to use for the Google Analytics OAuth flow.

```elixir
@spec strategy() :: module()
```

**Process**:
1. Return Assent.Strategy.Google module atom

**Test Assertions**:
- returns Assent.Strategy.Google module

### normalize_user/1

Transforms Google user data (OIDC claims) into the application domain model. Delegates to MetricFlow.Integrations.Providers.Google.normalize_user/1 for shared normalization logic.

```elixir
@spec normalize_user(map()) :: {:ok, map()} | {:error, :invalid_user_data} | {:error, :missing_provider_user_id} | {:error, :invalid_provider_user_id}
```

**Process**:
1. Guard clause returns error for non-map input
2. Delegate to MetricFlow.Integrations.Providers.Google.normalize_user/1 for map input
3. Return result from delegate, which normalizes provider_user_id, email, name, username, avatar_url, and hosted_domain

**Test Assertions**:
- returns ok tuple with normalized user data for valid Google user data
- extracts provider_user_id from "sub" field
- extracts email from "email" field
- extracts name from "name" field
- uses email as username
- extracts avatar_url from "picture" field
- extracts hosted_domain from "hd" field for Workspace accounts
- handles missing optional fields (name, picture, hd) gracefully with nil
- returns error :missing_provider_user_id when "sub" is missing or nil
- returns error :invalid_provider_user_id when "sub" is invalid type
- returns error :invalid_user_data when input is not a map
- converts integer provider_user_id to string
- normalized data has all atom keys

## Dependencies

- Assent.Strategy.Google
- Logger
- Application
- MetricFlowWeb.Endpoint
- MetricFlow.Integrations.Providers.Google
- MetricFlow.Integrations.Providers.Behaviour
