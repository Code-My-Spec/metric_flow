# Monitoring and Observability Setup

This document covers the full monitoring stack for MetricFlow in production: Sentry for error
tracking, PromEx with Fly.io's managed Prometheus and Grafana for APM and metrics, LiveDashboard
behind admin authentication, and custom telemetry events for business metrics.

See the decision record at `docs/architecture/decisions/monitoring_observability.md` for the
rationale behind these choices.

---

## 1. Dependencies

Add to `mix.exs`:

```elixir
defp deps do
  [
    # ... existing deps ...
    {:sentry, "~> 11.0"},
    {:prom_ex, "~> 1.11"}
  ]
end
```

Run `mix deps.get` after updating.

PromEx has no mandatory new transitive dependencies for the plugins used in this project. The Oban
plugin uses the `oban` package already present. The Phoenix LiveView plugin uses `phoenix_live_view`
already present. No additional infrastructure is needed.

---

## 2. Sentry — Error Tracking

### 2.1 Account Setup

1. Create a free account at https://sentry.io
2. Create a new project, select "Elixir" as the platform
3. Copy the DSN from the project settings (format: `https://<key>@<org>.ingest.sentry.io/<project-id>`)
4. Set the secret in production: `fly secrets set SENTRY_DSN=https://...`

### 2.2 config/runtime.exs

Add inside the `if config_env() == :prod do` block:

```elixir
if config_env() == :prod do
  # ... existing prod config ...

  config :sentry,
    dsn: System.fetch_env!("SENTRY_DSN"),
    environment_name: :prod,
    enable_source_code_context: true,
    root_source_code_paths: [File.cwd!()],
    integrations: [
      oban: [
        capture_errors: true,
        monitor_cron_jobs: true
      ]
    ]
end
```

`enable_source_code_context` requires `root_source_code_paths` pointing at the project root so
Sentry can read source lines around each exception frame. In a Fly.io Docker release the working
directory during `File.cwd!()` is `/app`, which matches where `mix release` places source files
when `COPY . .` is included in the Dockerfile.

`monitor_cron_jobs: true` requires Oban `>= 2.17.6`. The current constraint `~> 2.2` allows this
version; update `mix.exs` to `{:oban, "~> 2.17"}` before enabling it. Error capture from Oban
jobs works at any version within the `~> 2.2` range.

### 2.3 Plug Integration (Phoenix request context)

Add two plugs to `lib/metric_flow_web/endpoint.ex` after `plug Plug.RequestId`:

```elixir
plug Sentry.PlugContext
plug Sentry.PlugCapture
```

`Sentry.PlugContext` enriches every Sentry event with request metadata (URL, HTTP method, params,
user agent). `Sentry.PlugCapture` catches unhandled exceptions from within plug pipelines and
reports them before re-raising.

### 2.4 Logger Handler (process crashes)

Add to `config/config.exs` in the logger section, or in `config/prod.exs` if you want it only in
production:

```elixir
config :logger,
  backends: [:console],
  handle_otp_reports: true,
  handle_sasl_reports: true
```

Then add the Sentry handler in `config/runtime.exs` inside the prod block:

```elixir
config :logger,
  handlers: [
    {Sentry.LoggerHandler, %{capture_log_messages: true, level: :error}}
  ]
```

`Sentry.LoggerHandler` captures logger events at `:error` level and above that originate from
process crashes, `GenServer` terminations, and any code calling `Logger.error/2` explicitly. This
catches crashes in Oban workers, GenServers, and supervision tree failures that do not go through
the Phoenix plug pipeline.

### 2.5 User Identity in Sentry Events

To associate errors with a specific user, set the Sentry scope from authenticated LiveView sessions
or plug pipelines. The cleanest place in this project is an `on_mount` hook for authenticated
LiveView sessions:

```elixir
# In MetricFlowWeb.UserAuth or a dedicated Sentry hook module
defp set_sentry_user(%{assigns: %{current_scope: scope}} = socket) when not is_nil(scope) do
  Sentry.Context.set_user_context(%{
    id: scope.user.id,
    email: scope.user.email
  })
  socket
end

defp set_sentry_user(socket), do: socket
```

Call `set_sentry_user(socket)` at the end of each `on_mount` callback that sets `current_scope`.

### 2.6 Testing Sentry Integration

Sentry is a no-op in test and dev environments by default (no DSN configured). To verify the
integration works in production without triggering a real error, use:

```elixir
# In an iex console on the production node via `fly ssh console`
Sentry.capture_message("MetricFlow Sentry connectivity test", level: :info)
```

Check the Sentry project dashboard for the event within 30 seconds.

---

## 3. PromEx — Prometheus Metrics

### 3.1 PromEx Module

Create `lib/metric_flow_web/prom_ex.ex`:

```elixir
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

Each plugin covers:

| Plugin | Metrics |
|--------|---------|
| `Application` | OTP application uptime, version metadata |
| `Beam` | Memory (total, atom, binary, ets, process), run queue lengths, process count, scheduler utilization, GC counts |
| `Phoenix` | Endpoint request count and duration (by route, method, status), router dispatch times, socket connections |
| `Ecto` | Query total time, query time, queue time, decode time (tagged by repo and query source) |
| `PhoenixLiveView` | Mount duration, handle_event duration, handle_info duration (tagged by view module and event name) |
| `Oban` | Job count by queue/state, job execution duration, job queue time, job failure rate, queue depth |

### 3.2 Supervision Tree

In `lib/metric_flow/application.ex`, add `MetricFlowWeb.PromEx` after `MetricFlowWeb.Telemetry`:

```elixir
@impl true
def start(_type, _args) do
  children = [
    MetricFlowWeb.Telemetry,
    MetricFlowWeb.PromEx,        # add here, after Telemetry
    MetricFlow.Infrastructure.Repo,
    MetricFlow.Infrastructure.Vault,
    {DNSCluster, query: Application.get_env(:metric_flow, :dns_cluster_query) || :ignore},
    {Phoenix.PubSub, name: MetricFlow.PubSub},
    {Oban, Application.fetch_env!(:metric_flow, Oban)},
    MetricFlowWeb.Endpoint
  ]

  opts = [strategy: :one_for_one, name: MetricFlow.Supervisor]
  Supervisor.start_link(children, opts)
end
```

`MetricFlowWeb.Telemetry` and `MetricFlowWeb.PromEx` coexist without conflict. The existing
`Telemetry` module owns the `telemetry_poller` and the metric definitions consumed by LiveDashboard.
PromEx runs its own internal pollers for Prometheus export. Both subscribe to telemetry events
independently.

### 3.3 Metrics Endpoint in the Router

Add a metrics route to `lib/metric_flow_web/router.ex`. This scope must be outside all existing
pipelines so Fly's scraper can reach it without authentication:

```elixir
# Add at the top of the router, before the browser pipeline scopes
scope "/" do
  get "/metrics", PromEx.Plug, prom_ex_module: MetricFlowWeb.PromEx
end
```

The `/metrics` endpoint returns Prometheus text-format exposition. It should not be placed behind
any authentication plug. Fly.io's internal metrics scraper connects from within the private WireGuard
network (Fly's `6pn` addresses), not from the public internet, so this endpoint is not reachable
by external parties.

If you want additional protection (belt-and-suspenders), you can restrict access by IP in the plug:

```elixir
# lib/metric_flow_web/plugs/metrics_auth.ex
defmodule MetricFlowWeb.Plugs.MetricsAuth do
  import Plug.Conn

  # Fly.io private network uses fd... IPv6 addresses
  def init(opts), do: opts

  def call(%{remote_ip: {0xfd, _, _, _, _, _, _, _}} = conn, _opts), do: conn
  def call(%{remote_ip: {127, 0, 0, 1}} = conn, _opts), do: conn

  def call(conn, _opts) do
    conn
    |> send_resp(403, "Forbidden")
    |> halt()
  end
end
```

Then compose it in the route:

```elixir
scope "/" do
  pipe_through [MetricFlowWeb.Plugs.MetricsAuth]
  get "/metrics", PromEx.Plug, prom_ex_module: MetricFlowWeb.PromEx
end
```

### 3.4 PromEx Configuration

Add to `config/config.exs`:

```elixir
config :metric_flow, MetricFlowWeb.PromEx,
  manual_metrics_start_delay: :no_delay,
  drop_metrics_groups: [],
  grafana: :disabled,
  metrics_server: :disabled
```

`grafana: :disabled` means PromEx will not attempt to automatically push dashboards to a Grafana
instance. Dashboard upload is a one-time manual step (see section 5 below). `metrics_server:
:disabled` tells PromEx not to start its own HTTP server because the router handles the endpoint.

---

## 4. Fly.io Prometheus Scraping Configuration

### 4.1 fly.toml [metrics] Section

Add this section to `fly.toml`:

```toml
[metrics]
  port = 4000
  path = "/metrics"
```

`port` must match the HTTP port the application listens on. The default in `config/runtime.exs` is
`String.to_integer(System.get_env("PORT") || "4000")`, so `4000` is correct unless `PORT` is
overridden.

Fly scrapes the endpoint every 15 seconds. After deploying, metrics appear in the Fly-managed
Grafana instance at `https://fly-metrics.net` within a few minutes. Log in with your Fly.io
account credentials to access it.

### 4.2 Verifying the Scrape is Working

SSH into the running machine and check the metrics endpoint directly:

```bash
fly ssh console --app metric-flow
curl http://localhost:4000/metrics | head -40
```

You should see lines like:

```
# HELP beam_memory_total Total memory currently used by Erlang
# TYPE beam_memory_total gauge
beam_memory_total{} 52428800
# HELP phoenix_http_requests_total Total number of Phoenix HTTP requests
# TYPE phoenix_http_requests_total counter
phoenix_http_requests_total{method="GET",route="/",status="200"} 42
```

If the endpoint returns a 404, check that the `PromEx.Plug` route is correctly added to the router
and that the app restarted after the deploy.

### 4.3 Fly Grafana Access

Navigate to https://fly-metrics.net and log in with your Fly.io account. The metrics namespace
will be `<app-name>`, and the default Prometheus data source is already configured. PromEx's
bundled Grafana dashboards (JSON files in the PromEx package) can be imported manually through
the Grafana UI (Dashboard -> Import -> Upload JSON file). Find the JSON files in:

```
_build/dev/lib/prom_ex/priv/grafana_dashboards/
```

Dashboard files to import:

- `application.json`
- `beam.json`
- `phoenix.json`
- `ecto.json`
- `phoenix_live_view.json`
- `oban.json`

When importing each file, set the data source to the Fly Prometheus data source (typically named
`Prometheus` in the fly-metrics.net Grafana instance).

---

## 5. Custom Business Metric Telemetry Events

MetricFlow has domain-specific operations that are not covered by the standard PromEx plugins.
These require custom telemetry events emitted from context modules and captured by a custom
PromEx plugin.

### 5.1 Defining the Event Naming Convention

All MetricFlow-specific telemetry events follow this naming pattern:

```
[:metric_flow, <context>, <action>]
```

Examples:
- `[:metric_flow, :sync, :complete]` — a data sync finished
- `[:metric_flow, :sync, :token_refresh]` — an OAuth token was refreshed during sync
- `[:metric_flow, :oauth, :callback]` — OAuth callback received and processed
- `[:metric_flow, :integration, :connected]` — user connected a new integration

### 5.2 Emitting Events from Context Modules

Emit events using `:telemetry.execute/3` at the point where the action completes. Always
emit at both success and failure paths so counters reflect total attempts with status tags.

In `MetricFlow.DataSync.SyncWorker` (the Oban worker that runs syncs):

```elixir
defp emit_sync_complete(provider, status, duration_ms) do
  :telemetry.execute(
    [:metric_flow, :sync, :complete],
    %{duration: duration_ms},
    %{provider: to_string(provider), status: to_string(status)}
  )
end

# Call at the end of perform/1:
# emit_sync_complete(provider, :success, duration)
# emit_sync_complete(provider, :failed, duration)
```

In `MetricFlow.Integrations` when a token refresh occurs:

```elixir
defp emit_token_refresh(provider, status) do
  :telemetry.execute(
    [:metric_flow, :sync, :token_refresh],
    %{count: 1},
    %{provider: to_string(provider), status: to_string(status)}
  )
end
```

In `MetricFlowWeb.IntegrationCallbackController` after a successful OAuth callback:

```elixir
defp emit_oauth_callback(provider, status) do
  :telemetry.execute(
    [:metric_flow, :oauth, :callback],
    %{count: 1},
    %{provider: to_string(provider), status: to_string(status)}
  )
end
```

### 5.3 Custom PromEx Plugin

Create `lib/metric_flow_web/prom_ex/plugins/data_sync.ex`:

```elixir
defmodule MetricFlowWeb.PromEx.Plugins.DataSync do
  @moduledoc """
  PromEx plugin for MetricFlow business metric telemetry events.

  Captures custom telemetry events emitted from MetricFlow context modules
  and exports them as Prometheus metrics for the Fly.io Grafana instance.
  """

  use PromEx.Plugin

  @impl true
  def event_metrics(_opts) do
    [
      # Sync completion counter: total syncs by provider and outcome
      counter(
        [:metric_flow, :sync, :complete, :count],
        event_name: [:metric_flow, :sync, :complete],
        measurement: fn _measurements -> 1 end,
        tags: [:provider, :status],
        tag_values: fn metadata ->
          %{
            provider: Map.get(metadata, :provider, "unknown"),
            status: Map.get(metadata, :status, "unknown")
          }
        end,
        description: "Total data sync completions, tagged by provider and status (success/failed)"
      ),

      # Sync duration distribution: latency histogram by provider and outcome
      distribution(
        [:metric_flow, :sync, :complete, :duration],
        event_name: [:metric_flow, :sync, :complete],
        measurement: :duration,
        tags: [:provider, :status],
        tag_values: fn metadata ->
          %{
            provider: Map.get(metadata, :provider, "unknown"),
            status: Map.get(metadata, :status, "unknown")
          }
        end,
        unit: {:native, :millisecond},
        description: "Data sync duration in milliseconds, tagged by provider and status"
      ),

      # Token refresh counter: how often tokens are being refreshed
      counter(
        [:metric_flow, :sync, :token_refresh, :count],
        event_name: [:metric_flow, :sync, :token_refresh],
        measurement: fn _measurements -> 1 end,
        tags: [:provider, :status],
        tag_values: fn metadata ->
          %{
            provider: Map.get(metadata, :provider, "unknown"),
            status: Map.get(metadata, :status, "unknown")
          }
        end,
        description: "OAuth token refresh attempts during sync, tagged by provider and status"
      ),

      # OAuth callback counter: integration connection events
      counter(
        [:metric_flow, :oauth, :callback, :count],
        event_name: [:metric_flow, :oauth, :callback],
        measurement: fn _measurements -> 1 end,
        tags: [:provider, :status],
        tag_values: fn metadata ->
          %{
            provider: Map.get(metadata, :provider, "unknown"),
            status: Map.get(metadata, :status, "unknown")
          }
        end,
        description: "OAuth callback completions, tagged by provider and status (success/error)"
      )
    ]
  end
end
```

### 5.4 Registering the Custom Plugin

Add the custom plugin to `MetricFlowWeb.PromEx.plugins/0`:

```elixir
@impl true
def plugins do
  [
    PromEx.Plugins.Application,
    PromEx.Plugins.Beam,
    {PromEx.Plugins.Phoenix, router: MetricFlowWeb.Router},
    PromEx.Plugins.Ecto,
    {PromEx.Plugins.PhoenixLiveView, duration_unit: :millisecond},
    {PromEx.Plugins.Oban, queue_poll_interval: 5_000},
    MetricFlowWeb.PromEx.Plugins.DataSync    # add here
  ]
end
```

### 5.5 Useful Business Metric Queries in Grafana

Once the plugin is deployed, use these PromQL queries in Grafana panels:

**Sync success rate over the last 1 hour:**
```promql
sum(rate(metric_flow_sync_complete_count{status="success"}[1h]))
/
sum(rate(metric_flow_sync_complete_count[1h]))
```

**Sync failure rate by provider:**
```promql
sum by (provider) (rate(metric_flow_sync_complete_count{status="failed"}[1h]))
```

**95th percentile sync duration by provider:**
```promql
histogram_quantile(0.95, sum by (provider, le) (rate(metric_flow_sync_complete_duration_milliseconds_bucket[1h])))
```

**Token refresh rate (elevated rate signals token management issues):**
```promql
sum by (provider) (rate(metric_flow_sync_token_refresh_count[1h]))
```

---

## 6. LiveDashboard in Production

### 6.1 Why Enable it in Production

LiveDashboard provides real-time BEAM process inspection. In production it enables:
- Live view of process counts, run queue lengths, memory breakdown
- ETS table sizes and contents
- Live request log with timing
- Custom metrics from `MetricFlowWeb.Telemetry.metrics/0`

Without a production route, diagnosing performance issues requires SSH + `iex` + manual calls
to `:erlang.process_info/1`, which is slower and harder than a dashboard view.

### 6.2 Admin Authentication Plug

Create `lib/metric_flow_web/plugs/require_admin.ex`:

```elixir
defmodule MetricFlowWeb.Plugs.RequireAdmin do
  @moduledoc """
  Plug that restricts access to admin-only routes.

  Redirects unauthenticated users to the login page.
  Returns 403 for authenticated non-admin users.

  Admin status is determined by the user having `role: :admin` on their
  account record. Update this check as the authorization model evolves.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2, put_flash: 3]

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.assigns[:current_scope] do
      nil ->
        conn
        |> put_flash(:error, "You must be logged in to access this page.")
        |> redirect(to: "/users/log-in")
        |> halt()

      %{user: %{role: :admin}} ->
        conn

      _non_admin ->
        conn
        |> send_resp(403, "Forbidden")
        |> halt()
    end
  end
end
```

Note: This assumes a `role` field on the user schema. If the user schema does not yet have an
admin role, use `Plug.BasicAuth` as a temporary alternative (see section 6.3).

### 6.3 Alternative: Plug.BasicAuth (if no admin role yet)

If the user schema does not yet have role-based access control, use HTTP Basic Auth as a
stopgap. This is acceptable because Fly.io enforces TLS in production, so credentials are
encrypted in transit.

Add to `config/runtime.exs` inside the prod block:

```elixir
config :metric_flow, :dashboard_username,
  System.get_env("DASHBOARD_USERNAME") || raise("DASHBOARD_USERNAME env var missing")

config :metric_flow, :dashboard_password,
  System.get_env("DASHBOARD_PASSWORD") || raise("DASHBOARD_PASSWORD env var missing")
```

Set the secrets: `fly secrets set DASHBOARD_USERNAME=admin DASHBOARD_PASSWORD=<strong-password>`

Then define a plug:

```elixir
defmodule MetricFlowWeb.Plugs.DashboardBasicAuth do
  def init(opts), do: opts

  def call(conn, _opts) do
    username = Application.fetch_env!(:metric_flow, :dashboard_username)
    password = Application.fetch_env!(:metric_flow, :dashboard_password)

    Plug.BasicAuth.basic_auth(conn, username: username, password: password)
  end
end
```

### 6.4 Router Changes

Replace the dev-only LiveDashboard block in `lib/metric_flow_web/router.ex` with a production
route. Keep the dev block as-is and add a new production-accessible route:

```elixir
# Keep existing dev block unchanged
if Application.compile_env(:metric_flow, :dev_routes) do
  import Phoenix.LiveDashboard.Router

  scope "/dev" do
    pipe_through :browser
    live_dashboard "/dashboard", metrics: MetricFlowWeb.Telemetry
    forward "/mailbox", Plug.Swoosh.MailboxPreview
  end
end

# Add new admin-gated production route
import Phoenix.LiveDashboard.Router

pipeline :admins_only do
  plug :fetch_session
  plug :fetch_current_scope_for_user
  plug MetricFlowWeb.Plugs.RequireAdmin
  # Or, using BasicAuth as the temporary alternative:
  # plug MetricFlowWeb.Plugs.DashboardBasicAuth
end

scope "/admin" do
  pipe_through [:browser, :admins_only]

  live_dashboard "/dashboard",
    metrics: MetricFlowWeb.Telemetry,
    ecto_repos: [MetricFlow.Infrastructure.Repo]
end
```

The `ecto_repos` option enables the Ecto query breakdown panel in LiveDashboard.

### 6.5 Accessing the Dashboard in Production

Navigate to `https://metricflow.app/admin/dashboard` (or the production domain). The `admins_only`
pipeline handles authentication.

For an alternative approach when SSH access is needed without a browser, use `fly ssh console`:

```bash
fly ssh console --app metric-flow
# Then in the iex console:
:observer_cli.start()
```

`observer_cli` provides a terminal-based view of process lists and memory similar to LiveDashboard,
without needing the web route.

---

## 7. Coexistence: Telemetry, PromEx, and LiveDashboard

The existing `MetricFlowWeb.Telemetry` module and `MetricFlowWeb.PromEx` both attach to the same
underlying telemetry events without conflict. Here is what each layer owns:

| Layer | Role | Consumers |
|-------|------|-----------|
| `MetricFlowWeb.Telemetry` | Defines `Telemetry.Metrics` metric structs; runs `telemetry_poller` for periodic VM measurements | LiveDashboard reads these metric definitions via `metrics: MetricFlowWeb.Telemetry` |
| `MetricFlowWeb.PromEx` | Attaches its own telemetry handlers; runs its own pollers; aggregates into Prometheus counters and histograms | Prometheus scraper via `/metrics` endpoint; Fly Grafana |
| `MetricFlowWeb.PromEx.Plugins.DataSync` | Attaches handlers for custom `[:metric_flow, ...]` events | Prometheus scraper; Fly Grafana (custom panels) |

Each layer is a separate telemetry consumer. Telemetry's pub/sub model allows any number of
handlers to attach to the same event name simultaneously — there is no conflict.

---

## 8. Environment Variable Summary

| Variable | Where Set | Required | Description |
|----------|-----------|----------|-------------|
| `SENTRY_DSN` | `fly secrets set` | Yes (prod) | Sentry project DSN from sentry.io project settings |
| `DASHBOARD_USERNAME` | `fly secrets set` | If using BasicAuth | Username for dashboard basic auth |
| `DASHBOARD_PASSWORD` | `fly secrets set` | If using BasicAuth | Password for dashboard basic auth |

PromEx requires no environment variables. It reads from OTP app config set in `config.exs`.

---

## 9. Implementation Checklist

In the order they should be completed:

- [ ] Add `{:sentry, "~> 11.0"}` and `{:prom_ex, "~> 1.11"}` to `mix.exs`, run `mix deps.get`
- [ ] Create Sentry project at sentry.io, set `SENTRY_DSN` via `fly secrets set`
- [ ] Add Sentry config to `config/runtime.exs` (prod block)
- [ ] Add `Sentry.PlugContext` and `Sentry.PlugCapture` to `lib/metric_flow_web/endpoint.ex`
- [ ] Add `Sentry.LoggerHandler` to logger config in `config/runtime.exs`
- [ ] Create `lib/metric_flow_web/prom_ex.ex` with all six plugins
- [ ] Add `MetricFlowWeb.PromEx` to the supervision tree in `lib/metric_flow/application.ex`
- [ ] Add `/metrics` route to `lib/metric_flow_web/router.ex`
- [ ] Add `[metrics]` section to `fly.toml`
- [ ] Create `lib/metric_flow_web/prom_ex/plugins/data_sync.ex` custom plugin
- [ ] Add custom plugin to `MetricFlowWeb.PromEx.plugins/0`
- [ ] Add telemetry emit calls to `SyncWorker` and `Integrations.handle_callback/4`
- [ ] Deploy and verify `/metrics` endpoint returns Prometheus text
- [ ] Import PromEx Grafana dashboard JSON files into fly-metrics.net
- [ ] Create `lib/metric_flow_web/plugs/require_admin.ex`
- [ ] Add `/admin/dashboard` route to the router with admin pipeline
- [ ] Verify dashboard is reachable in production and blocked for non-admins
- [ ] (When ready) Bump Oban to `~> 2.17` to enable cron check-in monitoring

---

## 10. Upgrade Path

If monitoring complexity grows — particularly if correlated traces linking an HTTP request through
to its Oban job and Ecto queries in a single timeline become necessary — **AppSignal is the
recommended next step**. Its Elixir-first SDK provides distributed tracing across Phoenix and
Oban automatically and is significantly more idiomatic than an OpenTelemetry setup. See the
decision record for the full AppSignal evaluation.

If Sentry errors exceed the free plan (5,000 errors/month), upgrade to the Sentry Team plan
($29/month) before switching tools. The same DSN and SDK configuration work across plans.
