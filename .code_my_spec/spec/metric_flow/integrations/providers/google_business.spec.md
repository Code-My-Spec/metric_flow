# MetricFlow.Integrations.Providers.GoogleBusiness

Google Business Profile OAuth provider implementation using Assent.Strategy.Google. Configures OAuth with the `business.manage` scope for accessing Google Business Profile locations and reviews. Delegates user normalization to the Google provider module for shared handling of Google user data.

## Functions

### config/0

Returns Assent strategy configuration for Google Business Profile OAuth with required credentials, redirect URI, and authorization parameters including the business.manage scope.

```elixir
@spec config() :: Keyword.t()
```

**Process**:
1. Fetch google_client_id from application config
2. Fetch google_client_secret from application config
3. Build redirect URI from endpoint URL and callback path
4. Return keyword list with client_id, client_secret, redirect_uri, and authorization_params
5. Authorization params include scope with email, profile, and business.manage scopes
6. Authorization params include access_type "offline" and prompt "consent"

**Test Assertions**:
- returns keyword list with required OAuth configuration keys
- includes client_id from application config
- includes redirect_uri pointing to the google_business callback path
- includes authorization_params with business.manage scope
- includes access_type offline for refresh token support
- raises when google_client_id is not configured

### strategy/0

Returns the Assent.Strategy.Google module to use for OAuth flow.

```elixir
@spec strategy() :: module()
```

**Process**:
1. Return Assent.Strategy.Google module atom

**Test Assertions**:
- returns Assent.Strategy.Google module

### normalize_user/1

Delegates to Google provider's normalize_user for shared Google user data handling.

```elixir
@spec normalize_user(map()) :: {:ok, map()} | {:error, :invalid_user_data}
```

**Process**:
1. Guard clause returns error for non-map input
2. Delegate to MetricFlow.Integrations.Providers.Google.normalize_user/1

**Test Assertions**:
- returns ok tuple with normalized user data for valid Google user data
- delegates to Google provider for normalization
- returns error :invalid_user_data when input is not a map

## Dependencies

- Assent.Strategy.Google
- MetricFlow.Integrations.Providers.Google
- Application
- MetricFlowWeb.Endpoint
