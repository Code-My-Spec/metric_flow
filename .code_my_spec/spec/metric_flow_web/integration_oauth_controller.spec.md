# MetricFlowWeb.IntegrationOauthController

OAuth callback handler for all providers. Receives authorization codes from Google, Facebook, and QuickBooks OAuth flows, exchanges them for tokens via Assent, and persists the integration.

## Type

controller

## Dependencies

- MetricFlow.Integrations
- MetricFlow.Integrations.OAuthStateStore

## Delegates

None

## Functions

### request/2

Initiates OAuth flow by redirecting to the provider authorization URL. Stores session params server-side via OAuthStateStore keyed by the state token.

```elixir
@spec request(Plug.Conn.t(), map()) :: Plug.Conn.t()
```

**Process**:
1. Parse provider from params
2. Call `Integrations.authorize_url/1` to get the authorization URL and session params
3. Store session params in OAuthStateStore keyed by state
4. Redirect to the provider authorization URL
5. On error, flash error and redirect to `/integrations/connect`

**Test Assertions**:
- redirects to provider authorization URL for valid provider
- stores session params in OAuthStateStore
- shows error flash and redirects for unsupported provider
- shows error flash when authorize_url fails

### callback/2

Handles OAuth callback from provider. Retrieves session params from OAuthStateStore, exchanges the code for tokens, and persists the integration.

```elixir
@spec callback(Plug.Conn.t(), map()) :: Plug.Conn.t()
```

**Process**:
1. Fetch session params from OAuthStateStore using the state token
2. Parse provider from URL path parameter
3. Check for provider-returned error param
4. Call `Integrations.handle_callback/4` to exchange code for tokens and persist
5. On success, flash success and redirect to provider connect page
6. On error, flash formatted error and redirect

**Test Assertions**:
- redirects with success flash after successful OAuth callback
- redirects with error flash when token exchange fails
- redirects with error flash when provider returns access_denied
- redirects with error flash for unsupported provider
- handles missing state parameter gracefully
