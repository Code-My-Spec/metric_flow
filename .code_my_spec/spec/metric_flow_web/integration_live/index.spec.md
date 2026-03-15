# MetricFlowWeb.IntegrationLive.Index

List and manage integrations, manual sync trigger.

## Type

liveview

## Route

`/integrations`

## Params

None

## Dependencies

- MetricFlow.DataSync
- MetricFlow.Integrations

## Components

None

## User Interactions

- **phx-click="sync" phx-value-provider**: Triggers a manual sync for the given provider by calling `DataSync.sync_integration(scope, provider)`. On success, shows an info flash "Sync started for {platform name}". On `{:error, :not_found}` or `{:error, :not_connected}`, shows an error flash "Integration not found."
- **phx-click="disconnect" phx-value-provider**: Opens the disconnect confirmation modal for the specified provider. Does not delete the integration immediately. Sets `disconnecting_provider` in socket assigns.
- **phx-click="confirm_disconnect"**: Calls `Integrations.delete_integration(scope, provider)` to remove the integration. Shows an info flash "Disconnected from {platform name}. Historical data is retained." Clears `disconnecting_provider` and refreshes the integrations list.
- **phx-click="cancel_disconnect"**: Closes the disconnect confirmation modal by clearing `disconnecting_provider` from assigns. Does not modify any data.

## Design

Layout: Centered single-column page, max-width 3xl, with top padding.

Header row:
- Left: H1 "Integrations" with subtitle "Manage your connected marketing platforms"
- Right: `.btn.btn-primary.btn-sm` link "Connect a Platform" navigating to `/integrations/connect`

Empty state (shown when no integrations exist):
- `.mf-card` centered panel with text "No platforms connected yet." and a `.btn.btn-primary` link "Connect your first platform" navigating to `/integrations/connect`

Connected Platforms section (shown only when at least one integration exists):
- H2 "Connected Platforms"
- One `.mf-card` row per connected platform, flex layout, items spaced between
  - Left: platform name (bold), description (muted), `.badge.badge-success` "Connected"
  - Right: `.btn.btn-ghost.btn-sm` "Manage" link navigating to `/integrations/connect/{provider}`
  - `.btn.btn-ghost.btn-sm` "Sync" button with `data-role="sync-integration"` and `phx-value-provider`
  - `.btn.btn-error.btn-sm` "Disconnect" button with `data-role="disconnect-integration"` and `phx-value-provider`

Available Platforms section (always shown):
- H2 "Available Platforms"
- Responsive grid: 1 column mobile, 2 columns sm, 3 columns lg
- One `.mf-card` per unconnected provider: platform name, description, `.badge.badge-ghost` "Not connected"
- `.btn.btn-primary.btn-sm.w-full` "Connect" button with `data-role="reconnect-integration"` and `phx-value-provider`

Disconnect confirmation modal (shown when `disconnecting_provider` is set):
- `.modal` overlay containing:
  - Warning text "Historical data will remain but no new data will sync."
  - `.btn.btn-error` "Disconnect" confirm button with `data-role="confirm-disconnect"`
  - `.btn.btn-ghost` "Cancel" button with `data-role="cancel-disconnect"`

Components: `.mf-card`, `.btn-primary`, `.btn-ghost`, `.btn-error`, `.badge-success`, `.badge-ghost`, `.modal`

Responsive: Stack cards vertically on mobile; platform grid collapses to single column.
