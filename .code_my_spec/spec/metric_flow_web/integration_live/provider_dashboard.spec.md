# MetricFlowWeb.IntegrationLive.ProviderDashboard

Per-provider data dashboard at `/integrations/:provider/dashboard`. Shows provider-specific synced data in a dedicated control panel: line charts of key metrics over time, recent sync history for this provider, sync now button, connection status, and last synced timestamp. For Google Business Profile, displays review count trend, average rating trend, recent reviews list, and performance metrics. For Google Analytics, shows traffic metrics. For Google Ads, shows ad performance. For QuickBooks, shows financial summary. Each provider dashboard gives users a focused view of their synced data and a concrete surface for QA.

## Type

liveview

## Dependencies

- MetricFlow.Reviews
- MetricFlow.Metrics
- MetricFlow.Integrations
- MetricFlow.DataSync

## Functions

