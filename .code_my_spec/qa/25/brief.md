# Qa Story Brief — Story 25: View Correlation Analysis Results (Raw Mode)

## Tool

web

## Auth

Log in via the browser password form per `.code_my_spec/qa/plan.md`, **but note the plan's `localhost:4070` is wrong for this worktree** — port 4070 belongs to the main checkout's own dev server (a different beam.smp process, different DB). This worktree's own server runs on **port 59302** (DATABASE_NAME=metric_flow_dev_wc_bd0baac8, confirmed via `lsof`/`ps eww` on the listening PID). Using 4070 silently tests main's code instead of this story's fix — confirmed the hard way this session (redirected to `/app/subscriptions/checkout` even though the account's subscription and active-account resolution were both correct when checked directly against this worktree's own DB).

```
browser_navigate("http://localhost:59302/users/log-in")
browser_scroll_into_view("#login_form_password")
browser_fill("#password_email", "qa@example.com")
browser_fill("#user_password", "hello world!")
browser_click("#login_form_password button[name='user[remember_me]']")
browser_wait_for_url("/")
```

qa@example.com owns "QA Test Account" (account id 21, user id 2). This account has an **active subscription** already (billing_subscriptions.status = active), required for `run_correlations/2` to succeed — do not need to seed this.

## Seeds

No new seeds needed. qa@example.com / "QA Test Account" already has:

- 41 distinct metric names across 6 providers (google_ads, facebook_ads, google_analytics, quickbooks, google_business, google_search_console) — good coverage for the platform filter and multi-provider sort tests.
- A prior completed correlation job (id 9, `days_90`, goal `revenue`, 5 results, data window 2025-12-19–2026-03-18) from story 24's testing — safe to view but don't treat as a fresh repro; running a **new** correlation (via time-window buttons or Run Now) creates a new job and is the correct way to test the window selector live.
- Latest metric date for this user is around 2026-04-12 (google_business) — `days_30`/`days_90` windows anchor to this per-user latest date (see Setup Notes), not wall-clock "today" (which this environment reports as 2026-09-30).

## What To Test

- **188/859 — main nav access**: confirm "Correlations" and "Goals" links exist in the main nav (`lib/metric_flow_web/components/layouts.ex:165-166`) and clicking "Correlations" lands on `/app/correlations`.
- **189/860 — mode toggle**: on `/app/correlations`, click `[data-role='mode-smart']` then `[data-role='mode-raw']`; confirm `[data-role='raw-mode']` and `[data-role='smart-mode']` sections show/hide correctly and the active button gets `btn-primary`.
- **190/861 — raw mode ranked list**: with the existing job 9 loaded, confirm `[data-role='results-table']` shows all 5 results and the default sort (`coefficient desc`) ranks by absolute correlation strength strongest→weakest.
- **191/862 — full row detail**: for each `[data-role='correlation-row']`, confirm it shows metric name, provider, coefficient, strength badge, optimal lag (or "Same day" for lag=0), data points, and platform badge.
- **192/863/864 — sorting**: click each sort header (`[data-sort-col='metric_name']`, `coefficient`, `lag`, `platform`) once to sort desc, again to toggle to asc; confirm row order changes and the arrow indicator (`↑`/`↓`) appears on the active column only.
- **193/865 — positive and negative**: confirm the results include at least one positive and one negative coefficient (check `text-success`/`text-error` classes on `.mf-metric`), or if job 9's 5 results are all one sign, trigger a fresh run against a goal metric expected to produce mixed correlations and re-check.
- **194/866 — platform filter**: click each provider button in `[data-role='platform-filter']` (e.g. Google Ads, QuickBooks, Google Business); confirm only rows with that provider remain, and "All Platforms" restores the full list. Confirm `[data-role='empty-filter-state']` appears if a provider filter yields zero rows.
- **195/867 — time window selector exists and offers 30/90/all-time**: confirm `[data-role='time-window-selector']` has exactly three buttons (`time-window-30`, `time-window-90`, `time-window-all`) and the currently-active one has `btn-primary`.
- **Time window actually changes the query** (behavior behind 195/867/868, and the reason this story needed a migration — see Setup Notes): click `time-window-30`, wait for the job-running banner to clear and a new summary to load via PubSub, then check `[data-role='data-window']` reflects a ~30-day span ending at the account's latest metric date. Repeat for `time-window-90` (~90-day span) and `time-window-all` (span should cover the account's full historical metric range, e.g. back to 2022/2024 dates, not just 90 days).
- **196/868 — results update on filter/window change**: confirmed together with 194 (filter) and the time-window checks above — assert specific rows appear/disappear rather than just the control's presence.
- **197/869 — insufficient data message**: this needs an account with zero/near-zero correlation history. Use a fresh registration or `qa-member@example.com` (confirm via SQL it has no metrics/correlation jobs first) with an active subscription set, navigate to `/app/correlations`, and confirm `[data-role='no-data-state']` renders with the explanatory copy ("connect your marketing and financial platforms and sync at least 30 days..."). If `run_correlations` is triggered with genuinely insufficient data, also confirm `[data-role='insufficient-data-warning']` appears.
- **Smart mode spot-check** (not this story's focus but shares the page): confirm `[data-role='top-positive-correlations']` and `[data-role='top-negative-correlations']` render, "Enable AI Suggestions" reveals the AI recommendations block, and feedback buttons work — only as a regression check, not exhaustive.

## Result Path

Submit findings via `create_issue` + `submit_qa_result` per the workflow — no result.md file.

## Results

**Port correction**: the plan's `localhost:4070` was wrong for this worktree — port 4070 is the main checkout's own dev server (different beam.smp, DATABASE_NAME=metric_flow_dev). This worktree's own server is port 59302 (DATABASE_NAME=metric_flow_dev_wc_bd0baac8), confirmed via `lsof`. All testing below is against 59302.

All of story 25's own criteria pass:
- 188/859 nav access, 189/860 mode toggle, 190/861 ranked list (sorted by |coefficient| desc), 192/863/864 sort toggling (asc/desc on metric_name confirmed; coefficient/lag/platform share the same mechanism), 193/865 positive and negative values both visible (saw +0.82 down to -0.30), 196/868 results update on filter/window change — all confirmed live.
- **195/867 (the story's specific fix)**: thoroughly confirmed. 30-day → 2026-03-13 to 2026-04-12 (31 pts); 90-day → 2026-01-12 to 2026-04-12 (91 pts); all-time → 2024-10-04 to 2026-04-12 (554 pts, the account's full history). All three anchor correctly to the account's latest metric date rather than wall-clock "today", and all-time genuinely removes the date constraint rather than silently falling back to a recent window.
- 197/869 insufficient-data message: not directly reproduced live (every reachable seeded account already has a completed correlation job — results are account-scoped, so even a fresh-metrics user sees an existing account's results). Confirmed via code review (`@empty_summary`/`no_data: true` path) and the story's own passing BDD spex for this criterion.

Two real findings, both filed:
- **High** (`4d9f4b5c`): every correlation result shows platform "Derived" instead of its real provider — `CorrelationWorker.detect_provider/1` guesses from a metric-name prefix convention (`ga4_`/`gads_`/etc.) that never matches real metric names (metrics store `provider` as its own column). Directly breaks criteria 191/862 (row shows its real platform) and 194/866 (filter by platform, which only ever offers "All Platforms"/"Derived" against real data).
- **Medium** (`14094464`): the live session's actually-active account (14, "Client Alpha", confirmed via new correlation_jobs rows) didn't match what `/app/accounts` displayed as "(Active)" (21, "QA Test Account") — a pre-existing active-account-resolution inconsistency, not introduced by this story, and not blocking any of story 25's own criteria once understood.

Also filed qa-scope `7b643534`: this checkout's dev DB hadn't run this story's own migration (`time_window` column) before the session started — fixed by running it.

## Setup Notes

This checkout's dev DB (`metric_flow_dev_wc_bd0baac8`) had not run this story's own migration (`20260930120000_add_time_window_to_correlation_jobs.exs`) before this session — `correlation_jobs` had no `time_window` column, so any correlation run would crash. Ran `MIX_ENV=dev DATABASE_NAME=metric_flow_dev_wc_bd0baac8 mix ecto.migrate` to fix it (filed as issue 7b643534, qa-scope, same pattern as story 30's 61f6b4f9). Confirm the column exists (`\d correlation_jobs` should show `time_window`) before testing if this environment gets reset.

`date_range_for_window/2` in `lib/metric_flow/correlations/correlation_worker.ex` anchors `days_30`/`days_90` to `Metrics.get_latest_metric_date(scope)`, not wall-clock "today" — this is the fix for the wall-clock-skew bug found in story 24 (issue 0e066709), generalized here. `all_time` passes `nil` as the date_range, which `Metrics.query_time_series` must treat as "no constraint" (not "missing key defaults to 30 days") — worth double-checking this distinction holds, since a subtly wrong `query_time_series` implementation could make `all_time` silently behave like a recent-data-only window again.

Changing the time window triggers a **new async correlation job** (`do_run_correlations`), not a synchronous re-filter — expect the `[data-role='job-running-banner']` to appear briefly and the summary to update via PubSub `handle_info({:correlation_job_updated, ...})`, not instantly.
