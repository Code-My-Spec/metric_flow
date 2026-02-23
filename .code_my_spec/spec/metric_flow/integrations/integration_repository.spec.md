# MetricFlow.Integrations.IntegrationRepository

Data access layer for Integration CRUD operations filtered by user_id. All operations are scoped via Scope struct for multi-tenant isolation. Provides upsert_integration/3 for OAuth callback handling, with_expired_tokens/1 for expiration queries, and connected?/2 for existence checks. Cloak handles automatic encryption/decryption of tokens.

## Functions

### get_integration/2

Retrieves a single integration for the scoped user and provider.

```elixir
@spec get_integration(Scope.t(), atom()) :: {:ok, Integration.t()} | {:error, :not_found}
```

**Process**:
1. Build query filtering by user_id from scope and provider
2. Execute query with Repo.one()
3. Return {:error, :not_found} if nil
4. Return {:ok, integration} if found
5. Cloak automatically decrypts access_token and refresh_token when loading

**Test Assertions**:
- Returns integration when it exists for scoped user and provider
- Returns error when integration doesn't exist for provider
- Returns error when integration exists for different user
- Decrypts access_token and refresh_token when loading
- Enforces multi-tenant isolation

### list_integrations/1

Returns all integrations for the scoped user, ordered by most recently created.

```elixir
@spec list_integrations(Scope.t()) :: list(Integration.t())
```

**Process**:
1. Build query filtering by user_id from scope
2. Order by inserted_at descending, then id descending
3. Execute query with Repo.all()
4. Return list of integrations (empty list if none exist)

**Test Assertions**:
- Returns all integrations for scoped user
- Returns empty list when no integrations exist
- Only returns integrations for scoped user
- Orders by most recently created
- Enforces multi-tenant isolation

### create_integration/2

Creates a new integration with encrypted tokens.

```elixir
@spec create_integration(Scope.t(), map()) :: {:ok, Integration.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Merge user_id from scope into attrs
2. Build changeset with Integration.changeset/2
3. Insert into database with Repo.insert/1
4. Validate provider is supported
5. Enforce unique constraint on (user_id, provider)
6. Cloak automatically encrypts access_token and refresh_token

**Test Assertions**:
- Creates integration with valid attributes
- Returns error with invalid provider
- Returns error with missing required fields
- Returns error with duplicate user_id and provider
- Allows same provider for different users
- Stores granted_scopes and provider_metadata
- Handles integration without refresh_token

### update_integration/3

Updates an existing integration with new attributes.

```elixir
@spec update_integration(Scope.t(), atom(), map()) :: {:ok, Integration.t()} | {:error, :not_found | Ecto.Changeset.t()}
```

**Process**:
1. Call get_integration/2 to fetch existing integration
2. Return {:error, :not_found} if integration doesn't exist
3. Build changeset with Integration.changeset/2
4. Update integration with Repo.update/1
5. Return updated integration or changeset errors

**Test Assertions**:
- Updates integration with valid attributes
- Returns error when integration doesn't exist for scoped user
- Returns error when integration exists for different user
- Returns error with invalid attributes
- Commonly used for token refresh operations

### delete_integration/2

Removes an integration and all associated encrypted tokens.

```elixir
@spec delete_integration(Scope.t(), atom()) :: {:ok, Integration.t()} | {:error, :not_found}
```

**Process**:
1. Call get_integration/2 to fetch existing integration
2. Return {:error, :not_found} if integration doesn't exist
3. Delete integration with Repo.delete/1
4. Return deleted integration struct

**Test Assertions**:
- Deletes integration for scoped user and provider
- Returns error when integration doesn't exist
- Returns error when integration exists for different user
- Removes all associated encrypted tokens
- Does not affect integrations for other providers

### by_provider/2

Alias for get_integration/2, provides semantic clarity when querying by provider.

```elixir
@spec by_provider(Scope.t(), atom()) :: {:ok, Integration.t()} | {:error, :not_found}
```

**Process**:
1. Delegate to get_integration/2
2. Return same result

**Test Assertions**:
- Returns integration for scoped user and provider
- Is alias for get_integration/2
- Provides semantic clarity when querying by provider

### with_expired_tokens/1

Returns all integrations for the scoped user where expires_at is less than current timestamp.

```elixir
@spec with_expired_tokens(Scope.t()) :: list(Integration.t())
```

**Process**:
1. Get current timestamp with DateTime.utc_now()
2. Build query filtering by user_id from scope
3. Add where clause for expires_at < current timestamp
4. Execute query with Repo.all()
5. Return list of expired integrations

**Test Assertions**:
- Returns integrations where expires_at is less than current timestamp
- Returns empty list when no integrations are expired
- Only returns expired integrations for scoped user
- Used to identify integrations requiring token refresh
- Does not decrypt tokens when checking expiration
- Enforces multi-tenant isolation

### upsert_integration/3

Creates or updates an integration based on unique constraint (user_id, provider).

```elixir
@spec upsert_integration(Scope.t(), atom(), map()) :: {:ok, Integration.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Merge user_id from scope and provider into attrs
2. Build changeset with Integration.changeset/2
3. Insert with on_conflict option: {:replace_all_except, [:id, :inserted_at]}
4. Set conflict_target to [:user_id, :provider]
5. Return integration with updated/created data

**Test Assertions**:
- Creates new integration when none exists
- Updates existing integration when one exists
- Based on unique constraint (user_id, provider)
- Used during OAuth callback for first-time connections
- Used during OAuth callback for reconnections
- Returns error with invalid attributes
- Allows different providers for same user

### connected?/2

Returns true if an integration exists for the scoped user and provider, false otherwise.

```elixir
@spec connected?(Scope.t(), atom()) :: boolean()
```

**Process**:
1. Build query filtering by user_id from scope and provider
2. Execute query with Repo.exists?/1
3. Return boolean result

**Test Assertions**:
- Returns true when integration exists for scoped user and provider
- Returns false when integration doesn't exist
- Returns false when integration exists for different user
- Efficient check without loading full integration record
- Checks all providers independently
- Enforces multi-tenant isolation

## Dependencies

- Ecto.Query
- MetricFlow.Infrastructure.Repo
- MetricFlow.Users.Scope
- MetricFlow.Integrations.Integration
