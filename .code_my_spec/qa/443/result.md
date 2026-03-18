# QA Result — Story 443: Create and Save Custom Reports

**Status:** fail

**Tested:** 2026-03-15
**Tester:** QA Agent (Claude Sonnet 4.6)
**App URL:** http://localhost:4070
**Auth:** qa@example.com

---

## Scenarios

### Scenario 1: Unauthenticated access is blocked

**Result:** pass

Navigated to `http://localhost:4070/dashboards/new` without logging in. The app redirected to `http://localhost:4070/users/log-in` as expected. The editor page was not accessible.

**Evidence:** `.code_my_spec/qa/443/screenshots/01-unauthenticated-redirect.png`

---

### Scenario 2: New Dashboard editor page loads for authenticated user

**Result:** pass

After login, the app redirected directly to `/dashboards/new` (Phoenix preserved the originally requested URL). The editor loaded with:
- Heading: "New Dashboard"
- `data-role="dashboard-name-input"` present
- `data-role="save-dashboard-btn"` with text "Save Dashboard" present
- Cancel link pointing to `/dashboards` present (note: this link is broken — see Issue 2)

**Evidence:** `.code_my_spec/qa/443/screenshots/02-new-dashboard-editor.png`

---

### Scenario 3: Template chooser is shown on the blank new-dashboard page

**Result:** pass

On fresh load of `/dashboards/new`, the `data-role="template-chooser"` section was visible with:
- Intro text: "Start from a template or blank canvas"
- Template card for "Financial Summary" (Clicks, Spend, Impressions, and ROAS at a glance)
- Template card for "Marketing Overview" (Revenue, Conversions, and CPC trends)
- "Blank Canvas" card (`data-role="template-card-blank"`) with text "Start with an empty dashboard"
- Empty canvas state (`data-role="empty-canvas"`) with text "Add a visualization to get started"

**Note:** The "can't be blank" name error is displayed immediately on page load without any user interaction — see Issue 1.

**Evidence:** `.code_my_spec/qa/443/screenshots/03-template-chooser.png`

---

### Scenario 4: Selecting a template populates the canvas

**Result:** pass

Clicked the "Marketing Overview" template card (`data-role="template-card-marketing_overview"`). Result:
- 4 visualization cards appeared on the canvas: Clicks (bar), Spend (line), Impressions (area), ROAS (line)
- Empty canvas state (`data-role="empty-canvas"`) disappeared
- Template chooser (`data-role="template-chooser"`) disappeared (hidden because canvas is no longer empty)
- All 4 cards had correct metric names and chart type badges

**Evidence:** `.code_my_spec/qa/443/screenshots/04-template-selected-canvas.png`

---

### Scenario 5: "+ Add Visualization" button opens the metric picker

**Result:** pass (with expected empty metric state)

Clicked `data-role="add-visualization-btn"`. The metric picker panel (`data-role="metric-picker"`) appeared with:
- Title "Add Visualization"
- Close button (`data-role="close-metric-picker"`)
- Metric list showing: "No metrics available. Connect a platform to get started." (expected — QA seeds do not include metric records)
- Chart type selector with Line, Bar, Area buttons
- "Add to Dashboard" confirm button (`data-role="confirm-add-btn"`) in disabled state (no metric selected)

**Evidence:** `.code_my_spec/qa/443/screenshots/05-metric-picker-open.png`

---

### Scenario 6: Closing the metric picker without adding a visualization

**Result:** pass

Clicked `data-role="close-metric-picker"`. The metric picker disappeared. The canvas retained all 4 visualization cards from the template selection — no state was lost.

**Evidence:** `.code_my_spec/qa/443/screenshots/06-metric-picker-closed.png`

---

### Scenario 7: Adding a visualization manually via the metric picker

**Result:** skipped — no metrics seeded for qa@example.com

The base QA seeds do not create any metric records. The metric picker shows "No metrics available." There are no metric buttons to click, so this scenario could not be tested via the browser.

---

### Scenario 8: Removing a visualization from the canvas

**Result:** pass

Removed all 4 visualization cards one at a time using the Remove button (aria-label "Remove"):
- Each click removed the first card from the top
- After all 4 were removed, the empty canvas state (`data-role="empty-canvas"`) reappeared
- The template chooser also reappeared (canvas empty again)

**Evidence:** `.code_my_spec/qa/443/screenshots/08-after-removal-empty-canvas.png`

---

### Scenario 9: Reordering visualizations (move up / move down)

**Result:** pass

Loaded a fresh page, selected "Marketing Overview" template (order: Clicks, Spend, Impressions, ROAS).

- Clicked "Move down" on first card (Clicks) → order became: Spend, Clicks, Impressions, ROAS (confirmed by reading canvas text)
- Clicked "Move up" on second card (Clicks) → order restored to: Clicks, Spend, Impressions, ROAS

Both move up and move down work correctly.

**Evidence:**
- `.code_my_spec/qa/443/screenshots/09a-after-move-down.png`
- `.code_my_spec/qa/443/screenshots/09b-after-move-up.png`

---

### Scenario 10: Save validation errors

**Result:** partial pass / partial fail

**No visualizations + blank name:** Clicking "Save Dashboard" on a fresh page (no visualizations, blank name) showed both errors simultaneously:
- "can't be blank" (name validation)
- "Please add at least one visualization to save the dashboard." (viz_error)

Both errors appeared as expected. No redirect occurred.

**Visualizations present, blank name:** After selecting the Marketing Overview template (4 visualizations present), clicking "Save Dashboard" showed only the "can't be blank" name error and no redirect. This is correct behavior.

**Note:** The "can't be blank" error is already shown on page load before any user interaction (see Issue 1). This makes it impossible to distinguish between a pristine form and an invalid submission.

**Evidence:**
- `.code_my_spec/qa/443/screenshots/10a-save-both-errors.png`
- `.code_my_spec/qa/443/screenshots/10b-save-blank-name-error.png`

---

### Scenario 11: Naming and saving a new dashboard

**Result:** fail — unable to complete

The `phx-change="validate_name"` event on the dashboard name input is not being triggered by vibium's `browser_fill`, `browser_type`, or `browser_keys` (key presses). The LiveView's server-side changeset is never updated with the typed name. `do_save` calls `extract_name(socket.assigns.changeset)` which returns `""` because the changeset params start as `%{}` and are never updated. All save attempts fail with "can't be blank".

Attempted approaches:
- `browser_fill` followed by `browser_press(Tab)` — phx-change did not fire
- `browser_type` character by character — phx-change did not fire
- `browser_keys` (individual keypresses) — phx-change did not fire
- Using `@ref` selector from `browser_map` — phx-change did not fire

This is a vibium tooling limitation with LiveView `phx-change` on standalone inputs (not inside a form element). See Issue 3 (QA scope).

**Evidence:** `.code_my_spec/qa/443/screenshots/11-save-blocked-name-blank.png`

---

### Scenario 12: Saved dashboard appears in the list

**Result:** fail — route does not exist

Navigated to `http://localhost:4070/dashboards` (the route used by the Cancel link and referenced in the spec as the dashboard list). The app returned a `Phoenix.Router.NoRouteError` — there is no GET /dashboards route. The actual dashboard index route is `/dashboard` (singular), which renders `DashboardLive.Show :index` (an analytics metrics view, not a report list).

Because Scenario 11 (save) also failed, no dashboard was created during this QA run. Even if a dashboard were created, there is no list page to verify it appears in.

**Evidence:** `.code_my_spec/qa/443/screenshots/12-dashboard-list.png`

---

### Scenario 13: Editing a saved dashboard

**Result:** fail — redirect broken

Navigated to `http://localhost:4070/dashboards/999999/edit` (non-existent ID) to test the not-found redirect. The LiveView redirected to `/dashboards` (the error flash redirect in `handle_params`), which returned a `Phoenix.Router.NoRouteError`. The redirect target should be `/dashboard` (singular) to match the actual route.

Could not test the happy path (editing a real saved dashboard) because saving is blocked by the name input issue.

**Evidence:** `.code_my_spec/qa/443/screenshots/13-edit-nonexistent-redirects.png`

---

### Scenario 14: Cancel link returns to the dashboard list

**Result:** fail — Cancel link points to non-existent route

The Cancel link in the editor (`<.link navigate="/dashboards">Cancel</.link>`) navigates to `/dashboards`, which is not a defined route. Clicking Cancel produces a `Phoenix.Router.NoRouteError`.

The correct path should be `/dashboard` (singular) to match the `DashboardLive.Show :index` route.

**Evidence:** `.code_my_spec/qa/443/screenshots/bug-cancel-404.png`

---

## Issues

### Issue 1 — Name validation error shown on fresh page load

**Severity:** MEDIUM
**Scope:** app
**Title:** "can't be blank" error shown immediately on /dashboards/new before user interaction

**Description:** When navigating to `/dashboards/new`, the name input renders with `class="input w-full input-error"` and a visible error paragraph `"can't be blank"` is displayed before the user has typed anything or attempted to save. This is because `has_name_error?/1` checks `changeset.errors` directly without checking if the changeset action has been set (i.e., without an `if @changeset.action` guard). The initial changeset created by `Dashboards.dashboard_changeset(%Dashboard{}, %{})` with empty attrs already has a `:name` error in the errors list, so the error is shown immediately.

**Expected:** The name field should start in a neutral state with no error shown. The "can't be blank" error should only appear after the user attempts to save or clears the field.

**Fix:** In `has_name_error?/1`, also check `changeset.action != nil` before returning true. The template condition should be `:if={has_name_error?(@changeset)}` guarded by action being set, or use `Ecto.Changeset.traverse_errors` after marking the changeset with `Map.put(changeset, :action, :validate)` only on user interaction.

**Reproduction:** Navigate to `http://localhost:4070/dashboards/new` while logged in. The red "can't be blank" error appears immediately in the name field.

**Evidence:** `.code_my_spec/qa/443/screenshots/bug-name-error-on-fresh-load.png`

---

### Issue 2 — Cancel link and not-found redirect use wrong path /dashboards

**Severity:** HIGH
**Scope:** app
**Title:** Cancel link and not-found redirect navigate to /dashboards which does not exist

**Description:** Two places in `MetricFlowWeb.DashboardLive.Editor` reference `/dashboards` (plural) as a navigation target:

1. The Cancel link: `<.link navigate="/dashboards" class="btn btn-ghost">Cancel</.link>` (line 67 of editor.ex)
2. The not-found redirect in `handle_params`: `redirect(to: "/dashboards")` (line 305 of editor.ex)

The router has no GET `/dashboards` route. The actual dashboard index route is GET `/dashboard` (singular), handled by `DashboardLive.Show :index`. Both navigation targets result in a `Phoenix.Router.NoRouteError` error page.

**Expected:** Cancel link should navigate to `/dashboard`. Not-found redirect should also go to `/dashboard`.

**Reproduction:**
1. Log in and navigate to `/dashboards/new`. Click "Cancel" → 404 error page.
2. Navigate to `/dashboards/999999/edit` → LiveView redirects to `/dashboards` → 404 error page.

**Evidence:**
- `.code_my_spec/qa/443/screenshots/bug-cancel-404.png`
- `.code_my_spec/qa/443/screenshots/13-edit-nonexistent-redirects.png`

---

### Issue 3 — vibium browser_fill/browser_type/browser_keys do not trigger phx-change on LiveView inputs without a form wrapper

**Severity:** HIGH
**Scope:** qa
**Title:** vibium cannot trigger phx-change on standalone text inputs — saving cannot be tested

**Description:** The dashboard name input uses `phx-change="validate_name"` directly on an `<input>` element (not inside a `<form phx-change="...">` wrapper). Vibium's `browser_fill`, `browser_type`, and `browser_keys` commands all update the DOM value property but do not dispatch DOM events that Phoenix LiveView hooks — the `phx-change` event never reaches the server. As a result:

- The server-side changeset params are never updated
- `extract_name/1` always returns `""` from the initial empty changeset
- All save attempts fail with a "can't be blank" error
- Scenarios 11 (save new dashboard), 12 (appear in list), and 13 (edit saved dashboard) could not be tested

Contrast: `phx-click` events (template selection, remove, reorder buttons) worked correctly throughout the session.

**Attempted workarounds:** `browser_fill` + `Tab`, `browser_type` character by character, `browser_keys` with Control+a followed by characters, pressing Enter, using `@ref` selectors from `browser_map`. None triggered phx-change.

**Recommendation:** Investigate whether vibium/Playwright's `page.fill()` and `keyboard.press()` dispatch `input` DOM events recognized by Phoenix LiveView's JS hooks. A workaround may be to use `page.evaluate()` to dispatch a native `InputEvent` or to wrap the input in a `<form phx-change="...">` in the editor template, which vibium may handle more reliably via form submission events.

---

## Summary

| Scenario | Result |
|---|---|
| 1. Unauthenticated access blocked | pass |
| 2. Editor page loads correctly | pass |
| 3. Template chooser shown on blank canvas | pass |
| 4. Template selection populates canvas | pass |
| 5. Metric picker opens with correct UI | pass |
| 6. Closing metric picker preserves canvas | pass |
| 7. Add visualization manually (metrics) | skipped (no metrics seeded) |
| 8. Remove visualization from canvas | pass |
| 9. Reorder visualizations (move up/down) | pass |
| 10. Save validation errors | partial pass |
| 11. Name and save new dashboard | fail (vibium phx-change issue) |
| 12. Saved dashboard appears in list | fail (route /dashboards missing) |
| 13. Edit saved dashboard | fail (redirect broken + route missing) |
| 14. Cancel link navigates back | fail (route /dashboards missing) |

**Bugs found:** 3
- Issue 1 (MEDIUM, app): Name error shown on fresh page load
- Issue 2 (HIGH, app): Cancel link and not-found redirect use wrong path /dashboards
- Issue 3 (HIGH, qa): vibium cannot trigger phx-change on standalone inputs
