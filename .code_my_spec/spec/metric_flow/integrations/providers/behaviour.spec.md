# MetricFlow.Integrations.Providers.Behaviour

Behaviour contract defining callbacks all OAuth provider implementations must implement. Providers return Assent strategy configuration via config/0, specify strategy module via strategy/0, and transform provider-specific user data via normalize_user/1. Enables leveraging Assent's battle-tested OAuth implementations while maintaining separation of concerns.

## Functions

### config/0

Returns the Assent strategy configuration for the provider.

```elixir
@spec config() :: Keyword.t()
```

**Process**:

1. Retrieve OAuth client credentials from application configuration
2. Build redirect URI for OAuth callback
3. Assemble keyword list with required keys: client_id, client_secret, redirect_uri
4. Include provider-specific authorization_params when applicable (e.g., scopes, access_type)
5. Return complete configuration compatible with Assent strategies

**Test Assertions**:

### strategy/0

Returns the Assent strategy module to use for this provider.

```elixir
@spec strategy() :: module()
```

**Process**:

1. Return the appropriate Assent.Strategy module atom for this provider (e.g., Assent.Strategy.Github, Assent.Strategy.Google)

**Test Assertions**:

### normalize_user/1

Transforms provider-specific user data into the application's domain model.

```elixir
@spec normalize_user(user_data :: map()) :: {:ok, map()} | {:error, term()}
```

**Process**:

1. Validate user_data is a map, return error tuple if not
2. Extract provider_user_id from "sub" field (OpenID Connect standard claim)
3. Convert integer provider_user_id to string if necessary
4. Return error if "sub" is missing or invalid type
5. Extract standard OpenID Connect claims: email, name, preferred_username, picture
6. Map OIDC claims to domain model keys with atom keys
7. Include provider-specific fields when applicable (e.g., hosted_domain for Google)
8. Return ok tuple with normalized user map containing: provider_user_id, email, name, username, avatar_url

**Test Assertions**:

- returns ok tuple with normalized user map when user_data is valid
- extracts provider_user_id from "sub" field
- converts integer provider_user_id to string
- extracts email, name, username, avatar_url from OpenID Connect claims
- includes provider-specific fields in normalized output
- handles optional fields gracefully
- returns error tuple when user_data is not a map
- returns error tuple when "sub" field is missing
- returns error tuple when "sub" field has invalid type
- normalized user map has atom keys
- normalized user map has required keys
- preserves original values without transformation
- uses standard OIDC claim names
- sub claim is mandatory per OIDC spec
- other OIDC claims are optional

## Dependencies

- Assent.Strategy.Github
- Assent.Strategy.Google
