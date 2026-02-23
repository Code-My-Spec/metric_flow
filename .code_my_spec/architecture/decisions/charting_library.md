# Charting Library for Dashboard Visualizations

## Status

Proposed

## Context

MetricFlow dashboards display marketing and financial metrics pulled from Google Analytics, Google Ads,
Facebook Ads, and QuickBooks. The architecture stores Vega-Lite JSON specs in the `Visualization` schema
(`vega_spec` field). Multiple features depend on rendering those specs in the browser:

- Canned dashboards with standard metric visualizations (line, bar, area, scatter)
- User-created custom visualizations with hand-authored Vega-Lite specs
- LLM-generated reports where the AI produces Vega-Lite JSON from natural language
- A correlation analysis view with potentially multi-view or layered specs
- Real-time updates when a background sync job completes and new metric data arrives

Because the system is spec-first — specs are stored in the database and the LLM generates specs
directly — the rendering layer must accept arbitrary Vega-Lite JSON without translation. Vega-Lite
is the _lingua franca_ of the data model, not an incidental implementation detail.

The project runs Phoenix LiveView 1.1, uses esbuild for JS bundling, already uses colocated hooks
via `phoenix-colocated`, and has no existing npm `package.json` (dependencies are either vendored or
installed directly against the esbuild `NODE_PATH`).

---

## Options Considered

### Option A: vega-embed (Official Vega-Lite Renderer)

`vega-embed` is the official browser-side renderer for Vega-Lite specs. It wraps the full Vega
runtime and the Vega-Lite compiler, exposing a single `vegaEmbed(element, spec, options)` function.
The three peer packages required are:

- `vega@6.x` (~900 KB minified, ~300 KB gzip)
- `vega-lite@6.x` (~400 KB minified, ~125 KB gzip)
- `vega-embed@7.x` (~60 KB minified, ~20 KB gzip)

Total gzip delivery budget is approximately 450 KB for the full Vega stack when bundled with esbuild.
This is the heaviest option considered.

**LiveView hook pattern:**

```javascript
// assets/js/hooks/vega_chart.js
import vegaEmbed from "vega-embed"

const VegaChart = {
  mounted() {
    const spec = JSON.parse(this.el.dataset.spec)
    vegaEmbed(this.el, spec, { actions: false, renderer: "svg" })
      .then(result => { this.view = result.view })
      .catch(console.error)

    // Server pushes updated spec when sync data arrives
    this.handleEvent(`chart:update:${this.el.id}`, ({ spec }) => {
      vegaEmbed(this.el, spec, { actions: false, renderer: "svg" })
        .then(result => { this.view = result.view })
        .catch(console.error)
    })
  },

  destroyed() {
    if (this.view) this.view.finalize()
  }
}

export default VegaChart
```

```heex
<%!-- phx-update="ignore" prevents LiveView from re-rendering the chart div,
     which would destroy the vega-embed canvas/SVG.
     The outer wrapper receives LiveView updates; the inner element is JS-owned. --%>
<div id={"chart-wrapper-#{@viz.id}"} phx-hook="VegaChart">
  <div
    id={"chart-#{@viz.id}"}
    phx-update="ignore"
    data-spec={Jason.encode!(@viz.vega_spec)}
  ></div>
</div>
```

Server-side spec push on real-time data arrival:

```elixir
# In the LiveView handle_info/2 for PubSub sync completion
def handle_info({:sync_complete, account_id}, socket) do
  updated_vizs = Dashboards.list_visualizations(socket.assigns.current_scope)
  Enum.each(updated_vizs, fn viz ->
    push_event(socket, "chart:update:chart-#{viz.id}", %{spec: viz.vega_spec})
  end)
  {:noreply, assign(socket, :visualizations, updated_vizs)}
end
```

**Elixir-side spec building with `vega_lite` hex package:**

For canned dashboards MetricFlow can build specs in Elixir rather than storing raw JSON:

```elixir
defp sessions_over_time_spec(rows) do
  VegaLite.new(width: :container, height: 200)
  |> VegaLite.data_from_values(rows)
  |> VegaLite.mark(:line, point: true, tooltip: true)
  |> VegaLite.encode_field(:x, "date", type: :temporal, title: "Date")
  |> VegaLite.encode_field(:y, "sessions", type: :quantitative, title: "Sessions")
  |> VegaLite.to_spec()
end
```

The `vega_lite` package (v0.1.11, released November 2024, 1M+ total downloads) is maintained by
the Livebook team and produces valid Vega-Lite JSON maps. It is already proven in the Livebook
ecosystem and is straightforward to add as a dependency.

**Bundle size mitigation — dynamic import:**

Because chart-heavy pages are behind authentication, the Vega stack can be loaded lazily. Esbuild
supports dynamic imports with code splitting enabled:

```javascript
// assets/js/hooks/vega_chart.js — lazy-loaded variant
const VegaChart = {
  async mounted() {
    const { default: vegaEmbed } = await import("vega-embed")
    // ... rest of mount logic
  }
}
```

Config change needed in `config/config.exs`:

```elixir
config :esbuild,
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
    ...
  ]
```

This means unauthenticated pages (registration, login) pay zero Vega bundle cost.

**Pros:**
- No translation layer — LLM output and stored specs render directly
- Handles every Vega-Lite feature: tooltips, brushing, linked views, streaming data, facets
- `vega_lite` Elixir package builds canned specs idiomatically server-side
- Interactive features (hover tooltips, zoom/pan via selections) work without additional JS
- SVG renderer produces print/export-friendly output
- Well-documented hook pattern with clear community precedent in the Elixir ecosystem
- Active maintenance: Vega-Lite 6.x released 2024, `vega_lite` hex 0.1.11 released November 2024

**Cons:**
- Largest bundle: ~450 KB gzip total for all three packages
- Full bundle paid on first dashboard page load (mitigated by lazy loading behind auth)
- `vegaEmbed` re-renders the entire chart on spec update rather than patching data (acceptable
  for dashboard use cases; streaming partial data updates are possible via the Vega View API
  but add complexity)
- No SSR — chart is blank until JS executes (acceptable; show loading skeleton)

---

### Option B: Chart.js

Chart.js is an imperative canvas-based charting library. It does not consume Vega-Lite specs;
it requires data and configuration to be provided in its own format.

Approximate bundle size: ~200 KB minified, ~60 KB gzip (Chart.js 4.x full build).

**Pros:**
- Smaller bundle than Vega
- Simpler for basic chart types (line, bar, pie)
- Familiar to many frontend developers

**Cons:**
- Requires a translation layer: Vega-Lite specs must be converted to Chart.js config on every
  render. This breaks the core architecture where the LLM generates Vega-Lite JSON. The
  translation would need to handle marks, encodings, transforms, multi-view compositions, and
  interactive selections — a substantial and ongoing maintenance burden.
- Does not support Vega-Lite features required by the spec: layered views, linked selections,
  correlation matrices, geographic projections, faceted grids
- Does not benefit from the `vega_lite` Elixir package
- Imperatively manages a canvas — complex LiveView hook lifecycle to avoid memory leaks
- The `chart_js` hex package (v0.1.0) is an early-stage wrapper with limited community adoption

---

### Option C: Apache ECharts

Apache ECharts is a feature-rich canvas-based chart library with its own JSON configuration format
(not Vega-Lite).

Approximate bundle size: ~1 MB minified full build; ~135 KB gzip with tree-shaking for a typical
chart subset.

**Pros:**
- Rich chart types including heatmaps and large dataset rendering
- Tree-shakeable in v5+: only include needed chart types
- SVG and Canvas rendering modes

**Cons:**
- Same core problem as Chart.js: does not consume Vega-Lite specs, requiring a full translation
  layer that would need to handle the entire Vega-Lite grammar
- Larger or comparable bundle to vega-embed even with tree-shaking for a comparable feature set
- No Elixir ecosystem integration
- Not suited to the LLM report generation workflow

---

### Option D: Observable Plot / D3

Observable Plot provides a concise API for exploratory charts. D3 provides low-level primitives.
Both support tree-shaking with esbuild.

Approximate bundle sizes: D3 full ~300 KB minified, ~90 KB gzip; Observable Plot ~60 KB gzip;
specific D3 modules much smaller.

**Pros:**
- D3 tree-shaking with esbuild can yield very small bundles for targeted chart types
- Observable Plot is concise for statistical charts
- Maximum rendering flexibility

**Cons:**
- Neither consumes Vega-Lite specs — LLM output would need either translation or a different
  output format entirely, requiring changes to the AI context and the Visualization schema
- High implementation complexity: building interactive time series charts with tooltips, zoom,
  and responsive behavior from D3 primitives requires significant custom JavaScript
- No idiomatic Elixir-side spec building library

---

## Decision

**Use `vega-embed` (Option A) as the browser-side Vega-Lite renderer, paired with the `vega_lite`
Elixir hex package for server-side spec construction.**

The architecture decision to store Vega-Lite specs in the database and generate them via LLM is
the decisive constraint. Options B, C, and D each require a translation layer from Vega-Lite to
their native format — a layer that would need to faithfully implement the Vega-Lite grammar
(marks, encodings, transforms, multi-view compositions, interactive selections). This translation
is not a one-time cost; it would need maintenance as Vega-Lite evolves and as new spec patterns
emerge from the LLM generator.

`vega-embed` accepts Vega-Lite JSON directly, eliminating the translation layer entirely. The
bundle weight (~450 KB gzip for the full stack) is a real cost, but it is manageable because:

1. Dashboard pages are behind authentication — unauthenticated critical path (registration, login)
   pays no cost.
2. Lazy loading via esbuild code splitting defers the Vega stack until a chart hook mounts.
3. The Vega stack is a one-time cost per session, cached by the browser.
4. Compared to the engineering cost of a translation layer, the extra bytes are the better tradeoff.

The `vega_lite` Elixir package (maintained by the Livebook team, v0.1.11) is used to build
Vega-Lite specs for canned dashboards server-side. This keeps spec construction in Elixir,
testable without a browser, and consistent with the JSON stored for user/LLM-generated specs.

---

## Consequences

**Accepted trade-offs:**
- The authenticated bundle will include ~450 KB gzip of Vega runtime. This is the cost of
  spec-native rendering and the LLM workflow.
- Charts render client-side only. A loading skeleton or spinner should display while the
  hook mounts.
- `vegaEmbed` re-renders the full chart on spec or data update. For dashboard use cases with
  O(hundreds) of data points this is imperceptible; if streaming thousands of points per second
  becomes a requirement, the Vega View streaming API (`view.change(...)`) can be adopted later.

**Follow-up actions:**
- Add `{:vega_lite, "~> 0.1.11"}` to `mix.exs` dependencies for server-side spec construction.
- Install `vega`, `vega-lite`, and `vega-embed` npm packages into `assets/`:
  `npm install --prefix assets vega vega-lite vega-embed`
- Implement a `VegaChart` colocated hook on the visualization component using the `mounted` /
  `destroyed` lifecycle and `handleEvent` for real-time spec updates.
- Use `phx-update="ignore"` on the chart container div to prevent LiveView from destroying
  the Vega-rendered SVG/canvas during re-renders. Place the hook on a wrapper element.
- Enable esbuild `--splitting --format=esm` to support dynamic `import()` of vega-embed,
  so the Vega stack is only fetched when a chart component actually mounts.
- Configure SVG rendering (`renderer: "svg"`) for print/export compatibility.
- Subscribe dashboard LiveViews to PubSub sync-complete events and use `push_event` to
  deliver updated specs to active chart hooks for real-time updates.
- Canned dashboard specs should be built with the `vega_lite` Elixir package and stored as
  seeded `built_in: true` records at deploy time rather than hardcoded in templates.

**Impact on development workflow:**
- Visualization specs can be developed and tested in Elixir unit tests using `VegaLite.to_spec/1`
  without running a browser.
- The LLM prompt for `ReportGenerator` should instruct the model to output Vega-Lite 6.x JSON
  conforming to the schema at `https://vega.github.io/schema/vega-lite/v6.json`.
- Developers can prototype and validate specs at `https://vega.github.io/editor/` before
  committing them to the codebase.

---

## References

- [Vega-Lite Embedding Guide](https://vega.github.io/vega-lite/usage/embed.html)
- [vega-embed GitHub](https://github.com/vega/vega-embed)
- [vega_lite Hex Package](https://hex.pm/packages/vega_lite)
- [VegaLite Elixir Demo with Phoenix LiveView](https://github.com/jonatanklosko/vega_lite_lv_example)
- [Interactive Graphing in Elixir with Vegalite and Phoenix LiveView](https://elixirmerge.com/p/interactive-graphing-in-elixir-with-vegalite-and-phoenix-liveview)
- [Phoenix LiveView JS Interop](https://hexdocs.pm/phoenix_live_view/js-interop.html)
- [Phoenix.LiveView.ColocatedHook](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.ColocatedHook.html)
- [Page-Specific JavaScript with LiveView and esbuild](https://aswinmohan.me/pagewise-js-liveview)
- [Integrating LiveView and JavaScript — WyeWorks](https://www.wyeworks.com/blog/2024/02/27/integrating-live-view-and-js/)
