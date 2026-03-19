# QA Result

Story 448: View Correlation Analysis Results (Raw Mode)

## Status

pass

## Scenarios

### Scenario 1 — Navigation link exists

pass

Navigated to `http://localhost:4070/dashboard` as `qa@example.com`. Found `<a href="/correlations">Correlations</a>` in the main navigation. The link is present and correctly attributed.

Evidence: `.code_my_spec/qa/448/screenshots/scenario1_nav_correlations_link.png`

### Scenario 2 — Correlations page is accessible via navigation

pass

Navigated to `http://localhost:4070/correlations`. URL resolved correctly. H1 "Correlations" was found. Subtitle "Which metrics drive your goal?" was confirmed via CSS selector. Both elements present.

Evidence: `.code_my_spec/qa/448/screenshots/scenario2_correlations_page.png`

### Scenario 3 — Unauthenticated redirect

pass

After logging out (DELETE `/users/log-out` via the "Log out" link), navigated to `http://localhost:4070/correlations`. Browser was redirected to `http://localhost:4070/users/log-in`. Confirmed both via curl (`302` to `/users/log-in`) and via browser URL check.

Evidence: `.code_my_spec/qa/448/screenshots/scenario3_unauthenticated_redirect.png`

### Scenario 4 — No-data empty state

pass

Logged in as `qa-empty@example.com` (created via `priv/repo/qa_seeds_448.exs` — personal account, no correlation data). Navigated to `http://localhost:4070/correlations`. The `[data-role="no-data-state"]` element was visible. Page showed "No Correlations Yet" heading and explanation text. A "Connect Integrations" link pointing to `/integrations` was present in the no-data section.

Evidence: `.code_my_spec/qa/448/screenshots/scenario4_no_data_state.png`

### Scenario 5 — Mode toggle is present

pass

Logged in as `qa@example.com` and navigated to `/correlations`. `[data-role="mode-toggle"]` was present and visible. `[data-role="mode-raw"]` had class `btn btn-primary btn-sm` (active/primary styling as expected for default state). `[data-role="mode-smart"]` had class `btn btn-ghost btn-sm` (inactive/ghost styling).

Evidence: `.code_my_spec/qa/448/screenshots/scenario5_mode_toggle.png`

### Scenario 6 — Switch to Smart mode

pass

Clicked `[data-role="mode-smart"]`. The `[data-role="smart-mode"]` div became visible. `[data-role="enable-ai-suggestions"]` button was visible. `[data-role="raw-mode"]` was not visible (`is_visible` returned false, consistent with `:if={@mode == :raw and not @summary.no_data}`).

Evidence: `.code_my_spec/qa/448/screenshots/scenario6_smart_mode.png`

### Scenario 7 — Switch back to Raw mode

pass

Clicked `[data-role="mode-raw"]` from Smart mode. `[data-role="smart-mode"]` became hidden. `[data-role="mode-raw"]` button class returned to `btn btn-primary btn-sm` (active styling restored).

Evidence: `.code_my_spec/qa/448/screenshots/scenario7_back_to_raw.png`

### Scenario 8 — Run Now button and insufficient data

pass

As `qa-empty@example.com` on the correlations page (no-data state), clicked `[data-role="run-correlations"]`. The `[data-role="insufficient-data-warning"]` badge appeared with text "Insufficient data — 30 days of metrics required". A flash error message was visible: "Not enough data to run correlations. At least 30 days of metric data is required." Both elements confirmed.

Evidence: `.code_my_spec/qa/448/screenshots/scenario8_insufficient_data.png`

### Scenario 9 — Configure Goals link

pass

On the correlations page, `[data-role="configure-goals"]` was present and visible with `href="/correlations/goals"`. Clicking the link navigated to `http://localhost:4070/correlations/goals` successfully.

Evidence: `.code_my_spec/qa/448/screenshots/scenario9_configure_goals_link.png`, `.code_my_spec/qa/448/screenshots/scenario9_goals_page.png`

## Evidence

- `.code_my_spec/qa/448/screenshots/scenario1_nav_correlations_link.png` — Dashboard with Correlations nav link visible
- `.code_my_spec/qa/448/screenshots/scenario2_correlations_page.png` — Correlations page with H1 heading and subtitle
- `.code_my_spec/qa/448/screenshots/scenario3_logout_state.png` — Login page after logout
- `.code_my_spec/qa/448/screenshots/scenario3_unauthenticated_redirect.png` — Unauthenticated access redirected to /users/log-in
- `.code_my_spec/qa/448/screenshots/scenario4_no_data_state.png` — No-data empty state for qa-empty user
- `.code_my_spec/qa/448/screenshots/scenario5_mode_toggle.png` — Mode toggle with Raw active (btn-primary)
- `.code_my_spec/qa/448/screenshots/scenario6_smart_mode.png` — Smart mode panel with Enable AI Suggestions button
- `.code_my_spec/qa/448/screenshots/scenario7_back_to_raw.png` — Returned to Raw mode (btn-primary styling restored)
- `.code_my_spec/qa/448/screenshots/scenario8_insufficient_data.png` — Flash error and insufficient-data-warning badge after Run Now
- `.code_my_spec/qa/448/screenshots/scenario9_configure_goals_link.png` — Configure Goals link visible on correlations page
- `.code_my_spec/qa/448/screenshots/scenario9_goals_page.png` — /correlations/goals page loaded after clicking link

## Issues

None
