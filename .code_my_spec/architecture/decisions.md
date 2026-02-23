# Architecture Decision Records

| # | Decision | Status | Summary |
|---|----------|--------|---------|
| 1 | [Elixir](decisions/elixir.md) | Accepted | Elixir ~> 1.19 on the BEAM VM for concurrency, fault tolerance, and real-time features |
| 2 | [Phoenix](decisions/phoenix.md) | Accepted | Phoenix ~> 1.8.1 with Bandit web server |
| 3 | [LiveView](decisions/liveview.md) | Accepted | Phoenix LiveView ~> 1.1.0 as primary UI framework |
| 4 | [Tailwind CSS](decisions/tailwind.md) | Accepted | Tailwind CSS via `tailwind` Mix package for utility-first styling |
| 5 | [CSS Component Library](decisions/css_component_library.md) | Accepted | Tailwind CSS + DaisyUI with theme system for agency white-labeling |
| 6 | [DaisyUI](decisions/daisyui.md) | Accepted | DaisyUI as Tailwind CSS component plugin for semantic classes and theming |
| 7 | [phx.gen.auth](decisions/phx-gen-auth.md) | Accepted | Built-in authentication with Scope pattern for multi-tenant scoping |
| 8 | [Authorization Strategy](decisions/authorization_strategy.md) | Accepted | phx.gen.auth Scope pattern + hand-rolled Accounts.Authorization module, no external library |
| 9 | [BDD Testing](decisions/bdd-testing.md) | Accepted | SexySpex BDD framework with given/when/then pattern mapped to user stories |
| 10 | [E2E Testing](decisions/e2e_testing.md) | Accepted | SexySpex BDD + ReqCassette for Req providers + TestRecorder for Tesla/Google API providers, no browser testing |
| 11 | [ExVCR](decisions/exvcr.md) | Rejected | Rejected in favor of ReqCassette + TestRecorder (Hackney incompatible with Req/Finch) |
| 12 | [LLM Provider](decisions/llm_provider.md) | Accepted | Anthropic Claude via ReqLLM — Sonnet 4.5 for chat/reports, Haiku 4.5 for batch insights |
| 13 | [Charting Library](decisions/charting_library.md) | Proposed | vega-embed for client-side Vega-Lite rendering + vega_lite Elixir package for server-side spec building |
| 14 | [Data Provider APIs](decisions/data_provider_apis.md) | Accepted | Google API Elixir client for GA4, raw Req for Google Ads / Facebook Ads / QuickBooks |
| 15 | [Background Job Processing](decisions/background_job_processing.md) | Accepted | Oban open-source with 3 queues (default, sync, correlations), Cron/Pruner/Lifeline plugins |
| 16 | [Correlation Engine](decisions/correlation_engine.md) | Proposed | Pure Elixir initial implementation with Explorer upgrade path for performance |
| 17 | [Caching Strategy](decisions/caching_strategy.md) | Proposed | PostgreSQL materialized views for dashboards + Cachex for computed results, no Redis |
| 18 | [OAuth Token Refresh](decisions/oauth_token_refresh.md) | Proposed | Reactive refresh via Assent.Strategy.OAuth2.refresh_access_token/3, provider-specific handling |
| 19 | [Deployment](decisions/deployment.md) | Proposed | Fly.io with managed PostgreSQL, BEAM clustering via dns_cluster, wildcard TLS for white-label |
| 20 | [Email Provider](decisions/email_provider.md) | Proposed | Postmark via Swoosh adapter — unlimited sender domains for agency white-label at $18/month |
| 21 | [File Storage](decisions/file_storage.md) | Proposed | Tigris (Fly.io native S3-compatible) for agency logos and report exports — zero egress, automatic CDN caching |
| 22 | [Monitoring & Observability](decisions/monitoring_observability.md) | Proposed | Sentry (free tier) for errors + PromEx with Fly.io managed Prometheus/Grafana for APM |
| 23 | [Report Export](decisions/report_export.md) | Proposed | Phased: browser print + CSV in Phase 1, ChromicPDF in Phase 2 when report template stabilizes |
| 24 | [Environment Variables](decisions/dotenvy.md) | Proposed | Dotenvy for local development .env file loading |
| 25 | [ngrok](decisions/ngrok.md) | Proposed | ngrok for local OAuth development tunneling |
