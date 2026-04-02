# MetricFlowWeb.Plugs.WhiteLabel

Plug that detects agency subdomains and loads white-label configuration. Extracts the first subdomain segment from the request host, looks up the matching WhiteLabelConfig via Agencies context, and stores branding data in the session for the LiveView on_mount hook to assign to the socket.

## Type

module

## Delegates

None

## Dependencies

- MetricFlow.Agencies

## Functions

### init/1

Standard Plug init callback. Passes options through unchanged.

```elixir
@spec init(keyword()) :: keyword()
```

**Process**:
1. Return opts as-is

**Test Assertions**:
- returns opts unchanged

### call/2

Extracts subdomain from request host and loads white-label config into session.

```elixir
@spec call(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
```

**Process**:
1. Extract first subdomain segment from `conn.host` (requires 3+ domain parts)
2. If no subdomain, set `white_label_config` session to nil
3. If subdomain found, look up `WhiteLabelConfig` via `Agencies.get_white_label_config_by_subdomain/1`
4. If config found, store subdomain, logo_url, primary_color, secondary_color in session
5. If no config matches, set session to nil

**Test Assertions**:
- sets white_label_config to nil for bare domain (no subdomain)
- sets white_label_config to nil for unknown subdomain
- loads config into session for matching subdomain
- session config contains subdomain, logo_url, primary_color, secondary_color
- handles localhost and IP addresses gracefully (no subdomain extracted)
