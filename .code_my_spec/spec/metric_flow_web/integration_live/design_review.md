# Design Review

## Overview

Reviewed MetricFlowWeb.IntegrationLive context with 5 child components: Index, Connect, AccountEdit, ProviderDashboard, and SyncHistory. The architecture is sound after fixing three consistency issues across specs. Each LiveView has a clear responsibility with appropriate separation between OAuth connection management (Connect), data platform management (Index), per-provider analytics (ProviderDashboard), account configuration (AccountEdit), and sync monitoring (SyncHistory).

## Architecture

- Clean separation between OAuth providers (Connect) and data platforms (Index) — Google OAuth covers both Analytics and Ads, presented correctly
- Each LiveView is self-contained with no shared components, which is appropriate given the distinct page purposes
- Dependencies are well-scoped: Index needs both Integrations and DataSync for sync controls; SyncHistory only needs DataSync; ProviderDashboard needs all four contexts for its comprehensive dashboard
- AccountEdit correctly delegates to Integrations only — no unnecessary dependencies
- Connect spec properly documents the OAuth callback controller as a separate route, maintaining the LiveView/controller boundary

## Integration

- Index links to Connect (`/integrations/connect`) for new connections and to AccountEdit (`/integrations/:provider/accounts/edit`) for account selection
- Connect handles OAuth flow and redirects back to itself with flash messages on completion
- ProviderDashboard pulls from Integrations (connection status), Metrics (charts), Reviews (google_business only), and DataSync (sync history and manual sync)
- SyncHistory receives live PubSub events from sync workers, providing real-time updates alongside persisted history
- All views redirect unauthenticated users to login via router plug

## Issues

- **AccountEdit type was `module`, changed to `liveview`**: It has mount/handle_params/handle_event/render functions and a route in the context spec — it is a LiveView. Added missing Route section.
- **Context spec missing `MetricFlow.Reviews` dependency**: ProviderDashboard depends on Reviews for the google_business reviews section, but the context spec did not list it. Added to context dependencies.
- **Index Edit Accounts link pointed to wrong route**: Was `/integrations/connect/{provider}/accounts`, corrected to `/integrations/{provider}/accounts/edit` to match AccountEdit's route.

## Conclusion

The IntegrationLive context is ready for implementation. All dependencies are verified against the architecture, test assertions are consistent and non-contradictory, and the three issues found have been fixed in the spec files.
