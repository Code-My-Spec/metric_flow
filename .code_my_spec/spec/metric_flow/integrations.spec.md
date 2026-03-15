# MetricFlow.Integrations

OAuth connections to external platforms. Orchestrates OAuth flows using Assent strategies and provider implementations, persisting tokens and user metadata through the IntegrationRepository.

The provider map is read from `Application.get_env(:metric_flow, :oauth_providers)` at call time, enabling test overrides without recompilation. Falls back to the built-in providers map when no override is set.

All public functions accept a `%Scope{}` as the first parameter for multi-tenant isolation. The exceptions are `get_integration_by_id/1` and `list_all_active_integrations/0`, which are unscoped and intended for background workers operating system-wide.

## Type

context

## Delegates

- get_integration/2: MetricFlow.Integrations.IntegrationRepository.get_integration/2
- list_integrations/1: MetricFlow.Integrations.IntegrationRepository.list_integrations/1
- list_all_active_integrations/0: MetricFlow.Integrations.IntegrationRepository.list_all_active_integrations/0
- delete_integration/2: MetricFlow.Integrations.IntegrationRepository.delete_integration/2
- connected?/2: MetricFlow.Integrations.IntegrationRepository.connected?/2
- get_integration_by_id/1: MetricFlow.Integrations.IntegrationRepository.get_integration_by_id/1

## Functions

### list_providers/0

Returns the list of configured provider atoms.

Reads the provider map from application config at call time, enabling test overrides without recompilation. Falls back to the default providers when no override is configured.

```elixir
@spec list_providers() :: list(atom())
```

**Process**:
1. Read provider map from `Application.get_env(:metric_flow, :oauth_providers)`, falling back to the default providers map
2. Return the map keys as a list of provider atoms

**Test Assertions**:
- returns list of provider atoms from the default configuration
- reflects custom providers when application config overrides the default

### authorize_url/2

Generates an OAuth authorization URL for the specified provider.

Looks up the provider module from the providers map (overridable via Application config for tests), retrieves the Assent configuration and strategy, then delegates to the strategy's `authorize_url/1`. The optional `opts` keyword list is merged into the provider config before calling the strategy.

```elixir
@spec authorize_url(atom(), keyword()) ::
        {:ok, %{url: String.t(), session_params: map()}}
        | {:error, :unsupported_provider}
        | {:error, term()}
```

**Process**:
1. Look up provider module from providers map using `fetch_provider/1`
2. Return `{:error, :unsupported_provider}` if provider not found
3. Get Assent configuration from provider's `config/0` callback, merged with opts
4. Get Assent strategy module from provider's `strategy/0` callback
5. Call strategy's `authorize_url/1` with the merged config
6. Return ok tuple with URL and session params, or error from strategy

**Test Assertions**:
- returns ok tuple with url and session_params for a supported provider
- returns error tuple with :unsupported_provider for an unknown provider atom
- returned url is a valid authorization endpoint for the provider
- session_params contain state for CSRF protection

### handle_callback/5

Handles an OAuth callback by exchanging the authorization code for tokens, normalizing user data, and upserting the integration record.

```elixir
@spec handle_callback(Scope.t(), atom(), map(), map(), keyword()) ::
        {:ok, Integration.t()} | {:error, term()}
```

**Process**:
1. Look up provider module from providers map using `fetch_provider/1`
2. Return `{:error, :unsupported_provider}` if provider not found
3. Merge session_params into provider config for CSRF state validation, merged with opts
4. Get Assent strategy module from provider's `strategy/0` callback
5. Verify the OAuth state param matches the stored session state
6. Call strategy's `callback/2` to exchange the authorization code for tokens and retrieve user data
7. Call provider's `normalize_user/1` to transform provider-specific user data to the domain model
8. Build integration attributes with tokens, expiry, scopes, and normalized metadata
9. Calculate `expires_at` from token `expires_in` field (defaults to 1 year if not present)
10. Parse `granted_scopes` from the token scope string (supports comma-separated, space-separated, or list)
11. Attach `realm_id` to `provider_metadata` when present in callback params (QuickBooks-specific)
12. Persist via `IntegrationRepository.upsert_integration/3`
13. Return ok tuple with integration, or error from any step

**Test Assertions**:
- returns ok tuple with integration for a valid callback
- upserts integration with encrypted tokens
- stores normalized provider_metadata from provider
- calculates expires_at from token expires_in
- defaults expires_at to 1 year when expires_in is not present
- parses granted_scopes from token scope string
- handles scope as comma-separated string
- handles scope as space-separated string
- handles scope as list
- returns error for unsupported provider
- returns error when token exchange fails
- returns error when user normalization fails
- returns error when OAuth state does not match session state

### disconnect/2

Disconnects an integration by revoking tokens with the provider (if supported) and then deleting the local integration record.

Token revocation is best-effort — the integration is deleted even if revocation fails, since the user's intent is to disconnect.

```elixir
@spec disconnect(Scope.t(), atom()) :: {:ok, Integration.t()} | {:error, term()}
```

**Process**:
1. Fetch the integration via `IntegrationRepository.get_integration/2`
2. Return error if integration not found
3. Attempt token revocation by calling `provider_mod.revoke_token/1` with the refresh token (falling back to access token) if the provider exports `revoke_token/1`
4. Log a warning if revocation fails, but continue regardless
5. Delete the integration via `IntegrationRepository.delete_integration/2`
6. Return the result of the delete operation

**Test Assertions**:
- returns ok tuple with the deleted integration on success
- returns error tuple with :not_found when integration does not exist
- calls provider's revoke_token/1 when the function is exported
- deletes the integration even when token revocation fails
- skips revocation when provider does not export revoke_token/1

### refresh_token/2

Attempts to refresh the OAuth access token for an integration using the stored refresh token.

Looks up the OAuth provider module based on the integration's provider field and exchanges the refresh token for a new access token. Updates the integration record with fresh tokens and expiry on success.

```elixir
@spec refresh_token(Scope.t(), Integration.t()) ::
        {:ok, Integration.t()} | {:error, term()}
```

**Process**:
1. Look up provider module from providers map using the integration's `provider` field
2. Return `{:error, :unsupported_provider}` if provider not found
3. Get Assent configuration from provider's `config/0` callback
4. Get Assent strategy module from provider's `strategy/0` callback
5. Call `strategy.refresh_access_token/2` with config and a map containing the stored refresh token
6. On success, build integration attributes from the refreshed token
7. Persist updated tokens via `IntegrationRepository.update_integration/3`
8. Return `{:error, :token_refresh_failed}` if an unexpected exception is raised

**Test Assertions**:
- returns ok tuple with updated integration when refresh succeeds
- returns error when provider strategy does not support refresh
- returns error when the refresh request fails
- returns error for unsupported provider
- returns :token_refresh_failed when an exception is raised during refresh

### get_integration/2

Retrieves integration for the scoped user and provider. Delegates to IntegrationRepository.

```elixir
@spec get_integration(Scope.t(), atom()) :: {:ok, Integration.t()} | {:error, :not_found}
```

**Test Assertions**:
- returns ok tuple with integration when found
- returns error tuple with :not_found when not found
- integration has decrypted tokens via Cloak

### list_integrations/1

Lists all integrations for the scoped user. Delegates to IntegrationRepository.

```elixir
@spec list_integrations(Scope.t()) :: list(Integration.t())
```

**Test Assertions**:
- returns list of integrations for the user
- returns empty list when user has no integrations
- integrations are ordered by most recently created

### list_all_active_integrations/0

Lists all integrations across all users. Intended for background workers operating system-wide. Delegates to IntegrationRepository.

```elixir
@spec list_all_active_integrations() :: list(Integration.t())
```

**Test Assertions**:
- returns all integrations regardless of user
- returns empty list when no integrations exist

### get_integration_by_id/1

Retrieves a single integration by its primary key, without scope filtering. Intended for background workers. Delegates to IntegrationRepository.

```elixir
@spec get_integration_by_id(integer()) :: {:ok, Integration.t()} | {:error, :not_found}
```

**Test Assertions**:
- returns ok tuple with integration when found
- returns error tuple with :not_found when not found

### delete_integration/2

Removes an integration for the scoped user and provider. Delegates to IntegrationRepository.

```elixir
@spec delete_integration(Scope.t(), atom()) :: {:ok, Integration.t()} | {:error, :not_found}
```

**Test Assertions**:
- returns ok tuple with the deleted integration
- returns error tuple with :not_found when integration does not exist

### connected?/2

Checks if the user is connected to the specified provider. Delegates to IntegrationRepository.

```elixir
@spec connected?(Scope.t(), atom()) :: boolean()
```

**Test Assertions**:
- returns true when integration exists
- returns false when integration does not exist

## Dependencies

- MetricFlow.Users
- MetricFlow.Infrastructure

## Components

### MetricFlow.Integrations.Integration

Ecto schema representing OAuth integration connections between users and external service providers. Stores encrypted access and refresh tokens with automatic expiration tracking. Enforces one integration per provider per user via unique constraint. Provides `expired?/1` and `has_refresh_token?/1` helper functions.

### MetricFlow.Integrations.IntegrationRepository

Data access layer for Integration CRUD operations filtered by user_id. All operations are scoped via Scope struct for multi-tenant isolation. Provides `upsert_integration/3` for OAuth callback handling, `with_expired_tokens/1` for expiration queries, `connected?/2` for existence checks, and unscoped functions `list_all_active_integrations/0` and `get_integration_by_id/1` for background workers. Cloak handles automatic encryption and decryption of tokens.

### MetricFlow.Integrations.OAuthStateStore

Server-side ETS-backed store for OAuth session params, keyed by the OAuth `state` token. Runs as a named GenServer that owns the ETS table and periodically purges expired entries. Avoids any reliance on cookies or the Phoenix session, which can be stripped by reverse proxies during 302 redirects. Implements consume-once semantics with a 5-minute TTL.

### MetricFlow.Integrations.Providers.Behaviour

Behaviour contract defining callbacks all OAuth provider implementations must implement. Providers return Assent strategy configuration via `config/0`, specify strategy module via `strategy/0`, and transform provider-specific user data via `normalize_user/1`. Enables leveraging Assent's battle-tested OAuth implementations while maintaining separation of concerns. Optionally providers may export `revoke_token/1` for token revocation on disconnect.

### MetricFlow.Integrations.Providers.Google

Google provider implementation using Assent.Strategy.Google. Configures OAuth with email, profile, and analytics.edit scopes with offline access and consent prompt. Normalizes Google user data to domain model including provider_user_id, email, name, avatar_url, and hosted_domain for Google Workspace accounts. Supports token revocation via the Google token revocation endpoint.

### MetricFlow.Integrations.Providers.Facebook

Facebook provider implementation using Assent.Strategy.Facebook. Configures OAuth with the `ads_read` scope for accessing Facebook Ads data. Normalizes Facebook user data to the domain model including provider_user_id, email, name, username, and avatar_url.

### MetricFlow.Integrations.Providers.QuickBooks

QuickBooks Online OAuth provider implementation using Assent.Strategy.OAuth2. Configures OAuth with the `com.intuit.quickbooks.accounting` scope using Intuit OAuth 2.0 endpoints. Normalizes QuickBooks user data to the domain model including provider_user_id, email, name, username, avatar_url, and realm_id for the connected company. Supports token revocation via the Intuit OAuth revocation endpoint.
