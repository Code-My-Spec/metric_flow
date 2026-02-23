# Monitoring and Observability

**Status:** Proposed
**Date:** 2026-02-21

## Context

MetricFlow is a Phoenix 1.8 LiveView SaaS application deployed to Fly.io. The project already ships with
`telemetry_metrics ~> 1.0`, `telemetry_poller ~> 1.0`, and `phoenix_live_dashboard ~> 0.8.3`. All three
are wired up in `MetricFlowWeb.Telemetry`, which collects Phoenix endpoint, router dispatch, channel, Ecto
query, and BEAM VM metrics. LiveDashboard is currently gated behind `dev_routes` and is not exposed in
production.

The project uses Oban `~> 2.2` for background jobs including data sync workers and scheduled jobs. Oban
emits rich telemetry events covering job start, stop, exception, and drain that any monitoring integration
can consume.

Four distinct needs must be addressed:

1. **Error tracking** - Capture, group, and alert on unhandled exceptions in production. This is the
   highest-priority need: without it there is no visibility into crashes in web requests or Oban workers.
2. **Application Performance Monitoring (APM)** - Request latency percentiles, slow Ecto queries,
   background job throughput, and queue depth. Important for diagnosing degradation as data sync volume
   grows.
3. **Business and operational metrics** - Sync success rates, API call counts by provider, token
   expiry events, correlation job durations. These are MetricFlow-specific and must be emitted as custom
   telemetry events.
4. **Alerting** - Pagerduty-style or email/Slack notification when syncs fail, tokens expire, or
   error rates spike.

At the current early stage (fewer than 100 accounts), the tooling choice is cost-sensitive. The project
should not pay hundreds of dollars per month for monitoring before reaching meaningful traffic. However,
a gap in error visibility is not acceptable: a silent exception loop would be undetected until a user
complains.

The deployment decision already noted that Fly.io's built-in metrics endpoint and log shipping should be
evaluated as an integration target, and that `telemetry_metrics` and `telemetry_poller` are in place.

---

## Options Considered

### Option A: Sentry (error tracking) + Fly.io built-in metrics (APM)

**What it is.** Sentry is the dominant open-source error tracking platform. The `sentry` Hex package
(v11.0.4, 72.9M all-time downloads, last release September 2025) is the official Elixir SDK maintained by
Sentry. It integrates with Phoenix via `Sentry.PlugContext` and `Sentry.PlugCapture`, and captures process
crashes via `Sentry.LoggerHandler`. Since v10.2.0 it includes a first-class Oban integration that captures
job exceptions and optionally reports Oban cron check-ins (requires Oban 2.17.6+, which is within the
`~> 2.2` constraint).

Fly.io's built-in Prometheus scraping is included at no extra cost. By adding a `[metrics]` section to
`fly.toml` pointing at a PromEx or custom Prometheus endpoint, Fly will scrape every 15 seconds and make
data available in a managed Grafana instance at `fly-metrics.net`. PromEx (v1.11.0, 4.3M downloads)
provides pre-built Grafana dashboards for Phoenix, Ecto, Phoenix LiveView, Oban, and the BEAM VM as a
single library with optional per-plugin deps.

**Error tracking features:**
- Unhandled exceptions with stack traces, request context, user identity
- Oban job failures and cron check-in monitoring
- Logger handler catches process crashes not originating from web requests
- Tracing (distributed transactions) added in v11.0.0, currently in beta for Elixir

**APM features (via PromEx + Fly metrics):**
- Phoenix endpoint latency, router dispatch times per route
- Ecto query times (total, queue, decode)
- BEAM VM metrics (memory, run queue lengths, process count)
- Phoenix LiveView mount/handle_event latency
- Oban job duration, queue depth, failure rates
- Custom business metrics emitted via `:telemetry.execute/3`

**Pricing:**
- Sentry Developer plan: free forever, 5,000 errors/month, 1 user. Sufficient for early stage.
- Sentry Team plan: $29/month (monthly billing), 50K errors and 5M tracing spans. Reasonable for growth.
- Fly built-in metrics: included with all Fly plans, no additional cost. Managed Grafana at fly-metrics.net
  is also free.
- PromEx: free open-source library.

**Pros:**
- Sentry error tracking has a permanently free tier adequate for early production
- Sentry's Elixir SDK is mature, actively maintained, and has first-class Oban support
- Fly's built-in Prometheus + managed Grafana is already paid for as part of the hosting platform
- PromEx covers every library in the stack (Phoenix, Ecto, LiveView, Oban, BEAM) with pre-built dashboards
- Total additional cost at early stage: $0 (Sentry free tier + Fly included metrics)
- Both tools build on top of `telemetry_metrics` and `telemetry_poller` already in the project
- PromEx integrates cleanly with the existing `MetricFlowWeb.Telemetry` supervisor pattern

**Cons:**
- Two separate tools require two separate setups and two separate alert configurations
- Fly's managed Grafana is adequate but not as polished for alerting workflows as dedicated APM vendors
- Sentry's Elixir tracing (APM spans) is beta as of v11.0.0; performance monitoring for Elixir is behind
  the Ruby/Python/JS SDK maturity
- Alert configuration on Fly metrics requires learning Grafana's alerting UI, which has a steeper curve
  than purpose-built APM alerting
- PromEx last release was October 2024 (v1.11.0); maintenance cadence has slowed, though the library is
  feature-complete

---

### Option B: AppSignal (all-in-one APM + error tracking)

**What it is.** AppSignal is a Dutch APM vendor focused exclusively on Ruby, Elixir, and Node.js. The
`appsignal` Hex package (v2.16.0, 8.8M all-time downloads, last release December 2025) provides a single
agent that reports errors, performance traces, and metrics to the AppSignal platform. AppSignal explicitly
supports Oban out of the box since v2.5.0 — it attaches to Oban's telemetry events automatically, creating
performance traces for each job execution and creating error samples on failure. No manual instrumentation
is required.

**Error tracking features:**
- Unhandled exceptions with stack traces and request/job context
- Automatic Oban job error capture (configurable: all errors, only discards, or none)
- Logger handler for process crashes
- Error grouping and alerting

**APM features:**
- Per-request performance traces with Ecto query breakdown
- LiveView performance (mount, handle_event, handle_info)
- Oban job duration, queue time, execution count (tagged by worker, queue, status)
- Host metrics (CPU, memory, load average) from the AppSignal host agent
- Custom metrics via `Appsignal.increment_counter/2`, `Appsignal.add_distribution_value/2`, etc.
- Magic Dashboards automatically generated from instrumented code

**Pricing:**
- Free tier: 50K requests/month, 1GB logging, 5-day retention — resets every 30 days
- Paid: €219/year (€18.25/month) for 250K requests/month, unlimited apps and users
- No overage charges: AppSignal stops monitoring (does not charge) if limits are exceeded

**Pros:**
- Elixir-first vendor — the SDK is built specifically for the BEAM ecosystem, not adapted from another language
- Single dependency covers error tracking, APM, and alerting in one place
- Zero-configuration Oban integration: attaches automatically to telemetry events
- Predictable pricing with no surprise overages
- Active community engagement: AppSignal sponsors the Erlang Ecosystem Foundation
- Alerting (Slack, PagerDuty, email) is built into the platform, no Grafana setup required
- Host metrics (CPU, memory) are included without a separate exporter

**Cons:**
- Free tier (50K requests/month) is modest for a SaaS with active users making multiple requests per session
- At early stage the €18.25/month cost is small but non-zero when combined with Fly.io hosting (~$50/month)
- Less flexibility than self-hosted Prometheus for custom business metric dashboards
- Smaller community than Sentry (8.8M vs 72.9M all-time Hex downloads)
- AppSignal's Elixir SDK wraps around the Ruby agent binaries in some configurations, which can complicate
  cross-compilation in Docker release builds

---

### Option C: Honeybadger (error tracking + Oban dashboard)

**What it is.** Honeybadger is an error monitoring service with a dedicated Elixir Phoenix integration.
The `honeybadger` Hex package (v0.24.1, 2M all-time downloads, last release July 2025) added Phoenix
performance monitoring and a dedicated Oban dashboard in the 0.24.x series. It attaches to Phoenix and
Oban telemetry events automatically and sends performance data to Honeybadger's performance dashboard.

**Error tracking features:**
- Unhandled exceptions with request context
- Oban job failures
- Logger error capture

**APM features (as of 0.24.x):**
- Phoenix request performance dashboard
- Oban job execution dashboard
- Basic Ecto query tracking

**Pricing:**
- Developer (free): 5,000 errors/month, 50MB/day logs, uptime monitoring
- Team: $26/month
- Business: $80/month

**Pros:**
- Free tier covers error tracking with 5,000 errors/month
- New Oban dashboard in 0.24.x is built for exactly this stack
- Simpler pricing model
- Check-ins / heartbeat monitoring included on all plans

**Cons:**
- APM and Oban performance features are new (0.24.x, released 2024); less mature than AppSignal's
  equivalent
- Much lower adoption than Sentry (2M vs 72.9M all-time Hex downloads)
- Performance monitoring depth is thinner than AppSignal — no host metrics, lighter on per-query details
- No BEAM VM metrics built in; would require separate PromEx or Prometheus exporter for VM monitoring
- Slower release cadence; last release July 2025 (5+ months behind AppSignal's December 2025)

---

### Option D: New Relic (full APM)

**What it is.** New Relic provides APM, infrastructure monitoring, logging, and alerting in one platform.
The `new_relic_agent` Hex package provides Elixir integration.

**Pros:**
- Full observability stack in one vendor
- Free tier (100GB/month ingest, 1 user)

**Cons:**
- Elixir SDK is not first-party: the `new_relic_agent` package is community-maintained and has seen
  irregular release activity
- No automatic Oban instrumentation; manual telemetry attachment required
- New Relic's mental model and UI are oriented toward Java/Ruby/Python applications; Elixir/BEAM concepts
  (processes, message queues, supervision trees) are not surfaced
- Complex pricing beyond the free tier
- Not recommended by the Elixir community for Phoenix applications

---

### Option E: Self-hosted Prometheus + Grafana

**What it is.** Run a Prometheus instance and Grafana on Fly.io (as separate apps or as a sidecar process)
and scrape PromEx metrics from the application.

**Pros:**
- Full control over dashboards, retention, and alerting rules
- No per-event SaaS cost
- All PromEx dashboards work identically to Option A but with your own infrastructure

**Cons:**
- Significant operational overhead: managing Prometheus storage, Grafana, alerting rules, and uptime on
  Fly.io is a second operational concern alongside the application itself
- No error tracking — a separate error tracking tool would still be required
- At early stage, the engineering time cost of self-hosting monitoring infrastructure is not justified
- Fly.io already provides managed Prometheus + Grafana at no extra cost, which is effectively this option
  without the operational burden

This option is superseded by Option A's use of Fly.io's managed Prometheus + Grafana.

---

## Decision

**Adopt Sentry (free tier) for error tracking plus PromEx with Fly.io's built-in managed Prometheus and
Grafana for APM and metrics.**

This combination covers all four stated needs at zero additional cost for the early stage, while remaining
upgradeable to paid tiers independently as the project grows.

### Rationale

**Error tracking: Sentry**

Sentry's free Developer plan provides 5,000 errors/month, which is adequate until the application reaches
meaningful user load. The `sentry` Hex package is the most widely adopted Elixir error tracking library
(72.9M downloads) with active maintenance and first-class Oban support since v10.2.0. The Oban integration
requires enabling `:integrations` config and is compatible with the project's `oban ~> 2.2` constraint.
The `Sentry.LoggerHandler` ensures process crashes outside of web requests are also captured.

AppSignal is the strongest alternative for error tracking. Its zero-configuration Oban integration and
Elixir-first focus are genuine advantages. However, at early stage the €18.25/month cost is non-trivial
when added to Fly.io hosting, and its 50K request/month free tier is narrow for a multi-user SaaS with
active LiveView sessions (each navigation event is a request). Sentry's 5,000 error/month free tier is
based on error events, not total requests, which maps better to early-stage error budgets.

If APM and error tracking must be combined in one vendor (e.g., to reduce tooling complexity for a solo
developer), **AppSignal is the recommended fallback choice**. Its Elixir-first design and automatic Oban
instrumentation make it the best all-in-one option for this stack.

**APM and metrics: PromEx + Fly.io built-in Prometheus/Grafana**

Fly.io's managed Prometheus and Grafana instance (`fly-metrics.net`) is already included in the hosting
cost. PromEx hooks into the project's existing `MetricFlowWeb.Telemetry` supervisor and publishes a
Prometheus metrics endpoint. Fly scrapes that endpoint every 15 seconds. PromEx provides pre-built Grafana
dashboards for Phoenix, Ecto, Phoenix LiveView, Oban, and BEAM VM metrics — covering every performance
concern listed in the requirements without custom dashboard work.

The `prom_ex` library integrates by extending the telemetry supervisor:

```elixir
# lib/metric_flow_web/prom_ex.ex
defmodule MetricFlowWeb.PromEx do
  use PromEx, otp_app: :metric_flow

  @impl true
  def plugins do
    [
      PromEx.Plugins.Application,
      PromEx.Plugins.Beam,
      {PromEx.Plugins.Phoenix, router: MetricFlowWeb.Router},
      PromEx.Plugins.Ecto,
      {PromEx.Plugins.PhoenixLiveView, duration_unit: :millisecond},
      {PromEx.Plugins.Oban, queue_poll_interval: 5_000}
    ]
  end

  @impl true
  def dashboard_assigns do
    [
      datasource_id: "fly-prometheus",
      default_selected_interval: "30s"
    ]
  end

  @impl true
  def dashboards do
    [
      {:prom_ex, "application.json"},
      {:prom_ex, "beam.json"},
      {:prom_ex, "phoenix.json"},
      {:prom_ex, "ecto.json"},
      {:prom_ex, "phoenix_live_view.json"},
      {:prom_ex, "oban.json"}
    ]
  end
end
```

Add to the supervision tree in `MetricFlow.Application`:

```elixir
children = [
  MetricFlowWeb.Telemetry,
  MetricFlowWeb.PromEx,       # add after Telemetry
  MetricFlow.Infrastructure.Repo,
  # ...
]
```

Expose the metrics endpoint in the router (separate from the authenticated app routes):

```elixir
scope "/" do
  get "/metrics", PromEx.Plug, prom_ex_module: MetricFlowWeb.PromEx
end
```

Configure Fly to scrape it in `fly.toml`:

```toml
[metrics]
  port = 4000
  path = "/metrics"
```

**LiveDashboard in production**

LiveDashboard is already in deps and provides real-time BEAM process inspection, which is useful for
diagnosing production issues via `fly ssh console`. It should be enabled in production behind admin
authentication rather than left dev-only. The router should be updated to expose it behind
`Plug.BasicAuth` or behind the authenticated user pipeline restricted to admin accounts:

```elixir
# In the router, add an admin-gated pipeline
pipeline :admins_only do
  plug :fetch_session
  plug :fetch_current_scope_for_user
  plug :require_admin
end

scope "/admin" do
  pipe_through [:browser, :admins_only]
  import Phoenix.LiveDashboard.Router
  live_dashboard "/dashboard", metrics: MetricFlowWeb.Telemetry
end
```

This makes LiveDashboard a lightweight real-time complement to Grafana for in-the-moment production
debugging — showing live process counts, message queue depths, and custom telemetry metrics.

**Custom business metrics**

MetricFlow-specific metrics (sync success rates, API call counts per provider, token expiry events,
correlation job durations) should be emitted via `:telemetry.execute/3` from the relevant context modules
and then captured by a custom PromEx plugin:

```elixir
# Emit from the data sync context
:telemetry.execute(
  [:metric_flow, :sync, :complete],
  %{duration: duration_ms},
  %{provider: :google_analytics, status: :success}
)

# Capture in a custom PromEx plugin
defmodule MetricFlowWeb.PromEx.Plugins.DataSync do
  use PromEx.Plugin

  @impl true
  def event_metrics(_opts) do
    [
      counter(
        [:metric_flow, :sync, :complete, :count],
        event_name: [:metric_flow, :sync, :complete],
        measurement: fn _measurements -> 1 end,
        tags: [:provider, :status],
        description: "Total data sync completions by provider and status"
      ),
      distribution(
        [:metric_flow, :sync, :complete, :duration],
        event_name: [:metric_flow, :sync, :complete],
        measurement: :duration,
        tags: [:provider, :status],
        unit: {:native, :millisecond},
        description: "Data sync duration in milliseconds"
      )
    ]
  end
end
```

---

## Consequences

**Dependencies to add to `mix.exs`:**

```elixir
{:sentry, "~> 11.0"},
{:prom_ex, "~> 1.11"}
```

PromEx has optional plugin dependencies. The Oban plugin requires no additional deps (Oban is already
present). The Phoenix LiveView plugin requires no additional deps (LiveView already present). No new
infrastructure is required beyond `fly.toml` configuration.

**Environment variables required in production:**

- `SENTRY_DSN` — obtained from Sentry project settings after creating a free account
- No additional env vars for PromEx; it reads from the OTP app config

**`config/runtime.exs` additions:**

```elixir
if config_env() == :prod do
  config :sentry,
    dsn: System.fetch_env!("SENTRY_DSN"),
    environment_name: :prod,
    enable_source_code_context: true,
    root_source_code_paths: [File.cwd!()],
    integrations: [
      oban: [capture_errors: true, monitor_cron_jobs: true]
    ]
end
```

**`MetricFlowWeb.Telemetry` and PromEx coexistence:** Both can run in the same supervision tree. The
existing `MetricFlowWeb.Telemetry` module owns the `telemetry_poller` and the metric definitions used by
LiveDashboard. PromEx runs its own pollers for Prometheus export. They do not conflict.

**Oban version note:** Sentry's Oban cron monitoring requires Oban `>= 2.17.6`. The current constraint is
`~> 2.2`. This will require a minor version bump to `~> 2.17` or `>= 2.17.6, ~> 2.0` before the cron
check-in feature can be used. Error capture from Oban jobs works regardless of version.

**Alerting gap:** Neither PromEx nor Fly's managed Grafana provides out-of-the-box PagerDuty or Slack
alerting as smoothly as AppSignal. Grafana alerting rules must be configured manually in the Fly-managed
Grafana instance. For critical alerts (sync failure rate above threshold, error rate spike), Grafana
alerting should be configured as a follow-up action after the initial PromEx integration is deployed.
Sentry's free tier supports email alerts on new issues automatically.

**Upgrade path:** If monitoring complexity grows — particularly if the team wants correlated traces
linking an HTTP request through to its Oban job and Ecto queries in a single timeline — **AppSignal is
the recommended next step**, not New Relic or a self-hosted OpenTelemetry stack. The AppSignal Elixir
SDK provides distributed tracing across Phoenix and Oban automatically and is significantly more
Elixir-idiomatic than OpenTelemetry's Elixir SDK.

**LiveDashboard in production:** The router currently gates LiveDashboard behind `dev_routes`. This
should be moved to a production-accessible admin route before the first production deployment. Without
this, real-time BEAM inspection (process counts, memory by process, message queue depths) is unavailable
when diagnosing production incidents. Accessing it via `fly ssh console` and `iex` is an alternative
but less ergonomic.
