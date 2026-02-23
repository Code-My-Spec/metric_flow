# MetricFlow.Integrations.Integration

Ecto schema representing OAuth integration connections between users and external service providers. Stores encrypted access and refresh tokens with automatic expiration tracking. Enforces one integration per provider per user via unique constraint. Provides expired?/1 and has_refresh_token?/1 helper functions.

## Fields

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| id | integer | Yes (auto) | Primary key | Auto-generated |
| provider | Ecto.Enum | Yes | The external service provider | Must be one of: :github, :gitlab, :bitbucket, :google, :google_ads, :facebook_ads, :google_analytics, :quickbooks |
| access_token | MetricFlow.Encrypted.Binary | Yes | OAuth access token (encrypted at rest) | Encrypted using Cloak.Ecto.Binary |
| refresh_token | MetricFlow.Encrypted.Binary | No | OAuth refresh token (encrypted at rest) | Optional, encrypted using Cloak.Ecto.Binary |
| expires_at | utc_datetime_usec | Yes | UTC timestamp when access_token expires | Must be a valid UTC datetime |
| granted_scopes | array of strings | No | List of OAuth scopes granted by the user | Defaults to empty list |
| provider_metadata | map | No | Provider-specific metadata (e.g., user IDs, usernames) | Defaults to empty map, must be a map type |
| user_id | integer | Yes | Foreign key to users table | References MetricFlow.Users.User |
| inserted_at | utc_datetime_usec | Yes (auto) | Timestamp when record was created | Auto-generated |
| updated_at | utc_datetime_usec | Yes (auto) | Timestamp when record was last updated | Auto-generated |

## Functions

### changeset/2

Creates an Ecto changeset for creating or updating an Integration record. Validates all required fields, type constraints, associations, and enforces unique constraint on user/provider combination.

```elixir
@spec changeset(Integration.t(), map()) :: Ecto.Changeset.t()
```

**Process**:
1. Cast attributes: user_id, provider, access_token, refresh_token, expires_at, granted_scopes, provider_metadata
2. Validate required fields: user_id, provider, access_token, expires_at
3. Validate provider_metadata is a map (or nil)
4. Add association constraint on user (ensures referenced user exists)
5. Add unique constraint on [:user_id, :provider] to prevent duplicate integrations
6. Return changeset with validations applied

**Test Assertions**:
- Creates valid changeset with all required fields
- Casts each field attribute correctly (user_id, provider, access_token, refresh_token, expires_at, granted_scopes, provider_metadata)
- Validates user_id is required
- Validates provider is required
- Validates access_token is required
- Validates expires_at is required
- Allows nil refresh_token as optional
- Allows empty granted_scopes array
- Allows nil granted_scopes (defaults to empty list)
- Validates provider_metadata is a map
- Rejects provider_metadata when not a map
- Rejects provider_metadata when it is a list
- Allows nil provider_metadata (defaults to empty map)
- Accepts all valid provider enum values (:github, :gitlab, :bitbucket, :google, :google_ads, :facebook_ads, :google_analytics, :quickbooks)
- Validates user association exists (assoc_constraint triggers on insert)
- Enforces unique constraint on user_id and provider combination
- Allows same provider for different users
- Allows different providers for same user
- Creates valid changeset for updating existing integration
- Preserves existing fields when updating subset of attributes
- Handles empty attributes map gracefully

### expired?/1

Checks if the integration's access token has expired by comparing expires_at timestamp with current UTC time.

```elixir
@spec expired?(Integration.t()) :: boolean()
```

**Process**:
1. Get current UTC time using DateTime.utc_now()
2. Compare current time with integration.expires_at using DateTime.compare/2
3. Return true if current time is greater than expires_at, false otherwise

**Test Assertions**:
- Returns true when expires_at is in the past
- Returns false when expires_at is in the future
- Returns true when expires_at is exactly current time
- Returns true when token expired one second ago
- Returns false when token expires in one second
- Returns false when token expires in one hour
- Returns true when token expired one hour ago
- Compares against current UTC time
- Works with integrations that have refresh tokens
- Works with integrations without refresh tokens

### has_refresh_token?/1

Checks if the integration has a refresh token available for token renewal.

```elixir
@spec has_refresh_token?(Integration.t()) :: boolean()
```

**Process**:
1. Pattern match on integration.refresh_token
2. Return false if refresh_token is nil
3. Return true if refresh_token has any value

**Test Assertions**:
- Returns true when refresh_token is present
- Returns false when refresh_token is nil
- Returns true for expired integration with refresh_token
- Returns false for expired integration without refresh_token
- Returns false when refresh_token is an empty string (implementation-dependent on encryption behavior)
- Works with different providers
- Works with provider that does not issue refresh tokens

## Dependencies

- Ecto.Schema
- Ecto.Changeset
- MetricFlow.Encrypted.Binary
- MetricFlow.Users.User
- DateTime
