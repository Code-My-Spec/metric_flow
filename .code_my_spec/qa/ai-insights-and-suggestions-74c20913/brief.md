# QA Story Brief — 450: AI Insights and Suggestions

## Tool

web (MCP browser tools — vibium)

## Auth

Launch a headless browser and log in with the password form:

```
mcp__vibium__browser_launch(headless: true)
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll_into_view(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait(selector: "body", timeout: 5000)
```

To test the empty-insights state, clear cookies and re-login as the empty user (no team account, no data):

```
mcp__vibium__browser_delete_cookies()
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll_into_view(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa-empty@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait(selector: "body", timeout: 5000)
```

## Seeds

Run in order — each depends on the previous:

```bash
mix run priv/repo/qa_seeds.exs
mix run priv/repo/qa_seeds_447.exs
mix run priv/repo/qa_seeds_450.exs
```

These must be run with `dangerouslyDisableSandbox: true` because the CloudflareTunnel
supervisor writes to `~/.cloudflared/config.yml` on application startup.

After running, the `qa@example.com` account has:
- 5 AI insights covering all suggestion types: budget_increase, optimization, monitoring,
  budget_decrease, general
- One insight (budget_increase) linked to a CorrelationResult (clicks -> revenue, coefficient 0.82)
- `qa-empty@example.com` has no team account and no insights (use for empty-state testing)

## What To Test

This story has two UI surfaces: `/correlations` (Smart mode toggle) and `/insights` (dedicated
insights page). Test both.

---

### Surface A: /correlations Smart Mode

#### Scenario A1: Smart mode toggle is present (AC: Enable AI Suggestions option in Smart mode)

1. Log in as `qa@example.com`
2. Navigate to `http://localhost:4070/correlations`
3. Screenshot the page in default (Raw) mode
4. Verify: `[data-role='mode-smart']` button is present
5. Verify: `[data-role='enable-ai-suggestions']` is NOT present in Raw mode
6. Click `[data-role='mode-smart']`
7. Wait for LiveView update
8. Screenshot after switching to Smart mode
9. Verify: `[data-role='enable-ai-suggestions']` ("Enable AI Suggestions") button is now visible

#### Scenario A2: Enabling AI Suggestions shows recommendations (AC: AI analyzes correlation data, AI suggestions based on correlation strength)

1. While in Smart mode on `/correlations` (from A1)
2. Click `[data-role='enable-ai-suggestions']`
3. Wait for LiveView update
4. Screenshot the recommendations section
5. Verify: `[data-role='ai-suggestions-enabled']` badge is visible with text "AI Suggestions enabled"
6. Verify: `[data-role='ai-recommendations']` section is visible
7. Verify: the recommendations text contains business context terms such as "revenue", "ROI", "budget", "spend", or "correlation strength"
8. Verify: actionable language is present such as "increase", "optimize", "reduce", or "consider"

#### Scenario A3: Feedback buttons appear and "Helpful" submits (AC: User can provide feedback, AI learns from feedback)

1. Still on `/correlations` with AI suggestions enabled
2. Verify: `[data-role='feedback-helpful']` ("Helpful") button is visible
3. Verify: `[data-role='feedback-not-helpful']` ("Not helpful") button is visible
4. Verify: `[data-role='feedback-helper-text']` mentions that feedback helps improve suggestions
5. Screenshot showing both buttons
6. Click `[data-role='feedback-helpful']`
7. Wait for LiveView update
8. Screenshot after submitting
9. Verify: `[data-role='feedback-confirmation']` appears with "Thanks for your feedback — helps improve future suggestions."
10. Verify: feedback buttons are no longer shown

#### Scenario A4: "Not helpful" feedback submits (AC: User can provide feedback)

1. Refresh the page, navigate back to `/correlations`, switch to Smart mode, enable AI suggestions
2. Click `[data-role='feedback-not-helpful']`
3. Wait for LiveView update
4. Screenshot after submitting
5. Verify: `[data-role='feedback-confirmation']` appears

---

### Surface B: /insights LiveView

#### Scenario B1: Insights list renders with populated data (AC: AI analyzes correlation data, AI suggestions based on correlation strength)

1. Log in as `qa@example.com`
2. Navigate to `http://localhost:4070/insights`
3. Take a full-page screenshot
4. Verify: page heading "AI Insights" is visible
5. Verify: subtitle "Actionable recommendations generated from your correlation analysis" is visible
6. Verify: `[data-role='insights-list']` is present and contains multiple `[data-role='insight-card']` elements
7. Verify: at least one card's `[data-role='insight-content']` references a correlation coefficient (e.g., "0.82") and a metric name (e.g., "clicks", "revenue")
8. Verify: at least one card contains actionable language (e.g., "Increase", "optimize", "budget")

#### Scenario B2: Type filter bar is functional (AC: AI suggestions based on correlation strength, trends, and business context)

1. On `/insights` as `qa@example.com`
2. Verify: `[data-role='type-filter']` filter bar is visible with buttons: All, Budget Increase, Budget Decrease, Optimization, Monitoring, General
3. Click "Budget Increase"
4. Screenshot after filtering
5. Verify: only Budget Increase type cards are visible (badge shows "Budget Increase")
6. Verify: the active "Budget Increase" button appears highlighted (btn-primary class)
7. Click "All"
8. Verify: all 5 insight cards are visible again

#### Scenario B3: Insight cards display all required fields (AC: AI analyzes correlation data)

1. On `/insights` as `qa@example.com`
2. For at least one visible insight card, verify presence of:
   - `[data-role='insight-summary']` — short summary text
   - `[data-role='insight-content']` — full recommendation text
   - `[data-role='insight-type-badge']` — type label (e.g., "Budget Increase")
   - `[data-role='insight-confidence-badge']` — confidence percentage (e.g., "85% confidence")
   - `[data-role='insight-generated-at']` — generated timestamp
3. Verify: the budget_increase insight shows `[data-role='insight-correlation-ref']` referencing a correlation result ID
4. Verify: confidence badges >=70% use `badge-success` class; lower confidence use `badge-ghost`

#### Scenario B4: Feedback buttons are present on each insight card (AC: User can provide feedback)

1. On `/insights` as `qa@example.com`
2. Verify: each insight card has `[data-role='ai-feedback-section']`
3. Verify: `[data-role='feedback-helpful']` ("Helpful") and `[data-role='feedback-not-helpful']` ("Not helpful") buttons are visible inside each section
4. Verify: `[data-role='feedback-helper-text']` reads "Your feedback helps improve future suggestions."
5. Screenshot the feedback section on one card

#### Scenario B5: "Helpful" feedback records and shows confirmation (AC: User can provide feedback)

1. On `/insights` as `qa@example.com`
2. Click `[data-role='feedback-helpful']` on the first insight card
3. Wait for LiveView update
4. Screenshot after clicking
5. Verify: `[data-role='feedback-confirmation']` replaces the buttons
6. Verify: confirmation text reads "Thanks for your feedback — helps improve future suggestions."
7. Verify: no error flash message appears

#### Scenario B6: "Not helpful" feedback records and shows confirmation (AC: User can provide feedback)

1. On `/insights` as `qa@example.com`
2. Click `[data-role='feedback-not-helpful']` on a different insight card (one not yet rated)
3. Wait for LiveView update
4. Screenshot after clicking
5. Verify: `[data-role='feedback-confirmation']` replaces the buttons with the confirmation text

#### Scenario B7: AI personalization note is visible when insights exist (AC: AI learns from feedback)

1. On `/insights` as `qa@example.com` with insights loaded
2. Verify: `[data-role='ai-personalization-note']` is visible below the insights list
3. Verify: text reads "AI suggestions learn from your feedback and improve over time."
4. Screenshot the personalization note

#### Scenario B8: Feedback persists on page reload (AC: AI learns from feedback)

1. After clicking "Helpful" in Scenario B5, navigate away from `/insights`
2. Return to `http://localhost:4070/insights`
3. Take a screenshot
4. Verify: the insight that received feedback still shows `[data-role='feedback-confirmation']` (not the Helpful/Not helpful buttons)
5. Verify: other insights still show their feedback buttons

#### Scenario B9: Empty state — no insights (AC: AI analyzes correlation data)

1. Clear cookies and log in as `qa-empty@example.com`
2. Navigate to `http://localhost:4070/insights`
3. Take a screenshot
4. Verify: `[data-role='no-insights-state']` is visible with heading "No Insights Yet"
5. Verify: a "Run Correlations" link button is present
6. Verify: `[data-role='insights-list']` is NOT rendered
7. Verify: `[data-role='ai-personalization-note']` is NOT visible

#### Scenario B10: Empty filter state — filter with no matches

1. Log back in as `qa@example.com`, navigate to `/insights`
2. If any filter type maps to zero results in the seed data, click it
3. Verify: `[data-role='no-filter-results-state']` appears with "No insights match the selected filter."
4. Verify: `[data-role='clear-filter']` "Show All" ghost button is present
5. Click "Show All"
6. Verify: all insights are shown again

---

### Surface C: /dashboard AI Info Button (AC: Each chart can have an AI info button, Clicking AI button shows insights)

#### Scenario C1: Check for AI info buttons on dashboard visualizations

1. Log in as `qa@example.com`
2. Navigate to `http://localhost:4070/dashboard`
3. Take a screenshot
4. Check whether `[data-role='ai-info-button']` elements are present near chart or visualization containers
5. If present: click one, screenshot the result, verify an insights panel or link to `/insights` appears
6. If not present: document that the dashboard does not currently render AI info buttons (this is a potential implementation gap)

## Setup Notes

The `/correlations` Smart mode surface (Surface A) is what the BDD spex files test. The
`/insights` page (Surface B) is the dedicated standalone implementation that renders full
per-insight cards with feedback. Both surfaces are in scope for this story.

Feedback state is tracked per-insight in the database. On page reload the LiveView re-hydrates
feedback state via `Ai.get_feedback_for_insight/2`, so submitted feedback persists across reloads.

The dashboard AI info button (Surface C, AC3/AC4) may not yet be implemented — check and report
the finding either way.

## Result Path

`.code_my_spec/qa/450/result.md`
