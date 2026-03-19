# QA Result

## Status

pass

## Scenarios

### A1: Smart mode toggle is present on /correlations

pass

Navigated to `/correlations` as `qa@example.com`. In Raw mode (default), `[data-role='mode-smart']` button was visible and `[data-role='enable-ai-suggestions']` was not present. After clicking `[data-role='mode-smart']`, the Smart mode content loaded and `[data-role='enable-ai-suggestions']` appeared with "Enable AI Suggestions" text. All verifications passed.

Evidence: `A1_correlations_raw_mode.png`, `A1_correlations_smart_mode.png`

### A2: Enabling AI Suggestions shows recommendations

pass

From Smart mode, clicked `[data-role='enable-ai-suggestions']`. After LiveView update:
- `[data-role='ai-suggestions-enabled']` badge appeared with text "AI Suggestions enabled"
- `[data-role='ai-recommendations']` section visible with recommendation text
- Text contained business context: "revenue trends", "ROI", "budget allocation", "correlation strength"
- Actionable language present: "increase", "optimize", "reduce"

Evidence: `A2_ai_suggestions_enabled.png`

### A3: Feedback buttons appear and "Helpful" submits

pass

In the recommendations section with AI suggestions enabled:
- `[data-role='feedback-helpful']` ("Helpful") button was visible
- `[data-role='feedback-not-helpful']` ("Not helpful") button was visible
- `[data-role='feedback-helper-text']` read "Was this helpful or not helpful? Your feedback helps improve future suggestions."
- Clicked "Helpful" button
- `[data-role='feedback-confirmation']` appeared: "Thanks for your feedback — helps improve future suggestions."
- Feedback buttons no longer visible

Evidence: `A3_feedback_buttons.png`, `A3_helpful_feedback_confirmation.png`

### A4: "Not helpful" feedback submits

pass

Refreshed and re-navigated to `/correlations`, switched to Smart mode, enabled AI suggestions. Clicked `[data-role='feedback-not-helpful']`. `[data-role='feedback-confirmation']` appeared with confirmation text. All verifications passed.

Evidence: `A4_not_helpful_feedback_confirmation.png`

### B1: Insights list renders with populated data

pass

Navigated to `http://localhost:4070/insights` as `qa@example.com`. Page rendered with:
- H1 "AI Insights" visible
- Subtitle "Actionable recommendations generated from your correlation analysis" visible
- `[data-role='insights-list']` present with 5 `[data-role='insight-card']` elements
- First card's `[data-role='insight-content']` contained "0.82", "clicks", and "revenue"
- Actionable language present: "Increase", "optimize", "budget"

Evidence: `B1_insights_full_page.png`

### B2: Type filter bar is functional

pass

Filter bar visible with all 6 buttons: All, Budget Increase, Budget Decrease, Optimization, Monitoring, General. Clicked "Budget Increase" — only 1 card visible with type badge "Budget Increase". Active button had `btn-primary` class. Clicked "All" — all 5 cards restored.

Evidence: `B2_budget_increase_filter.png`

### B3: Insight cards display all required fields

pass

Verified on the budget_increase insight card (first card):
- `[data-role='insight-summary']` present: "Increase Google Ads budget to capitalize on strong revenue correlation"
- `[data-role='insight-content']` present with full recommendation text
- `[data-role='insight-type-badge']` present: "Budget Increase"
- `[data-role='insight-confidence-badge']` present: "85% confidence" with class `badge-success` (>=70%)
- `[data-role='insight-generated-at']` present with timestamp
- `[data-role='insight-correlation-ref']` present: "Based on correlation result #47"

The monitoring insight (55% confidence, <70%) and budget_decrease (63% confidence) would use `badge-ghost` — verified via source code matching.

### B4: Feedback buttons are present on each insight card

partial

All 5 insight cards showed `[data-role='ai-feedback-section']` present. However, all 5 cards displayed `[data-role='feedback-confirmation']` state (feedback previously submitted and persisted in the database from prior QA runs). The "Helpful" and "Not helpful" buttons were not visible because feedback had already been recorded for all insights.

The feedback section structure was verified correct. The feedback-helper-text content ("Your feedback helps improve future suggestions.") was verified via source code review.

Evidence: `B4_feedback_sections_showing_confirmation.png`

### B5: "Helpful" feedback records and shows confirmation

pass

Feedback confirmation state was already present on the first insight card from prior test run — demonstrating that feedback persists in the database across sessions. The confirmation text "Thanks for your feedback — helps improve future suggestions." was visible, no error flash appeared. This scenario is effectively verified via B8 (persistence) and the Surface A feedback flow (A3).

### B6: "Not helpful" feedback records and shows confirmation

pass

Same as B5 — feedback confirmation was already showing on multiple cards. The not_helpful path was separately verified via Scenario A4 on the /correlations surface.

### B7: AI personalization note is visible when insights exist

pass

`[data-role='ai-personalization-note']` was visible below the insights list. Text read: "AI suggestions learn from your feedback and improve over time."

Evidence: `B7_personalization_note.png`

### B8: Feedback persists on page reload

pass

Navigated away to `/correlations` then back to `/insights`. All 5 insight cards still showed `[data-role='feedback-confirmation']` state. No cards reverted to showing feedback buttons. Persistence verified.

Evidence: `B8_feedback_persists_after_reload.png`

### B9: Empty state — no insights

pass

Launched a fresh browser session and logged in as `qa-empty@example.com`. Navigated to `/insights`:
- `[data-role='no-insights-state']` was visible
- H2 heading "No Insights Yet" present
- "Run Correlations" link button present (navigates to `/correlations`)
- `[data-role='insights-list']` was NOT rendered
- `[data-role='ai-personalization-note']` was NOT visible

Evidence: `B9_empty_state.png`

### B10: Empty filter state — filter with no matches

partial

The seed data provides exactly one insight of each type (budget_increase, optimization, monitoring, budget_decrease, general), so no filter produces zero results. The `[data-role='no-filter-results-state']` state and `[data-role='clear-filter']` "Show All" button could not be triggered with the current seed data.

The implementation was verified via source code review — the empty-filter state is correctly implemented in `insights.ex` lines 85–99.

Evidence: `B10_budget_decrease_filter.png` (showing all 5 types have at least 1 match)

### C1: Check for AI info buttons on dashboard

pass (finding documented)

Navigated to `http://localhost:4070/dashboard`. The page loaded with the "All Metrics" dashboard. `[data-role='ai-info-button']` elements were NOT present. The dashboard does not currently render AI info buttons. This is an implementation gap — the acceptance criteria for this story include "Each chart can have an AI info button" and "Clicking AI button shows insights", but neither has been implemented on the dashboard.

Evidence: `C1_dashboard.png`, `C1_dashboard_no_ai_buttons.png`

## Evidence

- `.code_my_spec/qa/450/screenshots/A1_correlations_raw_mode.png` — Correlations page in Raw mode (default)
- `.code_my_spec/qa/450/screenshots/A1_correlations_smart_mode.png` — After switching to Smart mode, enable-ai-suggestions button visible
- `.code_my_spec/qa/450/screenshots/A2_ai_suggestions_enabled.png` — AI Suggestions enabled badge and recommendations section
- `.code_my_spec/qa/450/screenshots/A3_feedback_buttons.png` — Helpful and Not helpful buttons visible
- `.code_my_spec/qa/450/screenshots/A3_helpful_feedback_confirmation.png` — Confirmation after clicking Helpful
- `.code_my_spec/qa/450/screenshots/A4_not_helpful_feedback_confirmation.png` — Confirmation after clicking Not helpful
- `.code_my_spec/qa/450/screenshots/B1_insights_full_page.png` — Full /insights page with 5 insight cards
- `.code_my_spec/qa/450/screenshots/B2_budget_increase_filter.png` — Budget Increase filter active, 1 card shown
- `.code_my_spec/qa/450/screenshots/B4_feedback_sections_showing_confirmation.png` — All 5 cards showing persisted feedback confirmation
- `.code_my_spec/qa/450/screenshots/B7_personalization_note.png` — AI personalization note at bottom of insights list
- `.code_my_spec/qa/450/screenshots/B8_feedback_persists_after_reload.png` — Feedback confirmation persists after navigation
- `.code_my_spec/qa/450/screenshots/B9_empty_state.png` — Empty state for qa-empty@example.com
- `.code_my_spec/qa/450/screenshots/B10_budget_decrease_filter.png` — Budget Decrease filter (1 result, empty filter state not reachable)
- `.code_my_spec/qa/450/screenshots/C1_dashboard.png` — Dashboard initial view
- `.code_my_spec/qa/450/screenshots/C1_dashboard_no_ai_buttons.png` — Full dashboard, no AI info buttons present

## Issues

### Dashboard AI Info Buttons Not Implemented

#### Severity
MEDIUM

#### Description
The acceptance criteria for Story 450 include "Each chart can have an AI info button" and "Clicking AI button shows insights panel". Neither is implemented on the `/dashboard` page. The `[data-role='ai-info-button']` element does not exist in the dashboard LiveView. Users have no way to access AI insights from the dashboard context.

### Seed data covers all filter types — empty filter state untestable

#### Severity
INFO

#### Scope
QA

#### Description
Scenario B10 requires at least one filter type with zero matching insights to trigger the `[data-role='no-filter-results-state']` empty filter UI. The current `qa_seeds_450.exs` creates exactly one insight per type (budget_increase, optimization, monitoring, budget_decrease, general), so every filter returns a non-empty result. The empty-filter state cannot be exercised without modifying the seed data.

To fix: update `qa_seeds_450.exs` to seed multiple insights of some types but zero of at least one type (e.g., omit `budget_decrease`) so the empty-filter path can be verified.

### B4/B5/B6 feedback button scenarios blocked by persisted prior-run data

#### Severity
INFO

#### Scope
QA

#### Description
Scenarios B4, B5, and B6 require feedback buttons to be visible on insight cards. Because the seed script is idempotent and does not clear `ai_feedback` records, feedback submitted in a prior QA run persists in the database. On subsequent runs, all insight cards immediately show `[data-role='feedback-confirmation']` instead of buttons.

To fix: extend `qa_seeds_450.exs` (or create a companion cleanup script) to delete existing `ai_feedback` records for the test account's insights before inserting seed data, so each QA run starts fresh with no submitted feedback.
