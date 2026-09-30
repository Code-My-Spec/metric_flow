# QA Story 19 Brief: Render Saved Visualizations in Dashboards and Reports

## Tool

web

## Auth

Log in via the browser MCP tools against this working copy's own server (NOT port 4070 from plan.md — this worktree serves on its own port):

```
browser_navigate({ url = "http://127.0.0.1:59302/users/log-in" })
browser_scroll_into_view({ selector = "#login_form_password" })
browser_fill({ selector = "#login_form_password_email", text = "qa@example.com" })
browser_fill({ selector = "#user_password", text = "hello world!" })
browser_click({ selector = "#login_form_password button[name='user[remember_me]']" })
browser_wait_for_url({ pattern = "/", timeout = 5000 })
```

If the Editor/Index LiveViews show a paywall modal (`@paywall` assign), an active subscription is required — check `.code_my_spec/qa/plan.md` / prior story findings (story 24/45) for how an active subscription was set on this account for this worktree, or set one directly via SQL against this worktree's own dev DB (verify the actual DB name first — worktrees have used per-checkout DB names in past sessions, e.g. `metric_flow_dev_wc_<hash>`, not the default `metric_flow_dev`).

## Seeds

```
mix run --no-start -e "Application.ensure_all_started(:postgrex); Application.ensure_all_started(:ecto); MetricFlow.Repo.start_link([])" priv/repo/qa_seeds.exs
```

Verify qa@example.com has at least one connected integration / metric data (needed for the metric selector and chart preview). If `available_metrics` is empty, check `/app/integrations` for a connected platform.

## What To Test

- **Chart type selection (criteria 136/783):** `/app/visualizations/new` — confirm all 6 chart-type buttons are present (Line, Bar, Area, Scatter, Donut, Gantt), select a metric, click each chart type button, confirm the preview updates and the button highlights active.
- **Switching preserves selections (137/784):** with a metric selected and chart preview showing, switch chart type — confirm the bound metric list and name field are unchanged, only the mark/encoding changes.
- **Vega-Lite rendering (138/143/785/786):** confirm `[data-role='vega-lite-chart']` renders for each chart type (common: line/bar/area/scatter; less common: donut/gantt) — check the `data-spec` attribute is valid Vega-Lite JSON with a `mark` key (or `layer`).
- **Interactivity (139/787):** hover over the rendered chart and confirm tooltip appears (VegaLite hook default tooltip); click `[data-role='chart-drilldown']` to toggle the data table and confirm rows appear.
- **Multiple charts / multiple metrics comparison (140/149/788/798):** select two metrics in the editor — confirm the spec becomes a `layer` array with one layer per metric and a `color` encoding keyed to a `datum` per metric name (separate series).
- **Saving persists chart settings (141/789):** set a name, select metric(s) and chart type, click Save — reload `/app/visualizations` and confirm the saved visualization has the same name/chart type when reopened via Edit.
- **Saved viz renders inline in a report (142/790):** open a saved visualization at `/app/reports/:id` — confirm `[data-role='vega-lite-chart']` renders with real injected data (not a template).
- **Missing/malformed spec error state (144/791):** create a visualization with an invalid/empty `vega_spec` directly via SQL (or reuse a fresh synthetic one — note which id/fixture is used so a retest doesn't reuse a spent one), visit its `/app/reports/:id`, confirm `[data-role='report-spec-error']` shows instead of a blank panel.
- **Deleted/missing metric error state (147/792):** create a visualization bound to a metric name with no data (e.g. `discontinued_metric_<timestamp>`), visit `/app/reports/:id`, confirm `[data-role='metric-unavailable-error']` shows.
- **Resize/expand (145/793/794):** on `/app/reports/:id` with a valid chart, click `[data-role='report-chart-expand']` and confirm the chart height changes (320px → 600px); confirm `[data-role='report-chart-resize-handle']` is present for manual resize.
- **Library name + timestamp (146/795):** visit `/app/visualizations` and confirm each `[data-role='visualization-card']` shows the saved name and a `[data-role='visualization-updated-at']` "Updated <date>" timestamp.
- **Metrics bound via join table, not embedded (147/148/796):** after saving a visualization, inspect the saved `vega_spec` (via the Edit page's spec editor, or DB) and confirm it has `"data": {"name": "<metric>"}` (named reference) with NO `values` array embedded — and confirm a `visualization_metrics` row exists linking the visualization to the metric.
- **Same template renders different data per binding (148/797):** duplicate a visualization bound to metric A, edit the duplicate to bind metric B instead, confirm both render different data with the same mark/encoding template shape.

## Result Path

Findings are filed via `create_issue` as discovered; final result via `submit_qa_result`. No result.md file.

## Setup Notes

This working copy serves on `http://127.0.0.1:59302`, not the plan's default port 4070 — use the URL given in the task prompt. The Editor and Index LiveViews for visualizations (`lib/metric_flow_web/live/visualization_live/{editor,index}.ex`) render a paywall modal when `@paywall` is set (see story 45's AI-feature paywall) — confirm qa@example.com's account has an active subscription or is agency-linked before testing, otherwise scenarios will be blocked by the paywall rather than the feature itself.

Reports (`/app/reports/:id`, `ReportLive.Show`) are the read-only inline-render surface for saved visualizations — error states, resize/expand, and real-data-injection criteria are tested there. The editor (`/app/visualizations/new|:id/edit`) is where chart type selection, multi-metric layering, and saving live. The library list (`/app/visualizations`) is separate from `/app/reports` and is where the name+timestamp criterion is tested.

## Results (this pass)

This account's real seeded `clicks`/etc. data (2024–2026) falls entirely outside the current 30-day wall-clock window the Editor/Report views use by default, and the dashboard's own "All Time" filter did not widen it either when tried live — so real-data testing used two fresh synthetic metrics (`qa_viz_test_a`, `qa_viz_test_b`, 14 days of recent data each, inserted directly against `metric_flow_dev_wc_bd0baac8`) instead. Saved visualization id 22 ("QA Story19 MultiMetric Viz") is the primary fixture used throughout; ids 23/24 are malformed-spec/deleted-metric fixtures.

All chart-type (136/783), switch-preserves-selection (137/784), Vega-Lite rendering incl. donut/gantt (138/143/785/786), multi-metric layering with real distinct data per series (140/149/788/798), save-persists (141/789, confirmed via DB: `vega_spec` has no embedded `values`, `visualization_metrics` join rows correct), inline render in reports (142/790), missing/malformed-spec error state (144/791), deleted-metric error state (147/792), and library name+timestamp (146/795) all verified live and pass.

One real bug: the report's click-to-Expand button (145/793/794) toggles its own label and the server-side `@expanded` assign correctly, but the chart div's `style` (height) never visually changes because the div has `phx-update="ignore"`, which freezes it after first render — filed as issue `05b7e4b0`. The separate manual drag-resize handle is present and unaffected.

## Retest (issue 05b7e4b0)

The fix added a client-side `JS.toggle_class("report-chart-expanded", to: "#report-chart")` and a matching `#report-chart.report-chart-expanded { height: 600px; }` CSS rule. Both are correctly wired -- confirmed the class toggles onto `#report-chart` and the button label flips to "Collapse" on click, and the compiled `priv/static/assets/css/app.css` served by this dev server contains the rule (curl-confirmed).

However the chart's real box height still never changes (`getBoundingClientRect().height` stays 320 before and after the click). Root cause: the div still carries a server-rendered inline `style="width: 100%; height: #{if @expanded, do: \"600px\", else: \"320px\"}\"` attribute, and because the div has `phx-update="ignore"`, that inline style is frozen at its first-render value (320px) and never patched again -- a CSS class selector can never override an element's own inline style regardless of source order, only `!important` can, which this rule doesn't use. Confirmed live: `style` attribute still reads `height: 320px` verbatim after clicking Expand. This is exactly why the separate drag-resize handle (ResizablePanel) *does* work -- it sets `style.height` directly via JS, overwriting the frozen inline value instead of trying to out-rank it with a class. Filed as new issue `3dbb26ab` (medium) with the fix options (drop the inline style entirely, or set it directly via JS alongside the class toggle).
