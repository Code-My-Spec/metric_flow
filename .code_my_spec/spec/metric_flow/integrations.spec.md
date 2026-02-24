# MetricFlow.Integrations

OAuth connections to external platforms. Orchestrates OAuth flows using Assent strategies and provider implementations, persisting tokens and user metadata through the IntegrationRepository.

## Type

context

## Delegates

- get_integration/2: MetricFlow.Integrations.IntegrationRepository.get_integration/2
- list_integrations/1: MetricFlow.Integrations.IntegrationRepository.list_integrations/1
- delete_integration/2: MetricFlow.Integrations.IntegrationRepository.delete_integration/2
- connected?/2: MetricFlow.Integrations.IntegrationRepository.connected?/2

## Functions

### authorize_url/1

Generates OAuth authorization URL for the specified provider.

```elixir
@spec authorize_url(atom()) :: {:ok, %{url: String.t(), session_params: map()}} | {:error, :unsupported_provider} | {:error, term()}
```

**Process**:
1. Look up provider module from providers map
2. Return error if provider not found
3. Get Assent configuration from provider's config/0 callback
4. Get Assent strategy module from provider's strategy/0 callback
5. Call strategy's authorize_url with config
6. Return ok tuple with URL and session params, or error from strategy

**Test Assertions**:
- returns ok tuple with url and session_params for supported provider
- returns error tuple with :unsupported_provider for unknown provider atom
- returned url is a valid authorization endpoint for the provider
- session_params contain state for CSRF protection

### handle_callback/4

Handles OAuth callback, exchanges authorization code for tokens, normalizes user data, and upserts the integration.

```elixir
@spec handle_callback(Scope.t(), atom(), map(), map()) :: {:ok, Integration.t()} | {:error, term()}
```

**Process**:
1. Look up provider module from providers map
2. Return error if provider not found
3. Merge session_params into provider config
4. Get Assent strategy module from provider
5. Call strategy.callback to exchange code for tokens and retrieve user data
6. Call provider's normalize_user/1 to transform user data to domain model
7. Build integration attributes with tokens, expiry, scopes, and normalized metadata
8. Calculate expires_at from token expires_in (defaults to 1 year if not present)
9. Parse granted_scopes from token scope string
10. Persist integration via IntegrationRepository.upsert_integration/3
11. Return ok tuple with integration, or error from any step

**Test Assertions**:
- returns ok tuple with integration for valid callback
- upserts integration with encrypted tokens
- stores normalized provider_metadata from provider
- calculates expires_at from token expires_in
- defaults expires_at to 1 year when expires_in not present
- parses granted_scopes from token scope string
- handles scope as comma-separated string
- handles scope as space-separated string
- handles scope as array
- returns error for unsupported provider
- returns error when token exchange fails
- returns error when user normalization fails

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
- returns list of integrations for user
- returns empty list when user has no integrations
- integrations are ordered by most recently created

### delete_integration/2

Removes integration for the scoped user and provider. Delegates to IntegrationRepository.

```elixir
@spec delete_integration(Scope.t(), atom()) :: {:ok, Integration.t()} | {:error, :not_found}
```

**Test Assertions**:
- returns ok tuple with deleted integration
- returns error tuple with :not_found when integration doesn't exist

### connected?/2

Checks if user is connected to the specified provider. Delegates to IntegrationRepository.

```elixir
@spec connected?(Scope.t(), atom()) :: boolean()
```

**Test Assertions**:
- returns true when integration exists
- returns false when integration doesn't exist

## Dependencies

- MetricFlow.Users
- MetricFlow.Infrastructure

## Components

### MetricFlow.Integrations.Integration

Ecto schema representing OAuth integration connections between users and external service providers. Stores encrypted access and refresh tokens with automatic expiration tracking. Enforces one integration per provider per user via unique constraint. Provides expired?/1 and has_refresh_token?/1 helper functions.

### MetricFlow.Integrations.IntegrationRepository

Data access layer for Integration CRUD operations filtered by user_id. All operations are scoped via Scope struct for multi-tenant isolation. Provides upsert_integration/3 for OAuth callback handling, with_expired_tokens/1 for expiration queries, and connected?/2 for existence checks. Cloak handles automatic encryption/decryption of tokens.

### MetricFlow.Integrations.Providers.Behaviour

Behaviour contract defining callbacks all OAuth provider implementations must implement. Providers return Assent strategy configuration via config/0, specify strategy module via strategy/0, and transform provider-specific user data via normalize_user/1. Enables leveraging Assent's battle-tested OAuth implementations while maintaining separation of concerns.

### MetricFlow.Integrations.Providers.Google

Google provider implementation using Assent.Strategy.Google. Configures OAuth with email, profile, and analytics.edit scopes with offline access and consent prompt. Normalizes Google user data to domain model including provider_user_id, email, name, avatar_url, and hosted_domain for Google Workspace accounts.
