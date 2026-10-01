# Qa Story Brief

Story 39: Calculate Rolling Review Metrics from Review Table

## Tool

web

## Auth

Log in via the password form at `http://127.0.0.1:59302/users/log-in`:

```lua
browser_delete_cookies({})
browser_navigate({ url = "http://127.0.0.1:59302/users/log-in" })
browser_wait_for_load({})
browser_scroll_into_view({ selector = "#login_form_password" })
browser_fill({ selector = "#password_email", text = "qa@example.com" })
browser_fill({ selector = "#user_password", text = "hello world!" })
browser_click({ selector = "#login_form_password button[name='user[remember_me]']" })
```

`qa@example.com` (user id 2) has 129 real review metric rows (`metrics` table, `metric_type = "reviews"`) spanning 2022-08-16 through 2025-11-30, synced from a real Google Business Profile connection earlier this session.

## Seeds

No fresh seeding needed. This story's criteria are pure backend computation (`query_rolling_review_metrics/2`) surfaced, per the story's own BDD spex, on `/app/integrations/google_business/dashboard`.

## What To Test

- **989/990/991/992/993** — Run `mix test test/spex/39_calculate_rolling_review_metrics_from_review_table/*.exs` and visit `/app/integrations/google_business/dashboard` directly to confirm, live, that none of the UI elements these criteria require (`[data-role='rolling-review-metrics-section']`, `[data-role='running-review-total']`, `[data-role='rolling-review-metric-row']`, `[data-role='daily-review-count']`, `[data-role='no-review-data']`) exist anywhere on the page.
- Separately verify, via `mix run -e`, that the underlying computation logic itself is at least correct in one of its two implementations: `MetricFlow.Metrics.query_rolling_review_metrics/2` (reads the real `metrics` table, `metric_type = "reviews"` rows) versus `MetricFlow.Reviews.query_rolling_review_metrics/2` (reads a dedicated `reviews` table that nothing in the sync pipeline ever populates).

## Result Path

`.code_my_spec/qa/39/result.md`

## Setup Notes

This story's component linkage (`IntegrationLive.ProviderDashboard`) does not implement any of this story's criteria. Full investigation before testing:

1. Two separate, duplicate implementations of `query_rolling_review_metrics/2` exist: `MetricFlow.Metrics.ReviewMetrics` (delegated via `MetricFlow.Metrics.query_rolling_review_metrics/2`) queries the generic `metrics` table filtered to `metric_type == "reviews"`. `MetricFlow.Reviews.ReviewMetrics` (delegated via `MetricFlow.Reviews.query_rolling_review_metrics/2`) queries a dedicated `reviews` table (backed by a `MetricFlow.Reviews.Review` schema with `review_date`/`star_rating` columns) that is entirely separate from `metrics`.
2. The real GBP review sync (`lib/metric_flow/data_sync/data_providers/google_business.ex`) writes review data into the generic `metrics` table (`metric_type: "reviews"`, `metric_name: "review_rating"`/`"review_count"`) — it never writes to the dedicated `reviews` table at all. Confirmed live: `reviews` table has 0 rows project-wide; `metrics` table has 174 rows with `metric_type = 'reviews'` (129 for the real qa@example.com account).
3. `grep -rn "query_rolling_review_metrics" lib` finds only the two implementations, their two delegating context modules, and test files — **no caller anywhere in `lib`**, including `ProviderDashboard` (the story's own linked component), which instead has its own ad hoc `load_reviews/1` that lists raw review records directly from the `metrics` table and never computes or renders daily count / running total / rolling average at all.
4. `mix test test/spex/39_.../*.exs` confirms this live: **0/5 passing**. All 5 failures are `has_element?` assertions against `/app/integrations/google_business/dashboard` for elements (`rolling-review-metrics-section`, `running-review-total`, `rolling-review-metric-row`, `daily-review-count`, `no-review-data`) that do not exist anywhere in `ProviderDashboard`'s current source.
5. Via `mix run -e`, confirmed `MetricFlow.Metrics.query_rolling_review_metrics(scope)` against the real 129-row dataset produces correct-looking output (running total incrementing 3, 6, 9, ... 129; rolling average rating trending ~4.86), while `MetricFlow.Reviews.query_rolling_review_metrics(scope)` against the same real scope returns `%{review_count: [], review_average_rating: [], review_total_count: []}` — always empty, since its backing table is never populated by anything.

This is a fail on every criterion: the feature this story describes is not rendered anywhere in the application, and even the module most literally named for "the Review table" is unreachable with real data.

## Retest 2026-10-01

Both issues confirmed resolved. `mix test test/spex/39_.../*.exs` now passes 5/5 (up from 0/5). `ProviderDashboard` now has a real `[data-role='rolling-review-metrics-section']`, backed by `Metrics.query_rolling_review_metrics/2` (the real-data implementation) -- the dead `Reviews.ReviewMetrics` duplicate and its empty-table delegate were removed entirely (confirmed via `grep`).

Live-confirmed 989/990/991/993 by inserting two fresh real-shaped `metrics` rows (`metric_type: "reviews"`, provider `google_business_reviews`) for yesterday and two days ago, then reloading the dashboard with no interaction needed (default `last_30_days` window): the table rendered exactly `2026-09-29: count=1, total=1, avg=5.0` and `2026-09-30: count=1, total=2, avg=4.5` -- correct running total and rolling average, computed on demand straight from the DB insert with zero pre-calculation step. Cleaned up the synthetic rows afterward. The empty state (`993`) was already confirmed live before inserting this data (`[data-role='no-review-data']`, "No review data for this period yet").

992 (date-range scoping) could not be directly confirmed through the browser this pass: selecting a different option in `select[name='date_range']` -- via `browser_select`, and separately via an explicit JS-dispatched `change` event with `bubbles: true` -- never produced a server round trip (the existing, pre-existing-code `review_count` metric chart also stayed empty across range changes, confirming this isn't specific to the new rolling-review code). This matches the `phx-change`/form-event-dispatch flakiness this browser automation tool has shown elsewhere this session, not a new regression: the identical handler code, driven via `Phoenix.LiveViewTest`'s `render_change` in criterion 992's own spex, passes; and calling `Metrics.query_rolling_review_metrics/2` directly via `mix run -e` with the exact `{Date.add(today, -365), today}` tuple the `last_12_months` option produces returns correct, properly-filtered real data (running totals 6, 9, 12 for the account's real late-2025 reviews). Treating 992 as pass on that combined evidence (passing spex + direct function-level confirmation with real data), while flagging the browser-tool limitation for the record.

All 5 criteria now pass. Submitting as pass.
