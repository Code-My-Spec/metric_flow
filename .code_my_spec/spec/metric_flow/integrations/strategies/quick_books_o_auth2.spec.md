# MetricFlow.Integrations.Strategies.QuickBooksOAuth2

Custom Assent OAuth2 strategy for QuickBooks Online that skips the userinfo fetch. QuickBooks uses OAuth 2.0 for token exchange but does not reliably support the OpenID Connect userinfo endpoint for the `com.intuit.quickbooks.accounting` scope. The `realmId` (company ID) is returned as a query parameter on the callback URL rather than from a userinfo endpoint. This strategy overrides the base OAuth2 behavior to complete token exchange without a userinfo HTTP call, returning an empty map as the user payload.

## Delegates

None.

## Functions

### default_config/1

Returns the default configuration for the QuickBooks OAuth2 strategy. Required by `Assent.Strategy.OAuth2.Base`.

```elixir
@spec default_config(Keyword.t()) :: Keyword.t()
```

**Process**:
1. Return an empty keyword list, as all configuration is supplied by the provider module at runtime

**Test Assertions**:
- returns an empty keyword list

### normalize/2

Normalizes the user map returned by the strategy. Required by `Assent.Strategy.OAuth2.Base`. For QuickBooks, the user payload from `fetch_user/2` is always an empty map, so normalization is a pass-through.

```elixir
@spec normalize(Keyword.t(), map()) :: {:ok, map()}
```

**Process**:
1. Return `{:ok, user}` unchanged, as no field mapping is required for the empty QuickBooks user payload

**Test Assertions**:
- returns ok tuple with the user map unchanged
- accepts an empty map and returns it as-is
- accepts a non-empty map and returns it unchanged

### fetch_user/2

Skips the userinfo HTTP request that a standard OAuth2 strategy would make. QuickBooks Online does not expose a userinfo endpoint usable with the `com.intuit.quickbooks.accounting` scope; the `realmId` needed to identify the connected company is a callback URL parameter, not a userinfo response field. Returning an empty map here allows token exchange to complete without a network call.

```elixir
@spec fetch_user(Keyword.t(), map()) :: {:ok, map()}
```

**Process**:
1. Ignore the config and token arguments entirely
2. Return `{:ok, %{}}` — an empty map — to signal that user data will be populated from callback parameters by the provider layer

**Test Assertions**:
- returns ok tuple with an empty map regardless of config
- returns ok tuple with an empty map regardless of token
- never raises or returns an error tuple

## Dependencies

- Assent.Strategy.OAuth2.Base
