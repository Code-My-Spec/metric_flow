# Qa Story Brief

## Tool

web

## Auth

App URL for this session: `http://127.0.0.1:59302`.

Log in as the QA owner via the password form (note: browser_fill has been unreliable this session on these two fields -- use browser_click + browser_type if browser_fill hangs):

```
browser_navigate(url: "http://127.0.0.1:59302/users/log-in")
browser_fill(selector: "#password_email", text: "qa@example.com")
browser_fill(selector: "#user_password", text: "hello world!")
browser_click(selector: "#login_form_password button[name='user[remember_me]']")
browser_wait_for_url(pattern: "/", timeout: 8000)
```

## Seeds

This worktree's dev DB is `metric_flow_dev_wc_bd0baac8`.

Three canned (built_in=true) dashboards already exist, matching the story's own examples exactly: id 1 "Marketing Overview", id 2 "Revenue Analysis", id 3 "Platform Comparison" (all `user_id=2`, i.e. qa@example.com). qa@example.com has real connected integrations with real historical metric data (confirmed by many other stories this session).

## What To Test

- **Criterion 162/774** (default templates provided, user browses them): Visit `/app/dashboards`. Expect a "System Dashboards" section (`data-role="canned-dashboards"`) listing all three built-in dashboards with a "Built-in" badge and a View link each.

- **Criteria 163/775/166/167/781/782/780/164** (selecting a template auto-populates with the user's data; vega-lite; line chart of a base metric; updates as new data syncs; canned dashboard content is template-specific): **Suspected major finding, confirm live** -- `router.ex` maps `/app/dashboards/:id` to `DashboardLive.Show`, and that module's `mount/3` signature is `mount(_params, _session, socket)` -- it discards the `:id` param entirely and always calls `Dashboards.get_dashboard_data(scope, date_range: default_range)` with no reference to which dashboard was requested. Visit `/app/dashboards/1` (Marketing Overview), record the page title/stat cards/chart; then visit `/app/dashboards/2` (Revenue Analysis) and `/app/dashboards/3` (Platform Comparison) and compare. If all three render byte-identical "All Metrics" content (same title, same stat cards, same chart), the three named templates are not actually differentiated in any way -- selecting a specific template never "auto-populates" it with anything template-specific, since there is no template-specific content to populate. This would mean criteria 163/775 pass only in the most literal sense (real data appears) while the story's actual intent (Marketing Overview shows marketing metrics, Revenue Analysis shows revenue metrics, etc.) is not implemented at all. If confirmed, file as a single high-severity issue covering 162's template-differentiation intent and 163/775's "auto-populates it" (implying *that* template's data, not a generic dump).

  The Vega-Lite rendering (166/781) and line-chart-of-a-base-metric (167/782) and automatic-update-on-sync (164/780) criteria are all real and already verified working on this exact `DashboardLive.Show` module in story 18/33's passes this session (real `data-role="vega-lite-chart"` SVG, `handle_info({:sync_completed, ...})` reload) -- so if the page renders at all for any dashboard id, those sub-criteria pass by that prior verification; they just apply uniformly to whichever id you visit rather than per-template, given the finding above.

- **Criterion 776** (template selected before any data has synced shows empty state): Log in as `qa-member@example.com` (or any user with zero integrations) and visit `/app/dashboards/1`. Since `Show.mount/3` checks `Dashboards.has_integrations?(scope)` for the *viewing* user regardless of which dashboard id was requested, expect `data-role="onboarding-prompt"` rather than any dashboard content -- confirms the empty-state mechanism works, though again it isn't really "selecting a template with no data" so much as "any user with no integrations sees the same prompt everywhere."

## Result Path

.code_my_spec/qa/21/result.md

## Setup Notes

This story's implementation and story 18/33 (already QA'd and passed this session) share the exact same `DashboardLive.Show` LiveView and `lib/metric_flow/dashboards.ex` backend -- the generic rendering, Vega-Lite chart, and PubSub auto-update mechanics were already verified live in those passes. This session's job for story 21 is specifically to check whether the three named canned dashboards are actually distinguishable from each other and from the generic "All Metrics" view, since the story's own criteria describe them as distinct templates.

## Results

- **Criteria 162/774** (listing page shows built-in dashboards): PASS. `/app/dashboards` renders a "System Dashboards" section (`data-role="canned-dashboards"`) with three `data-role="dashboard-card"` entries, each correctly named ("Marketing Overview"/id 1, "Revenue Analysis"/id 2, "Platform Comparison"/id 3), each with its own distinct description text, a "Built-in" badge, and a View link to `/app/dashboards/{id}`.

- **Criteria 163/775/166/167/781/782/780/164** (template-specific auto-population): FAIL -- suspected finding confirmed live. Logged in as `qa@example.com` (real integrations, real historical data) and visited `/app/dashboards/1`, `/2`, and `/3` in turn: all three returned `<h1>All Metrics</h1>` and a byte-identical `<main>` body (29566 chars, verified via direct string equality, not just length). `DashboardLive.Show.mount/3` discards the `:id` route param entirely and always renders the generic "All Metrics" view -- the three named canned dashboards are not differentiated from each other or from the generic view in any way. Filed as issue `0e10ecbc-89a9-4693-a7ea-5b86eefb8cab` (high). The Vega-Lite rendering, line-chart-of-base-metric, and auto-update-on-sync sub-mechanics are real and working (already verified on this exact module in stories 18/33's passes) -- they just apply uniformly to every dashboard id rather than per template, which is exactly the bug.

- **Criterion 776** (empty state before any data synced): PASS. `qa-empty@example.com` (id 20, confirmed via DB query to have zero rows in `integrations`) shows `data-role="onboarding-prompt"` ("Connect Your Platforms" / "Connect your marketing and financial platforms...") when visiting `/app/dashboards/1`, regardless of which dashboard id was requested -- consistent with `Show.mount/3`'s `Dashboards.has_integrations?(scope)` check running before (and independently of) any dashboard-id-specific logic.

  Note for future testers: `qa-member@example.com` is NOT a zero-integration user despite the name -- it has its own real integration rows (`integrations.user_id` is per-user, not per-account, despite users sharing an `account_members` business account). Use `qa-empty@example.com` or `qa-noint@example.com` instead. Also: a GET navigation to `/users/log-out` does not actually end the session (Phoenix's logout route requires POST/DELETE) -- use `browser_delete_cookies({})` to force a clean session before switching test users, or the browser will silently keep testing as the previously logged-in user while appearing to have logged in as someone else.

**Overall: partial.** One high-severity issue filed (`0e10ecbc-89a9-4693-a7ea-5b86eefb8cab`) covering criteria 162's template-differentiation intent and 163/775's per-template "auto-populates it" claim.

## Retest (issue 0e10ecbc, commit 2f4d80c)

`DashboardLive.Show.mount/3` now resolves the requested dashboard by id (canned dashboards looked up unscoped, matching the listing page; other ids fall back to ownership-scoped lookup) and, for a recognized canned template, filters `dashboard_data` down to a per-template metric set.

Confirmed live as qa@example.com: `/app/dashboards/1`, `/2`, `/3` now render genuinely different `<main>` content -- body lengths 20057 / 7065 / 10681 chars respectively (previously byte-identical at 29566 each). Browser tab `<title>` correctly reads "Marketing Overview" / "Revenue Analysis" / "Platform Comparison" per dashboard (`@page_title` assign, lib/metric_flow_web/live/dashboard_live/show.ex:503). Criteria 162/163/775 (and by extension 166/167/781/782/780/164, which apply to whichever content is now correctly rendered) pass.

One new, much smaller finding: the on-page visible `<h1>` (show.ex:60) is still a hardcoded literal `"All Metrics"` string, never interpolated from `@page_title` -- so the browser tab says "Marketing Overview" but the heading on the page itself still says "All Metrics" for all three dashboards. Filed as issue `f62d6934-b019-4ced-9ced-2a90257effa8` (low) -- not blocking, since no acceptance criterion specifically requires the in-page heading to name the template, and the browser tab title + underlying data are both correct.

Re-verified criterion 776 (empty state) after the mount/3 rewrite: qa-empty@example.com still sees `data-role="onboarding-prompt"` on `/app/dashboards/1` -- the has_integrations? check still runs correctly ahead of the new per-dashboard resolution logic.

**Overall: pass.** One new low-severity cosmetic issue filed (`f62d6934-b019-4ced-9ced-2a90257effa8`), not blocking.
