# MetricFlowWeb.IntegrationLive.Index

Per-platform data management and sync controls for connected integrations. Shows data platforms (Google Analytics, Google Ads, Facebook Ads, QuickBooks) rather than OAuth providers. Each platform maps to a parent OAuth provider (e.g., both Google Analytics and Google Ads map to the Google provider). A platform is "connected" when its parent provider has an active integration. OAuth connection management lives on `/integrations/connect`.

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

- **phx-click="sync" phx-value-platform phx-value-provider**: Triggers a manual sync for the given platform by calling `DataSync.sync_integration(scope, provider)`. On success, shows an info flash "Sync started for {platform name}". On `{:error, :not_found}` or `{:error, :not_connected}`, shows an error flash "Integration not found."
- **phx-click="confirm_disconnect" phx-value-provider**: Opens the disconnect confirmation modal for the specified provider. Warns that disconnecting will affect all platforms using that provider. Does not delete the integration immediately. Sets `disconnecting` in socket assigns.
- **phx-click="disconnect" phx-value-provider**: Calls `Integrations.disconnect(scope, provider)` to remove the integration. Shows an info flash "Disconnected from {provider name}. Historical data is retained." Clears `disconnecting` and refreshes the integrations list.
- **phx-click="cancel_disconnect"**: Closes the disconnect confirmation modal by clearing `disconnecting` from assigns. Does not modify any data.

## Design

Layout: Centered single-column page, max-width 3xl, with top padding.

Header row:
- Left: H1 "Integrations" with subtitle "Manage your connected marketing platforms"
- Right: `.btn.btn-primary.btn-sm` link "Connect a Platform" navigating to `/integrations/connect`

Empty state (shown when no integrations exist):
- Centered panel with text "No platforms connected yet." and a `.btn.btn-primary` link "Connect your first platform" navigating to `/integrations/connect`

Connected Platforms section (shown when at least one platform's parent provider is connected):
- H2 "Connected Platforms"
- One `.mf-card` row per connected platform, with `data-platform="{platform_key}"` and `data-status="connected"`
- Flex layout, items spaced between
  - Left: platform name (bold), description (muted), `.badge.badge-success` "Connected", sync status badge, connected date with provider name, selected accounts
  - Right column:
    - `.btn.btn-outline.btn-sm` "Sync Now" button with `phx-click="sync"`, `phx-value-platform`, and `phx-value-provider`
    - `.btn.btn-ghost.btn-sm` "Edit Accounts" link navigating to `/integrations/connect/{provider}/accounts`
    - `.btn.btn-ghost.btn-xs` "Manage" link navigating to `/integrations/connect/{provider}`
    - `.btn.btn-ghost.btn-xs.text-error` "Disconnect" button with `data-role="disconnect-integration"` and `phx-value-provider`

Available Platforms section (shown when any platform's parent provider is not connected):
- H2 "Available Platforms"
- One `.mf-card` row per unconnected platform with `data-platform="{platform_key}"` and `data-status="available"`
- Shows "Connect {provider name} first" message
- `.btn.btn-primary.btn-sm` "Connect {Provider}" link navigating to `/integrations/connect`

Disconnect confirmation modal (shown when `disconnecting` is set):
- `.modal` overlay containing:
  - Title "Disconnect {provider name}?"
  - Warning text about affecting all platforms using this connection
  - `.btn.btn-error` "Disconnect" confirm button with `data-role="confirm-disconnect"`
  - `.btn` "Cancel" button with `data-role="cancel-disconnect"`

Components: `.mf-card`, `.btn-primary`, `.btn-ghost`, `.btn-error`, `.btn-outline`, `.badge-success`, `.badge-ghost`, `.badge-warning`, `.modal`

Responsive: Stack cards vertically on mobile.
