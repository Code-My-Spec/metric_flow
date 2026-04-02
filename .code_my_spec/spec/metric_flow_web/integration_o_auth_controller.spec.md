# MetricFlowWeb.IntegrationOAuthController

OAuth callback handler for all providers. Manages the two-phase OAuth flow: request phase (generate authorization URL, store session params in server-side ETS) and callback phase (exchange authorization code for tokens, persist integration). Session params are stored server-side via OAuthStateStore to avoid cookie stripping by reverse proxies during 302 redirects.

## Type

controller

## Delegates

None

## Dependencies

- MetricFlow.Integrations
- MetricFlow.Integrations.OAuthStateStore

## Functions

### request/2

Initiates OAuth flow by redirecting to provider authorization URL. Generates the authorization URL via `Integrations.authorize_url/1`, stores Assent session params in the server-side ETS store keyed by the state token, and redirects the user to the provider's consent page.

```elixir
@spec request(Plug.Conn.t(), map()) :: Plug.Conn.t()
```

**Process**:
1. Convert provider string param to atom
2. Call `Integrations.authorize_url(provider)` to get URL and session params
3. Extract state token from session params and store via `OAuthStateStore.store/2`
4. Redirect to provider authorization URL
5. On error, flash error message and redirect to `/integrations/connect`
6. On ArgumentError (unknown atom), flash "not yet supported" and redirect

**Test Assertions**:
- redirects to provider authorization URL on success
- stores session params in OAuthStateStore keyed by state
- redirects to /integrations/connect with error flash on authorize_url failure
- redirects with error flash for unsupported provider atom

### callback/2

Handles OAuth callback from provider. Retrieves session params from ETS using the state token, exchanges the authorization code for tokens via `Integrations.handle_callback/4`, and persists the integration. Redirects to the provider detail page on success or with an error flash on failure.

```elixir
@spec callback(Plug.Conn.t(), map()) :: Plug.Conn.t()
```

**Process**:
1. Read provider from URL path param and map to atom
2. Fetch session params from OAuthStateStore using the state query param
3. Check for error param — if present, return error tuple
4. Call `Integrations.handle_callback(scope, provider, session_params, params)`
5. On success, flash "Successfully connected!" and redirect to provider page
6. On changeset error, flash "Failed to save integration"
7. On other error, format error message (access_denied, error_description, generic)
8. Rescue KeyError/ArgumentError with generic error flash

**Test Assertions**:
- creates integration and redirects with success flash on valid callback
- redirects with error flash when provider returns access_denied
- redirects with error flash when provider returns error with description
- redirects with error flash for unsupported provider
- redirects with error flash when state token is missing from ETS
- redirects with error flash on changeset validation failure
- codemyspec provider redirects to /users/settings instead of /integrations/connect
