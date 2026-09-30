# Qa Story Brief

Story 18: View All Metrics Dashboard

## Tool

web

## Auth

Use `run_browser_script` with the standard `browser_*` tools. Log in as the seeded QA owner via the password form:

```lua
browser_delete_cookies({})
browser_navigate({ url = "http://127.0.0.1:59302/users/log-in" })
browser_wait_for_load({})
browser_scroll_into_view({ selector = "#login_form_password" })
browser_fill({ selector = "#password_email", text = "qa@example.com" })
browser_fill({ selector = "#user_password", text = "hello world!" })
browser_click({ selector = "#login_form_password button[name='user[remember_me]']" })
browser_wait_for_url({ pattern = "/", timeout = 8000 })
```

For the no-integrations/onboarding scenario, use `qa-member@example.com` / `hello world!` if it has no personal integrations (confirmed in story 15's QA pass this session: qa-member owns zero integrations), or a fresh registration with no integrations connected.

App base URL: `http://127.0.0.1:59302` — this worktree's own dev server (port reassigned earlier this session after a harness restart; re-derive via `lsof -nP -iTCP -sTCP:LISTEN | grep beam` / `ps` if it has changed again by the time testing starts).

## Seeds

Seeds already in place. `qa@example.com` (owner of "QA Test Account") has 7 personally-connected integrations from base seeding (confirmed live in stories 13/15 this session): google_analytics, google_ads, google_search_console, google_business, facebook_ads, quickbooks, plus codemyspec. Route is `/app/dashboard` (not `/dashboard` — confirmed via router; the BDD spex use `/app/dashboard` too).

**Critical environment note carried over from stories 13/15/8 this session:** this worktree's dev server reads database `metric_flow_dev_wc_bd0baac8`, not the default `metric_flow_dev`. Any `mix run -e` shell must `export DATABASE_NAME=metric_flow_dev_wc_bd0baac8` first, or it silently writes to nothing the running app sees.

No destructive/consumable seed mutations are needed for this story — all scenarios below are read/filter interactions against qa@example.com's existing data, or a check against a genuinely no-integration account. Nothing here needs to be restored afterward.

## What To Test

- **128: access All Metrics dashboard with data from all connected platforms** — As qa@example.com, navigate to `/app/dashboard`. Confirm it loads (no redirect), shows an "All Metrics" heading, and `[data-role="metrics-dashboard"]` is present with `[data-role="platform-filter"]` listing multiple platforms.
- **129/747: marketing and financial metrics appear together, no distinction** — Confirm the metric-toggles row and chart/table include both marketing-platform metrics (e.g. clicks, impressions from Google/Facebook) and financial metrics (e.g. quickbooks revenue) with no separate section, heading, or visual grouping distinguishing them.
- **130/748: filter by platform, date range, or metric type** — Click a specific platform button in `[data-role="platform-filter"]` (e.g. Google Ads) and confirm the chart/table/metric-toggles update to reflect only that platform's metrics (fewer metric names than "All Platforms"). Toggle a metric off in `[data-role="metric-toggles"]` and confirm it disappears from the table columns and stat cards.
- **131/750: date range options (7/30/90 days, all time, custom)** — Click each button in `[data-role="date-range-filter"]` (`last_7_days`, `last_30_days`, `last_90_days`, `all_time`, `custom`) and confirm the clicked button gets `.btn-primary` and `[data-role="date-range"]`'s text updates accordingly. For `custom`, confirm `[data-role="custom-date-picker"]` appears with From/To date inputs, and that changing them (`update_custom_dates`) updates the displayed range.
- **132/751: default date range excludes today** — On initial load (default `last_30_days`), confirm `[data-role="date-range"]` text includes "today excluded — incomplete day" and the end date shown is yesterday's date, not today's.
- **133/752: dashboard updates dynamically when filters change** — Confirm each filter click above triggers a live update (no full page reload) — chart re-renders (`data-role="vega-lite-chart"`'s `data-spec` attribute changes) and table rows update without navigation.
- **134/753: no integrations connected shows onboarding prompts** — As a user with zero connected integrations, navigate to `/app/dashboard`. Confirm `[data-role="onboarding-prompt"]` is shown with "Connect Your Platforms" text and a link to `/app/integrations`, and `[data-role="metrics-dashboard"]` is NOT present.
- **135/754: visualizations use Vega-Lite** — Confirm `[data-role="vega-lite-chart"][phx-hook="VegaLite"]` is present with a non-empty `data-spec` JSON attribute, and that the chart visibly renders (screenshot) rather than showing the "No metric data available" empty-state text.
- **749: filter combination with no matching data shows an empty state** — Toggle off every metric in `[data-role="metric-toggles"]` (or select a platform/date-range combination with zero data). Confirm the page shows "No metric data available for the selected filters." (chart) and/or "No data to display." (table) and/or "No metrics match the selected filters." (stats) rather than an error or blank page.
- **146 (146/130 duplicate — granularity toggle, not in acceptance criteria list but visible in source)**: not a listed criterion, skip unless time permits; note if broken.

## Result Path

.code_my_spec/qa/18/screenshots/

## Setup Notes

Results are recorded via `submit_qa_result` (a DB-backed attempt) plus `create_issue` for findings — there is no `result.md` file; the path above is where screenshot evidence is saved.

Note from story 8's QA pass this session: `submit_qa_result` intermittently rolled back with an opaque "rollback" error when `issue_ids` was non-empty on a second call for the same task (framework issue 89845d87, since apparently resolved — a later retry on the same task succeeded cleanly). If this recurs, retry once before treating it as a new blocker, and file/reference the existing framework issue rather than duplicating it.

## Results

- 128/569, 129/747: pass. `/app/dashboard` loads with an "All Metrics" heading, `[data-role="metrics-dashboard"]`, and a platform filter listing all 6 connected data platforms (Google Business, Quickbooks, Google Analytics, Google Search Console, Google Ads, Facebook Ads) plus codemyspec. Marketing metrics (clicks, impressions, ctr) and financial metrics (from quickbooks) render in the same unstyled metric-toggle list and chart with no visual distinction or separation.
- **Critical environment discovery, affects most of the remaining criteria:** qa@example.com has 15,846 real metric rows in the DB, but every single one is dated between 2022-08-16 and 2026-04-12 — outside the default 30-day window relative to this environment's current wall-clock time (2026-09-30, the same skew pattern seen in stories 13/15 this session). With the default filter, every stat is 0.0 and the table/chart are empty. Discovered that "All Time" is supposed to be the escape hatch for exactly this case but doesn't work (see below), so verified 128/129/747/130/748/133/752/135/754 using a custom range (2022-01-01–2026-04-12) instead, which correctly surfaced 593 table rows and real, non-zero stats.
- 130/748: partial. Platform filtering works correctly on its own (selecting Google Ads narrows the metric-toggle list to that platform's own metric names). Metric-type toggling works correctly (toggling off a metric removes it from chart/table/stats). But combining a platform filter with an active custom date range silently discards the custom range back to the default 30-day window — filed medium issue 1059f96a.
- 131/750: partial. Last 7/30/90 Days and Custom Range all correctly apply their date windows (verified via distinct real data results for the custom range). "All Time" activates the button but does not actually remove the date constraint — it silently queries the same 30-day default. Filed high issue 103e0ac5 (this is also why the account's real historical data is unreachable through any preset).
- 132/751: pass. Default range on load is "Showing 2026-08-30 – 2026-09-29 (today excluded — incomplete day)" — correctly counts back from yesterday, not today.
- 133/752: pass. Every filter interaction (platform, date range, metric toggle, custom date update) triggers a live re-render with no page navigation — chart's `data-spec` attribute and table rows update in place each time.
- 134/753: pass. Logged in as qa-member@example.com (zero connected integrations, confirmed in story 15's pass): `/app/dashboard` shows `[data-role="onboarding-prompt"]` with "Connect Your Platforms" text and a working link to `/app/integrations`; `[data-role="metrics-dashboard"]` is absent.
- 135/754: pass. With real data loaded (custom range), `[data-role="vega-lite-chart"][phx-hook="VegaLite"]` renders an actual SVG element (Vega-Lite's default renderer), confirmed via `browser_count` for `svg` → 1, not just an empty container.
- 749: pass. Toggling off every metric in `[data-role="metric-toggles"]` produces "No metric data available for the selected filters." (chart) and "No data to display." (table) rather than an error, and zero stat cards render.

## Retest (after fixes for 103e0ac5 and 1059f96a)

Commit e52e4af fixed both issues at their shared root cause (absent-vs-nil ambiguity for :date_range across get_dashboard_data/2, resolve_time_series_date_range/1, and reload_dashboard_data/2). Confirmed live on http://127.0.0.1:59302 as qa@example.com:

- All Time now correctly shows "Showing all available data (today excluded -- incomplete day)" and surfaces all 593 real rows of this account's 2022-2026 data, matching what the custom range showed. Criterion 131/750 now fully passes.
- Platform filter + custom range combination: setting a custom range (2022-01-01 to 2026-04-12) then clicking a platform filter (Google Ads) no longer reverts the date range -- it stays exactly as set. Criterion 130/748 now fully passes.

Both previously-open issues are resolved; all of story 18's criteria now pass.

