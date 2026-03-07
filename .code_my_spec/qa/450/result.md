# QA Result

## Status

partial

## Scenarios

### A1: Smart mode toggle is present

pass

Navigated to `/correlations` as `qa@example.com`. In Raw mode (default), `[data-role='mode-smart']` was visible and `[data-role='enable-ai-suggestions']` was not present. After clicking `[data-role='mode-smart']`, the Smart mode panel appeared and `[data-role='enable-ai-suggestions']` became visible.

Evidence: `screenshots/A1_correlations_raw_mode.png`, `screenshots/A1_correlations_smart_mode.png`

### A2: Enabling AI Suggestions shows recommendations

pass

Clicked `[data-role='enable-ai-suggestions']` in Smart mode. The `[data-role='ai-suggestions-enabled']` badge appeared with text "AI Suggestions enabled". The `[data-role='ai-recommendations']` section rendered with text containing "revenue", "ROI", "budget", "spend", "correlation strength", "increase", "optimize", and "reduce" — all required business context terms and actionable language.

Evidence: `screenshots/A2_ai_suggestions_enabled.png`

### A3: Feedback buttons appear and "Helpful" submits

pass

With AI suggestions enabled on `/correlations`:
- `[data-role='feedback-helpful']` ("Helpful") was visible
- `[data-role='feedback-not-helpful']` ("Not helpful") was visible
- `[data-role='feedback-helper-text']` read "Was this helpful or not helpful? Your feedback helps improve future suggestions."

Clicked "Helpful". `[data-role='feedback-confirmation']` appeared with "Thanks for your feedback — helps improve future suggestions." and the feedback buttons disappeared.

Evidence: `screenshots/A3_feedback_buttons.png`, `screenshots/A3_feedback_helpful_confirmed.png`

### A4: "Not helpful" feedback submits

pass

Refreshed and navigated back to `/correlations`, switched to Smart mode, enabled AI suggestions, then clicked `[data-role='feedback-not-helpful']`. `[data-role='feedback-confirmation']` appeared correctly.

Evidence: `screenshots/A4_feedback_not_helpful_confirmed.png`

### B1: Insights list renders with populated data

pass

Navigated to `/insights` as `qa@example.com`. Page showed:
- H1 "AI Insights"
- Subtitle "Actionable recommendations generated from your correlation analysis"
- `[data-role='insights-list']` with 5 `[data-role='insight-card']` elements

First card's `[data-role='insight-content']` included "0.82", "clicks", and "revenue". Actionable language ("increasing", "budget") was present.

Evidence: `screenshots/B1_insights_page_initial.png`

### B2: Type filter bar is functional

pass

`[data-role='type-filter']` was visible with buttons: All, Budget Increase, Budget Decrease, Optimization, Monitoring, General. Clicking "Budget Increase" reduced displayed cards to 1 (with "Budget Increase" type badge). The active button had `btn btn-primary btn-sm` class. Clicking "All" restored all 5 cards.

Evidence: `screenshots/B2_budget_increase_filter.png`

### B3: Insight cards display all required fields

pass

First insight card (budget_increase type) had:
- `[data-role='insight-summary']` — "Increase Google Ads budget to capitalize on strong revenue correlation"
- `[data-role='insight-content']` — full recommendation text with "0.82" coefficient and metric names
- `[data-role='insight-type-badge']` — "Budget Increase"
- `[data-role='insight-confidence-badge']` — "85% confidence" with `badge-success` class (>=70%)
- `[data-role='insight-generated-at']` — timestamp rendered
- `[data-role='insight-correlation-ref']` — "Based on correlation result #5"

The monitoring insight (confidence 0.55) was verified to use `badge-ghost` class.

### B4: Feedback buttons are present on each insight card

pass

Each insight card had `[data-role='ai-feedback-section']`. Cards without prior feedback showed `[data-role='feedback-helpful']`, `[data-role='feedback-not-helpful']`, and `[data-role='feedback-helper-text']` ("Your feedback helps improve future suggestions."). Cards with prior feedback (from a previous seed run) showed `[data-role='feedback-confirmation']`.

Evidence: `screenshots/B4_feedback_section.png`

### B5: "Helpful" feedback records and shows confirmation

pass

Clicked `[data-role='feedback-helpful']` on the third insight card. `[data-role='feedback-confirmation']` appeared with "Thanks for your feedback — helps improve future suggestions." The feedback buttons disappeared. No error flash was shown.

Evidence: `screenshots/B5_feedback_helpful_submitted.png`

### B6: "Not helpful" feedback records and shows confirmation

pass

Clicked `[data-role='feedback-not-helpful']` on the fourth insight card. `[data-role='feedback-confirmation']` appeared correctly.

Evidence: `screenshots/B6_feedback_not_helpful_submitted.png`

### B7: AI personalization note is visible when insights exist

pass

`[data-role='ai-personalization-note']` was visible below the insights list with text "AI suggestions learn from your feedback and improve over time."

Evidence: `screenshots/B7_personalization_note.png`

### B8: Feedback persists on page reload

pass

After submitting "Helpful" on card 3 (B5), navigated away and returned to `/insights`. Card 3 still showed `[data-role='feedback-confirmation']`. Card 5 (no feedback given) still showed the Helpful/Not helpful buttons.

Evidence: `screenshots/B8_feedback_persistence_reload.png`

### B9: Empty state — no insights (qa-member@example.com)

fail

Logged in as `qa-member@example.com` and navigated to `/insights`. Expected to see `[data-role='no-insights-state']` with "No Insights Yet", but instead the full 5-insight list was rendered.

Root cause: `qa-member@example.com` shares account ID 2 ("QA Test Account") with `qa@example.com` — `Accounts.get_personal_account_id/1` returns the first account membership for the member, which is account 2. The insights seeded for account 2 are visible to all members of that account (correct account-level isolation behavior). The brief's claim that "qa-member@example.com has no insights" is incorrect for the current seed state.

The empty state (`[data-role='no-insights-state']`) was not testable with the current seed setup. The implementation appears correct based on code review — the empty state renders when `@insights == []`.

Evidence: `screenshots/B9_member_empty_state.png`

### B10: Empty filter state — filter with no matches

not tested

All 5 filter types (budget_increase, optimization, monitoring, budget_decrease, general) each have exactly one insight in the seed data. No filter type produces zero results, so the `[data-role='no-filter-results-state']` state could not be triggered. The implementation appears correct based on code review (rendered when `@insights != [] and @filtered_insights == []`).

### C1: AI info buttons on dashboard visualizations

pass

Navigated to `/dashboard`. 8 `[data-role='ai-info-button']` elements were present (one per chart). Clicked the "AI Info" button on the Clicks chart. An `[data-role='ai-insights-panel']` appeared with heading "AI Insights: Clicks" and context-specific text including a link to `/insights`. The panel included a close button (`[data-role='close-button']`).

Evidence: `screenshots/C1_dashboard.png`, `screenshots/C1_ai_info_button_clicked.png`, `screenshots/C1_ai_insights_panel.png`

## Evidence

- `screenshots/A1_correlations_raw_mode.png` — correlations page in default Raw mode
- `screenshots/A1_correlations_smart_mode.png` — after switching to Smart mode, Enable AI Suggestions button visible
- `screenshots/A2_ai_suggestions_enabled.png` — AI Suggestions enabled badge and recommendations section
- `screenshots/A3_feedback_buttons.png` — Helpful/Not helpful buttons and helper text visible
- `screenshots/A3_feedback_helpful_confirmed.png` — feedback confirmation after clicking Helpful
- `screenshots/A4_feedback_not_helpful_confirmed.png` — feedback confirmation after clicking Not helpful
- `screenshots/B1_insights_page_initial.png` — /insights page with all 5 insight cards
- `screenshots/B2_budget_increase_filter.png` — after filtering to Budget Increase type, 1 card shown
- `screenshots/B4_feedback_section.png` — feedback section on an insight card
- `screenshots/B5_feedback_helpful_submitted.png` — feedback confirmation after Helpful click
- `screenshots/B6_feedback_not_helpful_submitted.png` — feedback confirmation after Not helpful click
- `screenshots/B7_personalization_note.png` — AI personalization note below insights list
- `screenshots/B8_feedback_persistence_reload.png` — feedback state persists after page reload
- `screenshots/B9_member_empty_state.png` — qa-member@example.com sees full insight list (not empty state)
- `screenshots/C1_dashboard.png` — dashboard with AI Info buttons on each chart
- `screenshots/C1_ai_info_button_clicked.png` — after clicking AI Info button on Clicks chart
- `screenshots/C1_ai_insights_panel.png` — AI insights panel rendered with metric-specific context

## Issues

### B9 empty-state scenario is not testable with current seeds — both QA users share account 2

#### Severity
MEDIUM

#### Scope
QA

#### Description
The brief states that `qa-member@example.com` should have no insights and be suitable for testing the empty state on `/insights`. In practice, `Accounts.get_personal_account_id/1` returns account 2 ("QA Test Account") for both `qa@example.com` and `qa-member@example.com` because both are members of the same account. Insights are scoped at the account level, so both users see the same 5 insights.

To test the empty state, the seed strategy needs either: (a) a third user who is not a member of account 2 and whose first account has no insights, or (b) a dedicated empty-insights account seeded separately. The `qa_seeds_450.exs` script should be updated to create a new user/account pair with no insights, or `qa_seeds.exs` should ensure `qa-member@example.com` has a separate personal account.

### B10 empty filter state cannot be triggered with seed data — all 5 filter types are populated

#### Severity
LOW

#### Scope
QA

#### Description
The seed script creates exactly one insight per suggestion type (budget_increase, optimization, monitoring, budget_decrease, general), meaning all 5 filter buttons match at least one insight. The `[data-role='no-filter-results-state']` element can never be reached with the current seed data.

To enable testing of B10, `qa_seeds_450.exs` should be updated to leave at least one suggestion type with no insights (e.g., omit the `general` type) so the corresponding filter button returns zero results. Alternatively, the brief should note that B10 cannot be tested with 5-type coverage and should acknowledge this as an intentional trade-off.
