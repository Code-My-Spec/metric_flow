# QA Result

## Status

pass

## Scenarios

### Scenario 1: Correlations page loads and defaults to Raw mode

pass

Navigated to `http://localhost:4070/correlations`. The page title "Correlations" was confirmed via the `h1` element. The mode toggle `[data-role='mode-toggle']` was present with both `[data-role='mode-raw']` and `[data-role='mode-smart']` buttons. The Raw button had class `btn btn-primary btn-sm` (active styling) and the Smart button had class `btn btn-ghost btn-sm` (inactive styling), confirming Raw is the default mode.

Evidence: `screenshots/01-correlations-raw-mode-default.png`

### Scenario 2: Switch to Smart mode — Smart mode panel appears

pass

Clicked `[data-role='mode-smart']`. The `[data-role='smart-mode']` element became visible. After switching, the Raw button class changed to `btn btn-ghost btn-sm` and the Smart button class changed to `btn btn-primary btn-sm`, confirming correct active state styling on mode switch.

Evidence: `screenshots/02-smart-mode-active.png`

### Scenario 3: Smart mode shows opt-in card before AI suggestions are enabled

pass

With Smart mode active, confirmed:
- `[data-role='smart-mode'] h2` text was "Smart Mode"
- `[data-role='enable-ai-suggestions']` button was visible
- `[data-role='ai-suggestions-enabled']` was not visible (returns false from `browser_is_visible`)

Evidence: `screenshots/03-smart-mode-opt-in-card.png`

### Scenario 4: Enable AI Suggestions and verify recommendations panel

pass

Clicked `[data-role='enable-ai-suggestions']`. The `[data-role='ai-suggestions-enabled']` badge appeared with text "AI Suggestions enabled". The `[data-role='ai-recommendations']` section became visible with "AI Recommendations" heading. The `[data-role='ai-feedback-section']` was visible with "Helpful" and "Not helpful" feedback buttons.

Evidence: `screenshots/04-ai-suggestions-enabled.png`

### Scenario 5: Check for top positive and negative correlation sections

pass

The brief's setup notes stated that `[data-role='top-positive-correlations']` and `[data-role='top-negative-correlations']` were NOT implemented. However, both elements were visible and populated. The source code at `lib/metric_flow_web/live/correlation_live/index.ex` lines 305-358 does implement these sections — the brief's assessment was outdated.

Findings:
- `[data-role='top-positive-correlations']` was visible and contained 5 `[data-role='correlation-row']` elements (activeUsers, sessions, screenPageViews x2, newUsers — all "Derived" provider, coefficient ~0.97-1.00, Strong)
- `[data-role='top-negative-correlations']` was visible and contained 1 `[data-role='correlation-row']` element (income, QuickBooks, coefficient -0.38, Weak)
- Both sections render correctly whether or not `ai_suggestions_enabled` is true (they render whenever `@mode == :smart`)

Evidence: `screenshots/05-top-correlations-sections.png`

### Scenario 6: AI feedback interaction

pass

With AI suggestions enabled, clicked `[data-role='feedback-helpful']`. The `[data-role='feedback-confirmation']` element appeared with text "Thanks for your feedback — helps improve future suggestions." The feedback buttons were replaced by the confirmation message, confirming the state transition works correctly.

Evidence: `screenshots/06-feedback-confirmation.png`

### Scenario 7: Switch back to Raw mode from Smart mode

pass

Clicked `[data-role='mode-raw']`. The `[data-role='smart-mode']` element reached state `hidden`, confirming that switching back to Raw mode hides the Smart mode panel. The Raw button styling returned to `btn-primary`.

Evidence: `screenshots/07-back-to-raw-mode.png`

### Exploratory: Configure Goals navigation

pass

Clicked the `[data-role='configure-goals']` link. Browser navigated to `http://localhost:4070/correlations/goals` and the page rendered with h1 "Goal Metric". Navigation works correctly.

Evidence: `screenshots/08-configure-goals-page.png`

## Evidence

- `screenshots/01-correlations-raw-mode-default.png` — Correlations page on initial load in Raw mode (default)
- `screenshots/02-smart-mode-active.png` — Smart mode active after clicking Smart button
- `screenshots/03-smart-mode-opt-in-card.png` — Smart mode opt-in card before AI suggestions enabled
- `screenshots/04-ai-suggestions-enabled.png` — AI suggestions enabled, recommendations panel visible
- `screenshots/05-top-correlations-sections.png` — Full-page screenshot showing top positive and negative correlation sections with data
- `screenshots/06-feedback-confirmation.png` — Feedback confirmation after clicking "Helpful"
- `screenshots/07-back-to-raw-mode.png` — Page after switching back to Raw mode
- `screenshots/08-configure-goals-page.png` — Configure Goals link leads to Goal Metric page

## Issues

### Brief incorrectly states top-positive-correlations and top-negative-correlations are not implemented

#### Severity
LOW

#### Scope
QA

#### Description
The brief's Scenario 5 setup notes state: "The current Smart mode implementation shows generic AI recommendations text and a feedback panel. It does NOT render `top-positive-correlations` or `top-negative-correlations` data-role elements with `correlation-row` children." This is incorrect. The source at `lib/metric_flow_web/live/correlation_live/index.ex` lines 305-358 clearly implements both sections. During testing, both `[data-role='top-positive-correlations']` and `[data-role='top-negative-correlations']` were visible and populated with real correlation data. The brief also incorrectly tells the tester to expect `browser_is_visible` to return false for these elements. The brief should be updated to reflect that these sections exist unconditionally whenever Smart mode is active (outside the `ai_suggestions_enabled` conditional), and the test should verify they render correctly.
