# MetricFlowWeb.IntegrationLive.Index

Per-platform data management and sync controls for connected integrations. Shows data platforms (Google Analytics, Google Ads, Google Search Console, Google Business, Facebook Ads, QuickBooks) with each platform mapping 1:1 to its own OAuth provider and integration record. A platform is "connected" when it has an active integration. OAuth connection management lives on `/integrations/connect`.

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

- **phx-click="sync" phx-value-platform phx-value-provider**: Triggers a manual sync for the given platform by calling `DataSync.sync_integration(scope, provider)`. On success, adds platform to `syncing` MapSet and shows info flash "Sync started for {platform name}". On `{:error, :not_found}`, shows error flash "{platform name} integration not found. Please connect it first." On `{:error, :not_connected}`, shows error flash "{platform name} token has expired. Please reconnect." Sync Now button is disabled while platform is in `syncing` set or when no accounts are selected.
- **phx-click="confirm_disconnect" phx-value-provider**: Opens the disconnect confirmation modal for the specified provider. Sets `disconnecting` in socket assigns.
- **phx-click="disconnect" phx-value-provider**: Calls `Integrations.disconnect(scope, provider)` to remove the integration. Shows info flash "Disconnected from {provider name}. Historical data is retained; no new data will sync after disconnecting." Clears `disconnecting` and refreshes the integrations list.
- **phx-click="cancel_disconnect"**: Closes the disconnect confirmation modal by clearing `disconnecting` from assigns. Does not modify any data.
- **handle_info {:sync_completed, payload}**: Removes provider from `syncing` MapSet and stores sync result (records_synced, completed_at) in `sync_results` map keyed by platform key. Result displays inline on the connected platform card.
- **handle_info {:sync_failed, payload}**: Removes provider from `syncing` MapSet and shows error flash with failure reason.

## Design

Layout: Centered single-column page, `max-w-3xl` container wrapped in `mf-content` with `px-4 py-8` padding. `data-role="integrations-index"` on outer container.

Header row:
- Left: H1 "Integrations" with subtitle "Manage your connected marketing platforms" in `text-base-content/60`
- Right: `.btn.btn-primary.btn-sm` link "Connect a Platform" navigating to `/integrations/connect`

Empty state (shown when no integrations exist):
- Centered panel with text "No platforms connected yet." and a `.btn.btn-primary.btn-sm` link "Connect your first platform" navigating to `/integrations/connect`

Connected Platforms section (shown when at least one platform has an active integration):
- H2 "Connected Platforms"
- `data-role="integrations-list"` container with `space-y-4`
- One `.mf-card` row per connected platform with `data-role="integration-card"`, `data-platform="{platform_key}"`, and `data-status="connected"`
- Flex layout (`data-role="integration-row"`), items spaced between
  - Left column:
    - Platform name in `font-semibold` (`data-role="integration-platform-name"`)
    - Description in `text-sm text-base-content/60`
    - `.badge.badge-success` "Connected" with `data-status="connected"`
    - Sync status (`data-role="integration-sync-status"`): `.badge.badge-warning` "Syncing" with loading spinner while sync in progress; `.badge.badge-success` with "Synced {n} records at {datetime} UTC" after completion
    - Connected date (`data-role="integration-connected-date"`): "Connected as {email} via {provider name} on {date}"
    - Selected accounts (`data-role="integration-selected-accounts"`): displays provider-specific account identifier or "No accounts selected" in italic
  - Right column:
    - `.btn.btn-outline.btn-sm` "Sync Now" button with `phx-click="sync"`, `phx-value-platform`, `phx-value-provider`, disabled when syncing or no accounts selected
    - "Edit Accounts" link (`data-role="edit-integration-accounts"`) navigating to `/integrations/connect/{provider}/accounts` — `.btn.btn-primary.btn-sm` when no accounts selected, `.btn.btn-ghost.btn-sm` otherwise
    - "Manage" link (`data-role="integration-detail-link"`) navigating to `/integrations/connect/{provider}`, `.btn.btn-ghost.btn-xs`
    - "Disconnect" button (`data-role="disconnect-integration"`) with `phx-click="confirm_disconnect"`, `.btn.btn-ghost.btn-xs.text-error`

Available Platforms section (shown when any platform has no active integration):
- H2 "Available Platforms"
- `data-role="available-platforms-list"` container
- One `.mf-card` row per unconnected platform with `data-role="integration-card"`, `data-platform="{platform_key}"`, `data-status="available"`
- `.badge.badge-ghost` "Not connected"
- "Connect {provider name} first" message
- `.btn.btn-primary.btn-sm` "Connect {Provider}" link (`data-role="reconnect-integration"`) navigating to `/integrations/connect`

Disconnect confirmation modal (shown when `disconnecting` is set):
- `dialog.modal.modal-open` with `data-role="disconnect-modal"`
- Title "Disconnect {provider name}?"
- Warning text: "Are you sure you want to disconnect {provider}? This will affect all platforms that use this connection. Historical data will remain available, but no new data will sync after disconnecting." (`data-role="disconnect-warning"`)
- `.btn.btn-error` "Disconnect" confirm button with `data-role="confirm-disconnect"`
- `.btn` "Cancel" button with `data-role="cancel-disconnect"`
- Modal backdrop with cancel click handler

Components: `.mf-card`, `.btn-primary`, `.btn-ghost`, `.btn-error`, `.btn-outline`, `.badge-success`, `.badge-ghost`, `.badge-warning`, `.modal`, `.loading`

Responsive: Stack cards vertically on mobile.

