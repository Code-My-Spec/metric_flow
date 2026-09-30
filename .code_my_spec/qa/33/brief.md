# Qa Story Brief

Story 33: Cross-Platform Metric Normalization and Mapping

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

App base URL: `http://127.0.0.1:59302` -- this worktree's dev server, confirmed live moments ago during story 18's QA pass on this same checkout. Re-derive via `lsof`/`ps` if it has changed by the time testing starts.

## Seeds

Seeds already in place. `qa@example.com` (QA Test Account owner) has 7 connected integrations including both `google_ads` and `facebook_ads`, both with real `clicks` and `total_cost` metric history from 2022-08 through 2026-04 -- confirmed live during story 18's pass this session (15,846 metric rows, clicks summed to 35,795 across that range). The default 30-day filter window shows nothing (all data predates the current window); use a custom date range spanning `2022-01-01` to `2026-04-12` to see real data, exactly as story 18's pass did:

```lua
browser_click({ selector = "[data-role='date-range-filter'] button[phx-value-range='custom']" })
browser_fill({ selector = "[data-role='custom-date-picker'] input[name='start_date']", text = "2022-01-01" })
browser_fill({ selector = "[data-role='custom-date-picker'] input[name='end_date']", text = "2026-04-12" })
```

**Critical environment note carried over from stories 13/15/8/18 this session:** this worktree's dev server reads database `metric_flow_dev_wc_bd0baac8`, not the default `metric_flow_dev`. Any `mix run -e` shell must `export DATABASE_NAME=metric_flow_dev_wc_bd0baac8` first.

**Consumable seed action for criterion 766 (unmapped metric):** insert one fresh metric row directly via `mix run` with a metric_name that has no entry in any provider's `NormalizedMetric` map (e.g. `custom_audience_overlap_score` for `google_ads`, matching the BDD spex's own fixture) so its `normalized_metric_name` falls back to the downcased raw name, which is not in `NormalizedMetric.known_canonical_names/0`. This is additive and doesn't need cleanup -- it will just always appear as one more platform-specific stat card going forward.

## What To Test

- **763/569 (taxonomy): canonical taxonomy exposes standard metrics** -- With the custom range active, confirm the dashboard's summary-stats/metric-toggles include `clicks`, `total_cost`, `impressions`, `conversions` as canonical names (already partially confirmed in story 18's pass).
- **275/764/765: platform-native names map to canonical names, Google Ads Clicks and Facebook Ads Link Clicks both -> clicks** -- Click `[data-role='metric-mappings-link']`, confirm `[data-role='metric-mappings-panel']` opens listing each connected platform with `[data-role='metric-mapping'][data-native-name='clicks'][data-canonical-name='clicks']` for both `google_ads` and `facebook_ads`.
- **766/276: unmapped platform metric stored as platform-specific** -- After inserting the `custom_audience_overlap_score` metric (see Seeds), reload the dashboard with the custom range and confirm its stat-card has `data-metric-scope="platform-specific"` (vs `"canonical"` for mapped metrics and `"derived"` for cpc/ctr/roas).
- **277/767: user views platform-to-canonical mappings** -- Same as the mappings-panel check above; also confirm `[data-role='close-metric-mappings']` closes it.
- **278/768: dashboard aggregates mapped metrics using canonical name** -- With platform filter = "All Platforms" and the custom range active, confirm the `clicks` stat-card's sum equals the combined total across google_ads + facebook_ads (cross-check against the DB query used in story 18's pass, or against per-platform sums via the platform filter).
- **279/769: chart compares mapped metrics side-by-side across platforms** -- With "All Platforms" selected (no platform filter) and the custom range active, inspect the Vega-Lite chart's `data-spec` JSON for series named `"clicks (google_ads)"` and `"clicks (facebook_ads)"` (the dashboard splits a canonical metric into per-provider series in the chart specifically when it spans more than one provider and no platform filter narrows it -- `expand_with_platform_breakdown/2` in show.ex). Confirm these appear as two distinct color-coded lines, not a single merged "clicks" line.
- **280/770: comparison warns of known semantic differences** -- Confirm `[data-role='semantic-warning']` is present and its text names the Google Ads/Facebook Ads attribution-window difference, when platforms with a genuine cross-platform metric are in view.
- **281/771: no warning shown when no semantic difference is known** -- The footnote's own BDD spex only tests the zero-integration case (onboarding state), which trivially passes since the whole dashboard section is absent then. Test more meaningfully: filter to a single platform via `[data-role='platform-filter']` (e.g. quickbooks only, a financial platform with no cross-platform attribution ambiguity in view) and check whether `[data-role='semantic-warning']` is still shown. The footnote in `show.ex` has no `:if` condition beyond `@has_integrations` overall, so it is expected to still render even when nothing is actually being compared across platforms -- confirm this live and treat it as a finding if so, since it doesn't match the criterion's plain-language intent even though the narrow BDD spex passes.
- **282/772: new platform integrations don't require changes to existing canonical definitions** -- Not independently testable live without adding a real new platform integration type. Verify via code review of `lib/metric_flow/metrics/normalized_metric.ex`: each provider's mapping is a separate module attribute merged into `@provider_maps`, and `known_canonical_names/0` is computed generically from whatever is in that map -- adding a new provider entry requires no edits to any other provider's map or to the taxonomy logic. Note this as a code-review-backed pass.
- **282/773: derived metric (CPC) automatically extends to a newly mapped platform** -- With both google_ads and facebook_ads contributing `total_cost` and `clicks` (already true in the seeded data), confirm the `cpc` stat-card exists with `data-metric-scope="derived"` and a value consistent with combined total_cost / combined clicks across both platforms (per `enrich_with_known_metrics/1` in show.ex, which computes derived stats from summed raw totals across all connected platforms, not per-platform).

## Result Path

.code_my_spec/qa/33/screenshots/

## Setup Notes

Results are recorded via `submit_qa_result` (a DB-backed attempt) plus `create_issue` for findings -- there is no `result.md` file; the path above is where screenshot evidence is saved. This story shares its implementation (`MetricFlowWeb.DashboardLive.Show`) with story 18, already QA'd this session with two filed date-range bugs (103e0ac5, 1059f96a) unrelated to metric mapping -- no need to re-verify those here.

## Results

- 763/569, 764/765, 275, 277/767: pass. `[data-role='metric-mappings-link']` opens `[data-role='metric-mappings-panel']` listing all 6 connected platforms with native->canonical entries; both Google Ads and Facebook Ads show `clicks -> clicks`. Close button confirmed working (initial read of the panel as still-visible right after the click was a stale-DOM artifact from combining too many steps in one script; a follow-up isolated check confirmed it closes correctly).
- 766/276: pass. Inserted a fresh `custom_audience_overlap_score` metric for google_ads with no entry in any provider's `NormalizedMetric` map; its stat-card correctly shows `data-metric-scope="platform-specific"`, distinct from `"canonical"` (clicks, revenue, expenses, etc.) and `"derived"` (cpc, ctr, roas) cards -- confirmed via a full DOM dump of every stat-card's scope attribute.
- 278/768: pass. The `clicks` stat-card sums to 35,795 across the custom 2022-2026 range, combining both google_ads and facebook_ads under the canonical name (`Metrics.aggregate_metrics/3` operates on `normalized_metric_name`, not per-provider).
- 279/769: pass. With "All Platforms" selected, the chart's `data-spec` JSON contains distinct series `"clicks (google_ads)"` and `"clicks (facebook_ads)"` -- `expand_with_platform_breakdown/2` correctly splits a canonical metric into per-provider series for the chart specifically (while stats/table stay aggregated), which is exactly the right reconciliation between this criterion and 278/768's aggregation requirement.
- 280/770: pass. `[data-role='semantic-warning']` is present with attribution-window text naming Google Ads/Facebook Ads.
- 281/771: fail. The footnote has no `:if` guard beyond `@has_integrations`, so it still displays even when filtered to a single platform (quickbooks) with no actual cross-platform comparison in view. The story's own BDD spex only tests the zero-integration case, which trivially passes; the live single-platform case does not match the criterion's intent. Filed low-severity issue 09112199.
- 282/772: pass (code-review-backed, not independently live-testable without a real new integration type). `lib/metric_flow/metrics/normalized_metric.ex` merges each provider's mapping into `@provider_maps` as a separate module attribute; `known_canonical_names/0` is computed generically from whatever's in that map. Adding a new provider requires no edits to any other provider's map or the taxonomy logic.
- 282/773: pass (mechanism verified in code, not with a fully live non-zero repro). `enrich_with_known_metrics/1` computes derived stats (cpc, ctr, roas) from `raw_sums` built across `dashboard_data.summary_stats ++ raw_zero_stats`, which is itself already aggregated across all providers per canonical name -- the same mechanism verified live for criterion 278/768's clicks total. Live `cpc` value happened to be 0.0 in this pass because this account's real seed data has no positive `total_cost`/`cost`/`spend` rows in the queried window (not a normalization bug -- `clicks` alone summed correctly to 35,795 across both platforms).
