# QA Result

Story 445 — View and Navigate Saved Reports

## Status

pass

## Scenarios

### Scenario 1: Unauthenticated redirect

pass

Verified with curl: `curl -s -w "\nFinal URL: %{url_effective}\nStatus: %{http_code}" -o /dev/null http://localhost:4070/dashboards`

Result: HTTP 302 redirect. The server returns 302 without following the redirect. Following with `-L` lands on the login page (200). Behavior matches the `:require_authenticated_user` pipeline protecting the `/dashboards` route.

### Scenario 2: Page loads and shows heading

pass

Navigated to `http://localhost:4070/dashboards` after logging in as `qa@example.com`. Verified:
- `h1` text is "Dashboards"
- Subtitle "Your saved views and system dashboards" is visible in page text
- `[data-role='new-dashboard-btn']` is present with text "New Dashboard" and `href="/dashboards/new"`

Screenshot: `01_dashboards_page_initial.png`

### Scenario 3: Canned dashboards section is visible

pass

After running `qa_seeds_444.exs` (seeds were already present from a prior run), the canned dashboards section was visible. Verified:
- `[data-role='canned-dashboards']` is present and visible
- Heading "System Dashboards" and subtitle "Pre-built views ready to use" are visible in page text
- Three canned dashboard cards exist: "Marketing Overview", "Revenue Analysis", "Platform Comparison"
- All canned cards have `data-built-in="true"`
- Each canned card shows a "Built-in" badge
- Each canned card has a `[data-role='view-dashboard-{id}']` link
- No `button[data-role^='delete-dashboard']` elements exist within `[data-built-in='true']` cards — confirmed with `find_all` returning no elements

Screenshot: `02_canned_dashboards_section.png`

### Scenario 4: User dashboards section — empty state

pass

With no user-owned dashboards present, verified:
- `[data-role='user-dashboards']` section is present and visible
- Heading "My Dashboards" is visible
- `[data-role='empty-user-dashboards']` is visible with text "No dashboards yet"
- "Create your first dashboard" link is inside the empty state section

Screenshot: `03_user_dashboards_empty_state.png`

### Scenario 5: Create a user dashboard and verify it appears in the list

pass

Navigated to `/dashboards/new`. The form requires at least one visualization before saving (shows validation message "Please add at least one visualization to save the dashboard."). Clicked the "Marketing Overview" template card (`[data-role='template-card-marketing_overview']`), which populated the canvas with four visualizations (Clicks, Spend, Impressions, ROAS). Filled in dashboard name "QA Revenue Dashboard" via `input[placeholder='My Dashboard']`. Clicked "Save Dashboard".

After save, the browser redirected to `/dashboards/4` (the new dashboard's view page). Navigated back to `/dashboards`. Verified:
- "QA Revenue Dashboard" appears in `[data-role='user-dashboards']`
- The card has `data-built-in="false"`
- "View", "Edit", and "Delete" buttons are present

Screenshots: `04_new_dashboard_form.png`, `05_new_dashboard_validation.png`, `06_dashboard_saved_view.png`, `07_dashboards_with_user_dashboard.png`

### Scenario 6: Inline delete confirmation flow

pass

Clicked `[data-role='delete-dashboard-4']`. Waited for `[data-role='delete-confirm-4']` to become visible. Verified:
- `[data-role='delete-confirm-4']` text includes "Are you sure?"
- `[data-role='confirm-delete-4']` ("Yes, delete") button is visible
- `[data-role='cancel-delete']` ("Cancel") button is visible

Clicked "Cancel". Waited for `[data-role='delete-confirm-4']` to reach state "hidden". Verified `[data-role='dashboard-card'][data-dashboard-id='4']` is still visible. The dashboard card was not removed.

Screenshots: `08_delete_confirmation_prompt.png`, `09_cancel_delete_card_still_present.png`

### Scenario 7: Confirm delete removes dashboard

pass

Clicked `[data-role='delete-dashboard-4']` again. Waited for confirm prompt to appear. Clicked `[data-role='confirm-delete-4']`. Waited for `[data-role='dashboard-card'][data-dashboard-id='4']` to reach state "hidden". Verified:
- The dashboard card is no longer in the DOM
- `[data-role='user-dashboards']` reverted to empty state ("No dashboards yet")
- Flash message "Dashboard deleted." appeared (found via `role="alert"`)

Screenshot: `10_dashboard_deleted_flash.png`

### Scenario 8: Clicking "View" on a canned dashboard navigates to it

pass

On `/dashboards` with canned dashboards visible, clicked `[data-role='view-dashboard-1']` (the "Marketing Overview" card, id=1). Waited for URL to match `/dashboards/1`. URL became `http://localhost:4070/dashboards/1`. Navigation was successful.

Screenshot: `11_canned_dashboard_view.png`

## Evidence

- `.code_my_spec/qa/445/screenshots/01_dashboards_page_initial.png` — full-page view of dashboards index after login
- `.code_my_spec/qa/445/screenshots/02_canned_dashboards_section.png` — canned (system) dashboards section with three cards
- `.code_my_spec/qa/445/screenshots/03_user_dashboards_empty_state.png` — empty state for user dashboards section
- `.code_my_spec/qa/445/screenshots/04_new_dashboard_form.png` — new dashboard form before filling
- `.code_my_spec/qa/445/screenshots/05_new_dashboard_validation.png` — validation error shown when saving without visualizations
- `.code_my_spec/qa/445/screenshots/06_dashboard_saved_view.png` — new dashboard view after save (redirected to /dashboards/4)
- `.code_my_spec/qa/445/screenshots/07_dashboards_with_user_dashboard.png` — dashboards list with "QA Revenue Dashboard" in user section
- `.code_my_spec/qa/445/screenshots/08_delete_confirmation_prompt.png` — inline delete confirmation prompt visible
- `.code_my_spec/qa/445/screenshots/09_cancel_delete_card_still_present.png` — card still present after clicking Cancel
- `.code_my_spec/qa/445/screenshots/10_dashboard_deleted_flash.png` — flash "Dashboard deleted." and empty state after confirm delete
- `.code_my_spec/qa/445/screenshots/11_canned_dashboard_view.png` — canned dashboard view page after clicking View

## Issues

None
