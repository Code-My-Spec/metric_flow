# MetricFlowWeb.WhiteLabelHook

LiveView on_mount hook that loads white-label configuration from the session into socket assigns. The WhiteLabel plug sets the session value based on subdomain; this hook makes it available to LiveView templates for branding customization.

## Type

module

## Delegates

None

## Dependencies

None

## Functions

### on_mount/4

Reads white-label config from session and assigns it to the socket.

```elixir
@spec on_mount(:load_white_label, map(), map(), Phoenix.LiveView.Socket.t()) :: {:cont, Phoenix.LiveView.Socket.t()}
```

**Process**:
1. Read `white_label_config` from session map
2. Assign it to socket as `:white_label_config`

**Test Assertions**:
- assigns white_label_config from session when present
- assigns nil when no white_label_config in session

