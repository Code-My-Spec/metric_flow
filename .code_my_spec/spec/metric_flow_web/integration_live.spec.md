# MetricFlowWeb.IntegrationLive

Platform integration management UI views.

## Type

live_context

## LiveViews

### IntegrationLive.Index

- **Route:** `/integrations`
- **Description:** Lists all connected platform integrations for the active account with sync status and quick actions.

### IntegrationLive.Connect

- **Route:** `/integrations/connect`
- **Description:** Provider selection and OAuth connection flow. Displays available providers, initiates OAuth, and handles account selection for multi-account providers.

### IntegrationLive.AccountEdit

- **Route:** `/integrations/:provider/accounts/edit`
- **Description:** Edits integration account settings for a specific provider, such as selected sub-accounts or sync preferences.

### IntegrationLive.ProviderDashboard

- **Route:** `/integrations/:provider/dashboard`
- **Description:** Per-provider dashboard showing sync status, metrics summary, and data sync history for a connected integration.

### IntegrationLive.SyncHistory

- **Route:** `/integrations/sync-history`
- **Description:** Cross-provider sync history log showing all data sync jobs with status, timestamps, and error details.

## Components

None — each LiveView is self-contained.

## Dependencies

- MetricFlow.Integrations
- MetricFlow.DataSync
- MetricFlow.Metrics
- MetricFlow.Reviews
