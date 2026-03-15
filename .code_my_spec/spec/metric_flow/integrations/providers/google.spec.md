# MetricFlow.Integrations.Providers.Google

Google provider implementation using Assent.Strategy.Google. Configures OAuth with email, profile, and analytics.edit scopes with offline access and consent prompt. Normalizes Google user data to domain model including provider_user_id, email, name, avatar_url, and hosted_domain for Google Workspace accounts.

## Functions

### config/0

Returns Assent strategy configuration for Google OAuth with required credentials, redirect URI, and authorization parameters including offline access and consent prompt.

```elixir
@spec config() :: Keyword.t()
```

**Process**:
1. Fetch google_client_id from application config using Application.fetch_env!/2
2. Fetch google_client_secret from application config using Application.fetch_env!/2
3. Build redirect URI by calling build_redirect_uri/0 helper
4. Log configuration values for debugging (client_id, client_secret presence, redirect_uri)
5. Return keyword list with client_id, client_secret, redirect_uri, and authorization_params
6. Authorization params include scope with email, profile, and analytics.edit
7. Set access_type to "offline" for refresh token support
8. Set prompt to "consent" to force consent screen on every auth

**Test Assertions**:
- returns keyword list with required OAuth configuration keys
- includes client_id from application config
- includes client_secret from application config
- includes redirect_uri built from Endpoint.url()
- includes authorization_params with email, profile, and analytics.edit scopes
- includes access_type "offline" for refresh token support
- includes prompt "consent" to force consent screen
- raises ArgumentError when google_client_id is not configured
- raises ArgumentError when google_client_secret is not configured

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

Transforms Google user data from OpenID Connect format into application domain model with provider_user_id, email, name, username, avatar_url, and hosted_domain.

```elixir
@spec normalize_user(map()) :: {:ok, map()} | {:error, :invalid_user_data} | {:error, :missing_provider_user_id} | {:error, :invalid_provider_user_id}
```

**Process**:
1. Guard clause returns error for non-map input
2. Extract provider_user_id from "sub" field using extract_provider_user_id/1
3. Return error tuple if provider_user_id extraction fails
4. Build normalized user map with atom keys
5. Set provider_user_id from extracted value
6. Extract email from "email" field
7. Extract name from "name" field
8. Use email as username
9. Extract avatar_url from "picture" field
10. Extract hosted_domain from "hd" field for Google Workspace accounts
11. Return ok tuple with normalized map

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
- handles minimal user data with only required fields
- normalized data has correct key types (all atoms)
- preserves original values without transformation
- normalizes multiple different Google users independently
- returns error tuple for empty map
- handles Google Workspace users with hosted domain
- handles personal Google accounts without hosted domain
- works with Google's OpenID Connect user info structure
- handles large numeric Google user IDs

## Dependencies

- Assent.Strategy.Google
- Logger
- Application
