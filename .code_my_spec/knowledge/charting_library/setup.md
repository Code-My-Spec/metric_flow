# Charting Library Setup: Vega-Embed + VegaLite

This document covers everything needed to get Vega-Lite charts working in MetricFlow. The stack
is `vega-embed` in the browser, the `vega_lite` Elixir hex package server-side, a colocated
`VegaChart` LiveView hook, esbuild code splitting for lazy loading, and PubSub `push_event` for
real-time updates.

Decision record: `docs/architecture/decisions/charting_library.md`

---

## 1. Package Installation

### npm packages (browser-side)

MetricFlow has no `package.json` — dependencies are installed directly into `assets/` using
npm's `--prefix` flag.

```
npm install --prefix assets vega vega-lite vega-embed
```

This creates `assets/package.json` and `assets/node_modules/`. The three packages and their
approximate gzip sizes at the time of the decision:

| Package | Version | Approx. gzip |
|---|---|---|
| `vega` | 6.x | ~300 KB |
| `vega-lite` | 6.x | ~125 KB |
| `vega-embed` | 7.x | ~20 KB |

Total for the full stack: approximately 450 KB gzip, loaded only on authenticated dashboard
pages (see section 4 for lazy loading).

After running npm install, the esbuild `NODE_PATH` in `config/config.exs` already resolves
`node_modules` under `assets/` because it points at `../deps` and the build path. To also
resolve `assets/node_modules`, add it to `NODE_PATH`:

```elixir
# config/config.exs — update the esbuild config
config :esbuild,
  version: "0.25.4",
  metric_flow: [
    args: ~w(
      js/app.js
      --bundle
      --splitting
      --format=esm
      --chunk-names=chunks/[name]-[hash]
      --target=es2022
      --outdir=../priv/static/assets/js
      --external:/fonts/*
      --external:/images/*
      --alias:@=.
    ),
    cd: Path.expand("../assets", __DIR__),
    env: %{
      "NODE_PATH" =>
        Enum.join(
          [
            Path.expand("../assets/node_modules", __DIR__),
            Path.expand("../deps", __DIR__),
            Mix.Project.build_path()
          ],
          ":"
        )
    }
  ]
```

The two key changes from the default config are:

- `--splitting` and `--format=esm` enable dynamic `import()` so the Vega stack is code-split
  into a separate chunk fetched on demand (see section 4).
- `--chunk-names=chunks/[name]-[hash]` puts generated chunks in a `chunks/` subdirectory with
  content-hash names for cache busting.
- `assets/node_modules` prepended to `NODE_PATH` so esbuild finds the npm packages.

### Elixir hex package (server-side)

Add to `mix.exs` deps:

```elixir
{:vega_lite, "~> 0.1.11"}
```

Then run `mix deps.get`. The `vega_lite` package (maintained by the Livebook team) produces
valid Vega-Lite 6.x JSON maps. No runtime configuration is needed.

---

## 2. The VegaChart Colocated Hook

MetricFlow uses `phoenix-colocated` — hooks live alongside their LiveView modules in `lib/`.
The colocated hooks are auto-discovered and merged into the `colocatedHooks` map in `app.js`.
No manual registration is needed.

Create the hook file alongside the dashboard LiveView:

```
lib/metric_flow_web/live/dashboard_live/show.hooks.js
```

### Full hook implementation

```javascript
// lib/metric_flow_web/live/dashboard_live/show.hooks.js

const VegaChart = {
  async mounted() {
    // Lazy-load the full Vega stack only when a chart component actually mounts.
    // This keeps the main app.js bundle free of the ~450 KB Vega runtime,
    // deferring that cost until an authenticated user lands on a dashboard page.
    const { default: vegaEmbed } = await import("vega-embed")

    const spec = JSON.parse(this.el.dataset.spec)
    const result = await vegaEmbed(this.el, spec, {
      actions: false,      // hide the default "..." export menu
      renderer: "svg",     // SVG for print/export compatibility; use "canvas" if
                           // rendering thousands of marks is slow
    })
    this.view = result.view

    // Listen for server-pushed spec updates.
    // The event name is scoped to this element's DOM id so multiple charts on
    // the same page each receive only their own updates.
    this.handleEvent(`chart:update:${this.el.id}`, async ({ spec: updatedSpec }) => {
      if (this.view) {
        this.view.finalize()
        this.view = null
      }
      const r = await vegaEmbed(this.el, updatedSpec, {
        actions: false,
        renderer: "svg",
      })
      this.view = r.view
    })
  },

  destroyed() {
    // Release Vega's internal timers, WebGL contexts, and event listeners
    // to prevent memory leaks when the LiveView navigates away.
    if (this.view) {
      this.view.finalize()
      this.view = null
    }
  },
}

export default VegaChart
```

The `async mounted()` signature is valid — LiveView does not inspect the return value of
hook lifecycle callbacks.

### Hook registration check

The `app.js` already spreads `colocatedHooks` into the LiveSocket:

```javascript
// assets/js/app.js (existing, no change needed)
import {hooks as colocatedHooks} from "phoenix-colocated/metric_flow"

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks},
})
```

`phoenix-colocated` discovers all `*.hooks.js` files under `lib/metric_flow_web/` and
exports them keyed by the module path. The `VegaChart` export from
`show.hooks.js` is registered as `"VegaChart"` automatically.

---

## 3. HEEx Template Pattern: phx-update="ignore"

LiveView re-renders the DOM on each `assign` change. The Vega runtime manages its own SVG or
canvas element inside the hook container. If LiveView patches that container during a re-render,
it destroys the rendered chart.

The solution is a two-element wrapper pattern:

- The **outer** wrapper carries `phx-hook` and receives LiveView lifecycle events. LiveView
  is allowed to update it.
- The **inner** div carries `phx-update="ignore"` and `data-spec`. LiveView leaves its children
  alone after the first render. The hook writes the chart into this element.

```heex
<%!-- In DashboardLive.Show render/1 --%>
<%= for viz <- @visualizations do %>
  <%!-- Outer wrapper: LiveView may update this element.
       phx-hook must be on the outermost element that LiveView controls. --%>
  <div
    id={"chart-wrapper-#{viz.id}"}
    phx-hook="VegaChart"
    class="relative min-h-[200px]"
  >
    <%!-- Loading skeleton shown while Vega initialises (CSS-only, removed when
         the hook's vegaEmbed promise resolves and vega writes its SVG/canvas). --%>
    <div class="absolute inset-0 animate-pulse bg-base-200 rounded-lg" aria-hidden="true" />

    <%!-- Inner container: phx-update="ignore" tells LiveView never to patch the
         children of this element after the initial render.
         The hook mounts, reads data-spec, and calls vegaEmbed(this.el, spec).
         Vega replaces the empty div's children with the rendered SVG. --%>
    <div
      id={"chart-#{viz.id}"}
      phx-update="ignore"
      data-spec={Jason.encode!(viz.vega_spec)}
      class="w-full"
    >
    </div>
  </div>
<% end %>
```

Key constraints:

- Every element with `phx-hook` must have a unique `id`. Use `viz.id` from the database.
- The inner `phx-update="ignore"` element must also have a unique `id` (different from the
  outer wrapper's id) — LiveView requires ids on `phx-update` elements.
- Do not put `phx-hook` and `phx-update="ignore"` on the same element. The hook goes on
  the wrapper; ignore goes on the inner chart container.
- `data-spec` is read once in `mounted()`. If you want to update the chart data later,
  use `push_event` from the server (section 5) rather than changing `data-spec` — the
  ignore prevents LiveView from updating the inner element anyway.

---

## 4. Esbuild Code Splitting and Lazy Loading

Vega-embed plus its peer dependencies are approximately 450 KB gzip. Unauthenticated pages
(registration, login, landing) must not pay this cost.

The `async import("vega-embed")` in the hook is sufficient to split the Vega code into a
separate chunk, but esbuild must be configured to enable code splitting:

```elixir
# config/config.exs — the complete esbuild stanza (combines sections 1 and 4)
config :esbuild,
  version: "0.25.4",
  metric_flow: [
    args: ~w(
      js/app.js
      --bundle
      --splitting
      --format=esm
      --chunk-names=chunks/[name]-[hash]
      --target=es2022
      --outdir=../priv/static/assets/js
      --external:/fonts/*
      --external:/images/*
      --alias:@=.
    ),
    cd: Path.expand("../assets", __DIR__),
    env: %{
      "NODE_PATH" =>
        Enum.join(
          [
            Path.expand("../assets/node_modules", __DIR__),
            Path.expand("../deps", __DIR__),
            Mix.Project.build_path()
          ],
          ":"
        )
    }
  ]
```

With `--splitting --format=esm`, esbuild emits ES modules instead of a single IIFE bundle.
The output changes from a single `app.js` to:

```
priv/static/assets/js/app.js           <- main entry (small, no Vega)
priv/static/assets/js/chunks/          <- auto-split chunks
priv/static/assets/js/chunks/vega-embed-[hash].js
priv/static/assets/js/chunks/vega-[hash].js
priv/static/assets/js/chunks/vega-lite-[hash].js
```

The browser only fetches the chunk files when `import("vega-embed")` executes inside the
hook's `mounted()`. On pages with no `phx-hook="VegaChart"` elements, the Vega chunks are
never requested.

### root.html.heex script tag change

Switching from IIFE to ESM output requires updating the script tag in the root layout to
use `type="module"`:

```heex
<%!-- lib/metric_flow_web/components/layouts/root.html.heex --%>
<script type="module" defer phx-track-static src={~p"/assets/js/app.js"}></script>
```

The `type="module"` attribute tells the browser to treat `app.js` as an ES module, which
is required for the dynamic `import()` calls in the chunks to work correctly.

### Development vs. production

The `mix assets.build` alias calls `esbuild metric_flow` without `--minify`, so chunk files
appear in development without compression. The `mix assets.deploy` alias adds `--minify`.

Phoenix's `phx.digest` (called in `assets.deploy`) fingerprints the chunk files along with
`app.js`, so `phx-track-static` on the script tag still works correctly.

---

## 5. Server-Side Spec Building with vega_lite

The `vega_lite` package provides an Elixir DSL for composing Vega-Lite 6.x specs. Use it
for canned dashboard specs where the structure is known at compile time.

### Basic line chart

```elixir
defmodule MetricFlow.Dashboards.CannedSpecs do
  @moduledoc """
  Vega-Lite spec builders for canned MetricFlow dashboards.
  Each function accepts a list of data rows and returns a plain Elixir map
  (the Vega-Lite JSON spec) suitable for storing in Visualization.vega_spec.
  """

  alias VegaLite, as: Vl

  @doc """
  Line chart of sessions over time from Google Analytics.

  `rows` is a list of maps with at least `%{date: "YYYY-MM-DD", sessions: integer()}`.
  """
  def sessions_over_time(rows) do
    Vl.new(width: :container, height: 200, title: "Sessions Over Time")
    |> Vl.data_from_values(rows, only: ["date", "sessions"])
    |> Vl.mark(:line, point: true, tooltip: true)
    |> Vl.encode_field(:x, "date", type: :temporal, title: "Date")
    |> Vl.encode_field(:y, "sessions", type: :quantitative, title: "Sessions")
    |> Vl.to_spec()
  end

  @doc """
  Bar chart of ad spend by platform.

  `rows` is a list of maps like `%{platform: "Google Ads", spend: 1200.0}`.
  """
  def ad_spend_by_platform(rows) do
    Vl.new(width: :container, height: 200, title: "Ad Spend by Platform")
    |> Vl.data_from_values(rows, only: ["platform", "spend"])
    |> Vl.mark(:bar, tooltip: true)
    |> Vl.encode_field(:x, "platform", type: :nominal, title: "Platform")
    |> Vl.encode_field(:y, "spend", type: :quantitative, title: "Spend ($)")
    |> Vl.to_spec()
  end

  @doc """
  Multi-series line chart for comparing two metrics on the same time axis.

  `rows` is a list of maps with `%{date: "YYYY-MM-DD", metric: "name", value: float()}`.
  Uses Vega-Lite's color encoding to produce one line per metric name.
  """
  def multi_metric_trend(rows) do
    Vl.new(width: :container, height: 250)
    |> Vl.data_from_values(rows, only: ["date", "metric", "value"])
    |> Vl.mark(:line, point: true, tooltip: true)
    |> Vl.encode_field(:x, "date", type: :temporal, title: "Date")
    |> Vl.encode_field(:y, "value", type: :quantitative, title: "Value")
    |> Vl.encode_field(:color, "metric", type: :nominal, title: "Metric")
    |> Vl.to_spec()
  end

  @doc """
  Scatter plot for correlation analysis view.

  `rows` is a list of maps with `%{x_value: float(), y_value: float(), date: "YYYY-MM-DD"}`.
  """
  def correlation_scatter(rows, x_label, y_label) do
    Vl.new(width: :container, height: 300)
    |> Vl.data_from_values(rows, only: ["x_value", "y_value", "date"])
    |> Vl.mark(:point, tooltip: true)
    |> Vl.encode_field(:x, "x_value", type: :quantitative, title: x_label)
    |> Vl.encode_field(:y, "y_value", type: :quantitative, title: y_label)
    |> Vl.encode_field(:tooltip, "date", type: :temporal, title: "Date")
    |> Vl.to_spec()
  end
end
```

### Testing specs without a browser

Because `VegaLite.to_spec/1` returns a plain Elixir map, spec construction is testable in
unit tests with no browser or JavaScript involved:

```elixir
defmodule MetricFlow.Dashboards.CannedSpecsTest do
  use ExUnit.Case, async: true

  alias MetricFlow.Dashboards.CannedSpecs

  describe "sessions_over_time/1" do
    test "produces a valid Vega-Lite spec with the correct mark type" do
      rows = [
        %{date: "2026-01-01", sessions: 1200},
        %{date: "2026-01-02", sessions: 1350}
      ]

      spec = CannedSpecs.sessions_over_time(rows)

      assert spec["$schema"] =~ "vega-lite"
      assert spec["mark"]["type"] == "line"
      assert spec["encoding"]["x"]["field"] == "date"
      assert spec["encoding"]["y"]["field"] == "sessions"
    end

    test "embeds data rows inline" do
      rows = [%{date: "2026-01-01", sessions: 100}]
      spec = CannedSpecs.sessions_over_time(rows)
      assert length(spec["data"]["values"]) == 1
    end
  end
end
```

### Seeding canned specs into the database

The decision record recommends storing canned specs as `built_in: true` Visualization records
seeded at deploy time rather than hardcoding them in templates. A `priv/repo/seeds.exs` pattern:

```elixir
# priv/repo/seeds.exs
import Ecto.Query
alias MetricFlow.Infrastructure.Repo
alias MetricFlow.Dashboards.Visualization
alias MetricFlow.Dashboards.CannedSpecs

# Seed an empty spec — the spec will be populated at runtime with real data
# by the dashboard LiveView when it builds the assign. Store as a schema
# reference only; the actual data rows come from Metrics queries at runtime.
placeholder_rows = []

canned = [
  %{
    name: "Sessions Over Time",
    description: "Daily Google Analytics sessions",
    vega_spec: CannedSpecs.sessions_over_time(placeholder_rows),
    built_in: true
  },
  %{
    name: "Ad Spend by Platform",
    description: "Marketing spend breakdown",
    vega_spec: CannedSpecs.ad_spend_by_platform(placeholder_rows),
    built_in: true
  }
]

Enum.each(canned, fn attrs ->
  Repo.insert!(
    struct(Visualization, attrs),
    on_conflict: {:replace, [:vega_spec, :description]},
    conflict_target: :name
  )
end)
```

---

## 6. Real-Time Updates via PubSub and push_event

When a background `SyncWorker` completes, dashboard LiveViews should update their charts
without a full page reload. The pattern:

1. Subscribe the LiveView to a PubSub topic when mounting.
2. In `handle_info/2`, rebuild specs from fresh Metrics data.
3. Call `push_event/3` to deliver the updated spec to the hook.
4. The hook's `handleEvent` listener calls `vegaEmbed` with the new spec.

### PubSub topic convention

Use a per-account topic scoped to the sync domain:

```
"sync:#{account_id}"
```

The `DataSync.SyncWorker` broadcasts on this topic when a sync job completes:

```elixir
# lib/metric_flow/data_sync/sync_worker.ex
defmodule MetricFlow.DataSync.SyncWorker do
  use Oban.Worker, queue: :sync, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"account_id" => account_id} = args}) do
    # ... sync logic ...
    Phoenix.PubSub.broadcast(
      MetricFlow.PubSub,
      "sync:#{account_id}",
      {:sync_complete, account_id}
    )
    :ok
  end
end
```

### Dashboard LiveView subscription and push_event

```elixir
defmodule MetricFlowWeb.DashboardLive.Show do
  use MetricFlowWeb, :live_view

  alias MetricFlow.Dashboards
  alias MetricFlow.Metrics

  @impl true
  def mount(%{"id" => dashboard_id}, _session, socket) do
    scope = socket.assigns.current_scope

    if connected?(socket) do
      # Subscribe only on connected (not on static/dead render)
      account_id = scope.user.account_id
      Phoenix.PubSub.subscribe(MetricFlow.PubSub, "sync:#{account_id}")
    end

    dashboard = Dashboards.get_dashboard!(scope, dashboard_id)
    visualizations = Dashboards.list_visualizations_for_dashboard(scope, dashboard)

    socket =
      socket
      |> assign(:dashboard, dashboard)
      |> assign(:visualizations, visualizations)

    {:ok, socket}
  end

  @impl true
  def handle_info({:sync_complete, _account_id}, socket) do
    scope = socket.assigns.current_scope
    dashboard = socket.assigns.dashboard

    # Refetch visualizations with fresh metric data
    updated_vizs =
      Dashboards.list_visualizations_for_dashboard(scope, dashboard)

    # Push updated specs to each active VegaChart hook.
    # The event name matches the hook's handleEvent listener:
    #   this.handleEvent(`chart:update:${this.el.id}`, ...)
    # where this.el.id is "chart-#{viz.id}" (the inner container's DOM id).
    Enum.each(updated_vizs, fn viz ->
      push_event(socket, "chart:update:chart-#{viz.id}", %{spec: viz.vega_spec})
    end)

    {:noreply, assign(socket, :visualizations, updated_vizs)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>{@dashboard.name}</.header>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mt-6">
        <%= for viz <- @visualizations do %>
          <div
            id={"chart-wrapper-#{viz.id}"}
            phx-hook="VegaChart"
            class="relative min-h-[220px] rounded-lg border border-base-300 p-4"
          >
            <div class="absolute inset-0 animate-pulse bg-base-200 rounded-lg" aria-hidden="true" />
            <div
              id={"chart-#{viz.id}"}
              phx-update="ignore"
              data-spec={Jason.encode!(viz.vega_spec)}
              class="w-full"
            >
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
```

### Event name anatomy

```
chart:update:chart-42
^^^^^  ^^^^^^  ^^^^^^^
|      |       DOM id of the inner phx-update="ignore" div
|      event type
namespace
```

The event must match exactly between `push_event/3` and `handleEvent(...)`. Since `this.el`
in the hook is the outer wrapper (`chart-wrapper-42`), and the inner container is
`chart-42`, the push_event call uses `"chart-#{viz.id}"` (no `wrapper-` prefix).

---

## 7. LLM-Generated and User-Authored Specs

Specs stored in `Visualization.vega_spec` from sources other than `CannedSpecs` (LLM
output, user hand-authored JSON) are passed through to `vegaEmbed` without transformation.
No translation layer is needed. The hook simply calls:

```javascript
vegaEmbed(this.el, spec, { actions: false, renderer: "svg" })
```

where `spec` is parsed directly from `data-spec`.

### Validating LLM-generated specs server-side

The LLM prompt for `ReportGenerator` should include the schema URL:

```
"$schema": "https://vega.github.io/schema/vega-lite/v6.json"
```

A minimal server-side validation before persisting an LLM-generated spec:

```elixir
defmodule MetricFlow.Dashboards.Visualization do
  use Ecto.Schema
  import Ecto.Changeset

  schema "visualizations" do
    field :name, :string
    field :description, :string
    field :vega_spec, :map
    field :built_in, :boolean, default: false
    belongs_to :owner, MetricFlow.Users.User
    timestamps()
  end

  def changeset(visualization, attrs) do
    visualization
    |> cast(attrs, [:name, :description, :vega_spec, :built_in])
    |> validate_required([:name, :vega_spec])
    |> validate_vega_spec()
  end

  defp validate_vega_spec(changeset) do
    validate_change(changeset, :vega_spec, fn :vega_spec, spec ->
      cond do
        not is_map(spec) ->
          [vega_spec: "must be a JSON object"]

        not Map.has_key?(spec, "$schema") ->
          [vega_spec: "must include a $schema field"]

        not (Map.has_key?(spec, "mark") or Map.has_key?(spec, "layer") or
               Map.has_key?(spec, "concat") or Map.has_key?(spec, "facet") or
               Map.has_key?(spec, "spec")) ->
          [vega_spec: "must include a mark, layer, concat, facet, or spec field"]

        true ->
          []
      end
    end)
  end
end
```

### Prototyping specs during development

Use the Vega-Lite online editor to prototype and validate specs before committing:
https://vega.github.io/editor/

Set `"$schema": "https://vega.github.io/schema/vega-lite/v6.json"` to get editor validation
against the v6 schema. This is the version installed by `npm install vega-lite` (6.x).

---

## 8. Putting It All Together: Checklist

Use this checklist when implementing the dashboard feature:

- [ ] Run `npm install --prefix assets vega vega-lite vega-embed`
- [ ] Update `config/config.exs` esbuild config: add `--splitting --format=esm
      --chunk-names=chunks/[name]-[hash]`, update `NODE_PATH` to include
      `assets/node_modules`
- [ ] Update `root.html.heex` script tag to `type="module"` for ESM output
- [ ] Add `{:vega_lite, "~> 0.1.11"}` to `mix.exs` and run `mix deps.get`
- [ ] Create `lib/metric_flow_web/live/dashboard_live/show.hooks.js` with the
      `VegaChart` hook (async `mounted`, `destroyed`, `handleEvent`)
- [ ] Use the two-element wrapper/inner pattern in templates:
      - outer `div` with `phx-hook="VegaChart"` and `id="chart-wrapper-{viz.id}"`
      - inner `div` with `phx-update="ignore"`, `id="chart-{viz.id}"`, and
        `data-spec={Jason.encode!(viz.vega_spec)}`
- [ ] Add loading skeleton inside the wrapper (Tailwind `animate-pulse`) displayed
      until Vega replaces the inner div's children
- [ ] Subscribe dashboard LiveViews to `"sync:#{account_id}"` in `mount/3` when
      `connected?(socket)` is true
- [ ] Implement `handle_info({:sync_complete, _}, socket)` to refetch vizs and
      call `push_event(socket, "chart:update:chart-#{viz.id}", %{spec: ...})`
- [ ] Build canned specs in `MetricFlow.Dashboards.CannedSpecs` using `VegaLite`
      DSL and test with `ExUnit` (no browser required)
- [ ] Broadcast `{:sync_complete, account_id}` from `DataSync.SyncWorker` via
      `Phoenix.PubSub.broadcast/3`

---

## References

- [Vega-Lite Embedding Guide](https://vega.github.io/vega-lite/usage/embed.html)
- [vega-embed GitHub](https://github.com/vega/vega-embed)
- [vega_lite Hex Package](https://hex.pm/packages/vega_lite)
- [VegaLite Elixir + Phoenix LiveView Example](https://github.com/jonatanklosko/vega_lite_lv_example)
- [Phoenix LiveView JS Interop](https://hexdocs.pm/phoenix_live_view/js-interop.html)
- [Phoenix.LiveView.ColocatedHook](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.ColocatedHook.html)
- [Vega-Lite Online Editor](https://vega.github.io/editor/)
- [Vega-Lite v6 JSON Schema](https://vega.github.io/schema/vega-lite/v6.json)
