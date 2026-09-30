# QA Story 22 Brief: View and Navigate Saved Reports

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

This worktree's dev server reads database `metric_flow_dev_wc_bd0baac8`, not the default `metric_flow_dev` -- any direct `mix ecto.migrate`/`mix run -e` shell must set `DATABASE_NAME=metric_flow_dev_wc_bd0baac8` explicitly (config/dev.exs reads it from env; a bare shell doesn't have it set the way the dev server process does).

"Reports" in this story are `MetricFlow.Dashboards.Visualization` records (the same entities from story 19/29's visualization editor), listed at `/app/reports` by `ReportLive.Index`. Clicking a report's "View" button navigates to `/app/visualizations/:id/edit` (the editor) -- confirmed intentional against this story's own BDD spex (171/819), which explicitly asserts a live_redirect to the editor route, not `/app/reports/:id`. A separate `ReportLive.Show` LiveView also exists at `/app/reports/:id` with its own date-range filter, share button, and expand/collapse -- it implements criterion 174/822 (date-range persistence) and is reached directly by URL, not linked from the list UI.

Create a couple of fresh visualizations via `/app/visualizations/new` (pick a metric, name it, save) to populate the reports list for sorting/search/duplicate tests -- the account may already have others from prior sessions.

## What To Test

- **List view (168/815):** `/app/reports` shows all saved reports as `data-role="report-card"` cards with name, type caption, and Shareable badge where applicable.
- **Sort order (169/816):** `list_visualizations/1` orders by `updated_at desc, id desc` (code-verified in `visualizations_repository.ex`). Live-confirm: toggling favorite or duplicating (both call `update_visualization`/insert, bumping `updated_at`) on an older report should move it to the top of the list on next render.
- **Search by name (170/817):** type into `[data-role="report-search-input"]`; list should filter client-side (debounced 200ms) to matching names only.
- **Empty search result (818):** search for a name matching nothing; expect `[data-role="no-search-results"]` with the query echoed, not the generic empty-reports state.
- **Empty state (part of 168):** with search cleared and (hypothetically) zero reports, `[data-role="empty-reports"]` should show instead -- note this account likely has existing reports, so this may only be code-reviewable unless a fresh account is used.
- **View opens full view (171/819):** click `[data-role="view-report-<id>"]` -- expect navigation to `/app/visualizations/<id>/edit` showing the chart preview/editor, per the spex's own expectation.
- **Favorite (172/820):** click `[data-role="favorite-report-<id>"]`; label toggles "☆ Favorite" <-> "★ Favorited", and the report appears/disappears from the "Favorite Reports" section (`[data-role="favorite-reports"]`). Reload the page and confirm the favorite persisted (DB-backed via `is_favorite`).
- **Duplicate (173/821):** click `[data-role="duplicate-report-<id>"]`; expect a new card named "<original> (Copy)", a success flash, and the new copy NOT inheriting `is_favorite`/`last_viewed_date_range` (fresh variation) but inheriting the same bound metrics and vega_spec.
- **Date range persists on reopen (174/822):** navigate directly to `/app/reports/<id>`, click a non-default date-range button (e.g. "Last 90 Days") in `[data-role="date-range-filter"]`, confirm the chart re-renders for that range, then reload the page (or navigate away and back) -- the previously-selected range button should still show as active (`btn-primary`), proving `last_viewed_date_range` was persisted and restored via `parse_date_range_key/1`.
- **Delete gating:** confirm the Delete button (`[data-role="delete-report-<id>"]`) only appears when `can_modify` is true (owner/admin/account_manager) -- check with `qa-member@example.com` (read_only in QA Test Account) if time permits, otherwise code-review `mount/3`'s `can_modify` assignment.

## Result Path

Findings are filed via `create_issue` as discovered; final result via `submit_qa_result`. No result.md file.

## Results (this pass)

**List view (168/815): pass.** `/app/reports` shows all 24 (then 25 after duplicate) seeded reports as `report-card` entries with name and type caption.

**Sort order (169/816): pass.** `list_visualizations/1` orders `updated_at desc, id desc` (code-verified). Live-confirmed: duplicating report 22 produced a new report (id 25) that appeared first in the list immediately, ahead of items with higher-but-stale ids.

**Search by name (170/817) and empty search result (818): fail.** The search input's `phx-change="search"` never fires in a real browser -- tried `browser_type`, `browser_fill`, and a manual `dispatchEvent(new Event('input', {bubbles:true}))`; the DOM input's own `.value` updates every time but the reports-card count never changes from 24, and the server-rendered `value=""` on the input never reflects the typed text. `phx-click` works perfectly fine elsewhere on the exact same page load (toggle_favorite), and the handler itself is correct per the passing `mix test` LiveView-protocol-level spex. Filed as `0dfd2aea` (high).

**View opens full view (171/819): pass.** Clicking `[data-role='view-report-22']` correctly live-redirects to `/app/visualizations/22/edit`, matching the story's own spex expectation (Reports and Visualizations share a full-view route; a separate `ReportLive.Show` at `/app/reports/:id` also exists and is what implements date-range persistence below).

**Favorite (172/820): pass.** Clicking `[data-role='favorite-report-22']` toggled the label to "★ Favorited", populated the Favorite Reports section, and persisted across a full page reload (`is_favorite` DB-backed).

**Duplicate (173/821): pass.** Clicking `[data-role='duplicate-report-22']` created a new report named "QA Story19 MultiMetric Viz (Copy)" (id 25), did not inherit `is_favorite`, and sorted to the top of the list per its fresh `updated_at`.

**Date range persists on reopen (174/822): pass.** On `/app/reports/22`, clicking "Last 90 Days" then reloading the page kept "Last 90 Days" highlighted as active -- `last_viewed_date_range` is correctly persisted to the visualization row and restored via `parse_date_range_key/1` on next mount.

**Delete gating:** could not cross-test live -- `list_visualizations/1` scopes strictly by `user_id`, so `qa-member@example.com` (a different user, read_only member of the same QA Test Account) sees zero reports at all, making a second-user delete-button check impossible via this account setup. Code-reviewed instead: `can_modify` (owner/admin/account_manager) gates both the button's visibility (`:if={@can_modify}`) and is re-checked inside `confirm_delete`'s handler before the actual delete call, so this is defense-in-depth even if the button were somehow clicked.

## Setup Notes

App was returning `Phoenix.Ecto.PendingMigrationError` on every route at session start -- migration `20260930130000_add_favorite_and_date_range_to_visualizations` (this story's own feature) had never been run against this worktree's DB. Fixed by running `DATABASE_NAME=metric_flow_dev_wc_bd0baac8 mix ecto.migrate`. Filed as issue `76326e06` (qa scope) since the same class of blocker (wrong/stale worktree DB) has hit multiple stories this session.
