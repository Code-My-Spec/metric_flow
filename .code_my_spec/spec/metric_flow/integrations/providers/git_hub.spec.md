# MetricFlow.Integrations.Providers.GitHub

GitHub provider implementation using Assent.Strategy.Github. Configures OAuth with user:email and repo scopes. Normalizes GitHub user data to domain model including provider_user_id, email, name, username, and avatar_url extracted from OpenID Connect claims.

## Functions

### config/0

Returns OAuth configuration for GitHub integration including client credentials, redirect URI, and authorization scopes.

```elixir
@spec config() :: Keyword.t()
```

**Process**:
1. Fetch GitHub client ID from application configuration (:github_client_id)
2. Fetch GitHub client secret from application configuration (:github_client_secret)
3. Build redirect URI by combining oauth_base_url with "/auth/github/callback"
4. Construct authorization params with scope "user:email repo"
5. Return keyword list with client_id, client_secret, redirect_uri, and authorization_params

**Test Assertions**:
- Returns a keyword list
- Contains :client_id key with binary value from application config
- Contains :client_secret key with binary value from application config
- Contains :redirect_uri key with callback path /auth/github/callback
- Contains :authorization_params keyword list with scope including user:email and repo
- Configuration is compatible with Assent.Strategy.Github authorize_url/1
- All required keys for Assent OAuth strategy are present and properly formatted

### strategy/0

Returns the Assent strategy module for GitHub OAuth.

```elixir
@spec strategy() :: module()
```

**Process**:
1. Return Assent.Strategy.Github module reference

**Test Assertions**:
- Returns Assent.Strategy.Github module
- Returned module is loaded and available
- Returned module exports authorize_url/1 function
- Returned module exports callback/2 function

### normalize_user/1

Transforms GitHub user data from Assent (OpenID Connect claims) to application domain model.

```elixir
@spec normalize_user(user_data :: map()) :: {:ok, map()} | {:error, term()}
```

**Process**:
1. Validate input is a map, return {:error, :invalid_user_data} if not
2. Extract provider_user_id from "sub" claim using extract_provider_user_id/1
3. Return error if "sub" is missing or invalid
4. Map OpenID Connect claims to domain model:
   - "sub" -> :provider_user_id (required, string)
   - "email" -> :email (optional, can be nil)
   - "name" -> :name (optional, can be nil)
   - "preferred_username" -> :username (optional, can be nil)
   - "picture" -> :avatar_url (optional, can be nil)
5. Return {:ok, normalized_map} with atom keys

**Test Assertions**:
- Transforms complete GitHub user data to normalized domain model
- Maps OpenID Connect "sub" claim to :provider_user_id
- Maps OpenID Connect "email" claim to :email
- Maps OpenID Connect "name" claim to :name
- Maps OpenID Connect "preferred_username" claim to :username
- Maps OpenID Connect "picture" claim to :avatar_url
- Returns error {:error, :missing_provider_user_id} when "sub" field is missing
- Handles missing optional email field (sets to nil)
- Handles missing optional name field (sets to nil)
- Handles missing optional username field (sets to nil)
- Handles missing optional avatar_url field (sets to nil)
- Handles user with only minimal required data (just "sub")
- Returns map with all expected keys for Integration persistence
- Normalized map has atom keys (not string keys)
- Preserves original values without transformation
- Converts numeric "sub" to string if present
- Normalizes multiple different users independently
- Returns error tuple {:error, :invalid_user_data} for invalid non-map input
- Returns error tuple {:error, :missing_provider_user_id} for empty map
- Returns error tuple {:error, :invalid_user_data} for nil input
- Returns descriptive error for missing provider_user_id
- Fails fast with error for any invalid input structure

## Dependencies

- MetricFlow.Integrations.Providers.Behaviour
- Assent.Strategy.Github
- Application
