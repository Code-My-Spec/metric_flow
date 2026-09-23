# QA Result

## Status

pass

## Scenarios

### Scenario 1: Access to goal metrics from the correlations menu

pass

Navigated to `http://localhost:4070/correlations` after login as qa@example.com. The page loaded the correlations index. Searched for `[data-role="configure-goals"]` and `a[href='/correlations/goals']` — both found the element "Configure Goals" link. Clicking the link navigated successfully to `http://localhost:4070/correlations/goals`.

The "Configure Goals" link was added to the correlations index page after the initial test run. The link is discoverable from the UI and functional.

Evidence:
- `.code_my_spec/qa/446/screenshots/01b_correlations_index_with_configure_goals.png` — Correlations index with Configure Goals link visible
- `.code_my_spec/qa/446/screenshots/01c_goals_page_via_configure_goals_link.png` — Goals page reached by clicking the link

### Scenario 2: Direct navigation to goal metrics page

pass

Navigated directly to `http://localhost:4070/correlations/goals`. The page loaded correctly with:

- H1 "Goal Metric" — present
- Subtitle "Choose the metric the correlation engine targets." — present
- `<select name="goal_metric_name">` dropdown — present and populated with 25+ metric names
- Save Goal button `[data-role="save-goal"]` — present and enabled (metrics exist)
- Cancel button `[data-role="cancel"]` — present and enabled

Evidence: `.code_my_spec/qa/446/screenshots/02_goals_page_direct.png`, `.code_my_spec/qa/446/screenshots/02b_goals_page_with_metrics.png`

### Scenario 3: Empty state when no metrics are synced

partial — cannot test

The QA Test Account has synced metric data from prior integration runs (25+ distinct metric names). The empty state path — "No metrics available. Connect your integrations and sync data before configuring a goal." — could not be exercised without purging metric data from the database.

The source code was reviewed and the empty state branch is implemented correctly in `CorrelationLive.Goals`: when `metric_names == []`, the disabled placeholder option and "Connect Integrations" link are rendered, and the Save Goal button is disabled. This path was not tested via the browser.

No seed script or QA utility exists to reset the account to a zero-metrics state. This is a QA limitation, not an app failure.

### Scenario 4: Unauthenticated redirect

pass

Verified via curl (unauthenticated HTTP request, no session cookie):

```
curl -v http://localhost:4070/correlations/goals
HTTP/1.1 302 Found
location: /users/log-in
set-cookie: _metric_flow_key=...; path=/; HttpOnly; SameSite=Lax
```

An unauthenticated request to `/correlations/goals` returns HTTP 302 and redirects to `/users/log-in`. The flash cookie includes the message "You must log in to access this page."

Evidence: `.code_my_spec/qa/446/screenshots/04_unauth_redirect_login_page.png`

### Scenario 5: Cancel button navigates away

pass

Logged in, navigated to `http://localhost:4070/correlations/goals`. Clicked the Cancel button `[data-role="cancel"]`. The browser navigated immediately to `http://localhost:4070/correlations` without saving any changes. The correlations index loaded correctly.

Evidence: `.code_my_spec/qa/446/screenshots/05_after_cancel_correlations.png`

### Scenario 6: System stores goal metrics per account

pass

Metric data was available in the QA account (25+ metrics synced from prior integration tests). Navigated to `/correlations/goals`. The dropdown was pre-selected to "revenue" (the existing goal from the latest correlation summary). Selected "activeUsers" from the dropdown and clicked Save Goal.

Result: flash message "Goal metric saved. Correlation analysis started." appeared and the page redirected to `/correlations`. The correlations index showed a "Correlation analysis is running. This page will reflect the latest results once complete." banner, confirming the correlation job was enqueued successfully.

Evidence: `.code_my_spec/qa/446/screenshots/06a_goal_selected.png`, `.code_my_spec/qa/446/screenshots/06b_after_save_correlations.png`

### Scenario 7: Goal metric selection persists

pass

After saving "activeUsers" in Scenario 6, navigated back to `/correlations/goals`. The dropdown was pre-selected to "activeUsers", confirming the goal was persisted and pre-loaded from the latest correlation summary on mount. The goal was then restored to "revenue" for cleanup.

Evidence: `.code_my_spec/qa/446/screenshots/07_goal_persisted.png`

## Evidence

- `.code_my_spec/qa/446/screenshots/01b_correlations_index_with_configure_goals.png` — Correlations index with Configure Goals link (re-test after fix)
- `.code_my_spec/qa/446/screenshots/01c_goals_page_via_configure_goals_link.png` — Goals page reached via Configure Goals link
- `.code_my_spec/qa/446/screenshots/01_correlations_index.png` — Original correlations index screenshot (no link present, pre-fix)
- `.code_my_spec/qa/446/screenshots/02_goals_page_direct.png` — Goals page on direct navigation, form visible
- `.code_my_spec/qa/446/screenshots/02b_goals_page_with_metrics.png` — Goals page with populated metric dropdown
- `.code_my_spec/qa/446/screenshots/04_unauth_redirect_login_page.png` — Login page shown after unauthenticated redirect (curl-verified 302)
- `.code_my_spec/qa/446/screenshots/05_after_cancel_correlations.png` — Correlations index after Cancel clicked
- `.code_my_spec/qa/446/screenshots/06a_goal_selected.png` — Goals page with "activeUsers" selected before save
- `.code_my_spec/qa/446/screenshots/06b_after_save_correlations.png` — Correlations index after save, showing flash and running banner
- `.code_my_spec/qa/446/screenshots/07_goal_persisted.png` — Goals page showing "activeUsers" pre-selected after save

## Issues

### Empty state cannot be tested without metric data reset capability

#### Severity
LOW

#### Scope
qa

#### Description
Scenario 3 (empty state when no metrics are synced) could not be executed because the QA Test Account has 25+ synced metric names from prior integration test runs. No seed script or QA utility exists to reset the account to a zero-metrics state.

The empty state branch in `CorrelationLive.Goals` was verified via code review only, not via browser test. To make this scenario testable, a QA reset script should be added that truncates `metric_values` for the QA account or a dedicated empty-account fixture should be provided.
