# QA Story 34 Brief: Correct Aggregation of Derived and Calculated Metrics

## Tool

web

## Auth

```
browser_navigate({ url = "http://127.0.0.1:59302/users/log-in" })
browser_scroll_into_view({ selector = "#login_form_password" })
browser_fill({ selector = "#password_email", text = "qa@example.com" })
browser_fill({ selector = "#user_password", text = "hello world!" })
browser_click({ selector = "#login_form_password button[name='user[remember_me]']" })
browser_wait_for_url({ pattern = "/", timeout = 5000 })
```

## Seeds

```
mix run --no-start -e "Application.ensure_all_started(:postgrex); Application.ensure_all_started(:ecto); MetricFlow.Repo.start_link([])" priv/repo/qa_seeds.exs
```

This worktree's dev server reads database `metric_flow_dev_wc_bd0baac8`, not the default `metric_flow_dev` — any direct SQL/`mix run -e` shell must target that database explicitly (e.g. `PGPASSWORD=postgres psql -h localhost -U postgres -d metric_flow_dev_wc_bd0baac8`).

The dashboard's derived metrics (cpc, ctr, roas) are computed from raw component sums (`total_cost`/`clicks`, `clicks`/`impressions`, `revenue`/`total_cost`) over the currently selected date range and platform filter — see `lib/metric_flow_web/live/dashboard_live/show.ex` `@known_derived_metrics` and `enrich_with_known_metrics/1`. For a controlled test, insert fresh synthetic `total_cost`/`clicks`/`impressions`/`revenue` metric rows with known values and recent dates (this account's seeded data is outside the default 30-day window) directly via SQL against the `metrics` table (columns: `metric_type`, `metric_name`, `value`, `recorded_at`, `provider`, `dimensions` default `'{}'`, `user_id`, `normalized_metric_name`).

## What To Test

- **Raw vs derived classification (283/755):** `/app/dashboard` — confirm stat cards for `cpc`, `ctr`, `roas` have `data-metric-scope="derived"` while `clicks`/`total_cost`/`impressions`/`revenue` have a non-`derived` scope.
- **Formula definition (284/756):** confirm cpc = total_cost/clicks, ctr = clicks/impressions, roas = revenue/total_cost by inserting known raw values for a single platform and checking the displayed derived stat matches the hand-computed ratio.
- **Sum-then-derive across time (285/757):** insert component data across multiple days within one date-range filter, confirm the displayed derived value equals sum(component)/sum(component) over the whole range, not an average of daily ratios. Also check whether `cpc`/`ctr`/`roas` ever appear as rows in the Daily/Weekly/Monthly data table when switching granularity — note if they're absent entirely (their time-series entries are always empty per `enrich_with_known_metrics`, which may mean this criterion's "aggregating across time periods" is only demonstrated via the single-period stat card, not a granularity-switch).
- **Sum-then-derive across platforms (286/758):** insert component data for two different providers with different individual ratios (e.g. platform A: cost=100,clicks=10 → raw cpc=10; platform B: cost=10,clicks=100 → raw cpc=0.1). Confirm "All Platforms" shows sum(110)/sum(110)=1.0, not the naive average (5.05) of the two platform ratios. Then filter to each platform individually and confirm the single-platform value matches that platform's own ratio.
- **Never averages across rows (287):** covered by the multi-platform test above — the combined value must equal the re-derived ratio, not an average of pre-computed per-row/per-platform derived values.
- **Combined time+platform aggregation (759):** apply both a custom date range and a platform filter together, confirm the derived value is still sum-then-derive over the doubly-filtered component totals.
- **Data gap reflected, not silently zeroed (289/761):** insert `total_cost` data with NO corresponding `clicks` data at all for the same period/provider. Check whether the dashboard shows any indication ("incomplete", "missing data", "data gap") tied to the derived metric itself, or whether cpc silently renders as `0.0` (safe_divide defaults to 0.0). Note: the page's date-range caption always contains the literal substring "incomplete day" (unrelated text, referring to today being excluded) — confirm any "incomplete" match is actually attached to the derived-metric gap and not a false-positive from that unrelated caption before concluding this passes.
- **Displays identically to raw metrics (290/762):** confirm `cpc`/`ctr`/`roas` stat cards use the same markup/classes (`data-role="stat-card"`) as raw metric stat cards — same sum/avg/min/max layout, AI Insights button, etc.

## Result Path

Findings are filed via `create_issue` as discovered; final result via `submit_qa_result`. No result.md file.

## Setup Notes

The formula table lives in `lib/metric_flow_web/live/dashboard_live/show.ex` (`@known_derived_metrics`), not in a separate Metrics-context module — derived-metric logic is LiveView-local, computed once per render from already-filtered `summary_stats` sums (`Metrics.aggregate_metrics/3`, a real SQL `sum()`/`avg()` aggregate, not an app-level average of rows). `Dashboards.get_dashboard_data/2` is the entry point; `applied_filters` carries the platform/date_range through to both raw stats and (indirectly) the derived computation.

## Results (this pass)

Consumed fixtures: synthetic `metrics` rows with `metric_type='qa_derived_test'` for user_id 2 (google_ads cost=100/clicks=10, facebook_ads spend=10/clicks=100, dated `now() - 2 days`) — a fresh run should use a different `metric_type` tag or delete these first.

**Raw/derived classification (283/755) and identical display (290/762): pass.** `data-metric-scope` correctly reads `"derived"` for cpc/ctr/roas and `"canonical"`/`"platform-specific"` for everything else; derived stat cards use the same `data-role="stat-card"` markup as raw ones.

**Formula/sum-then-derive correctness (284/756, 285/757, 286/758, 287, 759): fail — critical root cause found.** `MetricFlow.Metrics.MetricRepository.aggregate_metrics/3` (used for every dashboard stat card, and therefore for every derived-metric component sum) filters by the raw, provider-specific `metric_name` column instead of the normalized-name-aware helper the sibling query functions use. Live repro: inserted google_ads cost=100/clicks=10 and facebook_ads spend=10/clicks=100 (both normalize to `total_cost`/`clicks`) — the Daily Data table correctly showed `total_cost=110.0` for the day, but the `total_cost` stat card directly below it showed `sum=0.0` for the exact same data, and `cpc` consequently showed `0.0` instead of the correct combined `110/110=1.0`. This isn't a sum-then-derive logic bug (that logic is structurally correct and does re-derive from `raw_sums` rather than averaging rows) — it's that the component sums fed into it are silently wrong whenever a raw metric name differs from its normalized name, which is the common case across providers. Filed as `d2ef8bd0` (critical).

**Data gap reflected, not silently zeroed (289/761): fail.** No code path detects a genuine missing-component gap; `safe_divide/2` defaults to `0.0`. The story's own BDD spex for this criterion (`criterion_761`) passes today only because the dashboard's unrelated date-range caption always contains the literal substring "incomplete day" — a coincidental match, not real gap detection. Filed as `d3f50b48` (high).

## Retest (issues d2ef8bd0, d3f50b48 resolved)

Both fixes confirmed live against the same repro data (google_ads cost=100/clicks=10, facebook_ads spend=10/clicks=100, metric_type='qa_derived_test'):

- `total_cost` stat card now correctly shows `110.0` (was `0.0`) — matches the Daily Data table. `cpc` now correctly shows `1.0`, the real sum-then-derive combined value (110/110), not the previously-broken `0.0` and not the naive per-platform average (5.05). `d2ef8bd0` fixed.
- `ctr` and `roas` (whose components — impressions, revenue — have zero real rows for this account) now render `data-role="stat-incomplete"` instead of a bare `0.0`, correctly distinguishing "no data" from "real zero". `d3f50b48` fixed.

All other criteria (283/755 classification, 290/762 identical display) were already passing and are unaffected. `qa_complete` now satisfied.

**Table/chart behavior for derived metrics (part of 285/757):** `cpc`/`ctr`/`roas` never appear as rows in the Daily/Weekly/Monthly table or as chart lines — their `time_series` entries are always empty (`enrich_with_known_metrics` only ever adds a zero-data placeholder), so switching granularity has no visible effect on them; the only demonstration of "time aggregation" is the single current-filter-range stat card.
