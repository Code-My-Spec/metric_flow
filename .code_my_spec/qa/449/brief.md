# QA Story Brief

Story 449 — View Correlation Analysis Results (Smart/AI Mode)

## Tool

web (vibium MCP browser tools)

## Auth

Log in as the QA owner user using the vibium browser tools:

```
mcp__vibium__browser_launch(headless: true)
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait_for_url(pattern: "/", timeout: 5000)
mcp__vibium__browser_get_url()  # verify — should be http://localhost:4070/
```

Credentials: `qa@example.com` / `hello world!`

## Seeds

The base seeds provide the QA user and team account. No story-specific seed data is required — the correlations page handles the no-data state gracefully.

Verify seeds are in place by confirming successful login above. If login fails, run:

```bash
cd /Users/johndavenport/Documents/github/metric_flow
mix run priv/repo/qa_seeds.exs
```

## What To Test

### Scenario 1: Correlations page loads and defaults to Raw mode

- Navigate to `http://localhost:4070/correlations`
- Verify the page title "Correlations" is visible
- Verify the mode toggle is present: `[data-role='mode-toggle']` with two buttons `[data-role='mode-raw']` and `[data-role='mode-smart']`
- Verify the Raw button has `.btn-primary` styling (default active mode)
- Verify the Smart button has `.btn-ghost` styling (inactive)
- Take a screenshot

### Scenario 2: Switch to Smart mode — Smart mode panel appears

- Click the "Smart" button: `[data-role='mode-smart']`
- Wait for `[data-role='smart-mode']` to be visible
- Verify Smart mode panel is rendered
- Verify the Raw button now has `.btn-ghost` styling
- Verify the Smart button now has `.btn-primary` styling
- Take a screenshot

### Scenario 3: Smart mode shows opt-in card before AI suggestions are enabled

- With Smart mode active (from Scenario 2), verify:
  - "Smart Mode" heading is visible within `[data-role='smart-mode']`
  - The "Enable AI Suggestions" button (`[data-role='enable-ai-suggestions']`) is visible
  - No `[data-role='ai-suggestions-enabled']` badge is present yet
- Take a screenshot

### Scenario 4: Enable AI Suggestions and verify recommendations panel

- Click "Enable AI Suggestions": `[data-role='enable-ai-suggestions']`
- Wait for `[data-role='ai-suggestions-enabled']` to appear
- Verify `[data-role='ai-recommendations']` section is visible
- Verify "AI Recommendations" heading is present
- Verify `[data-role='ai-feedback-section']` is visible with feedback buttons
- Take a screenshot

### Scenario 5: Check for top positive and negative correlation sections (BDD spec assertion)

The BDD spec (criterion 4125) asserts that Smart mode shows:
- A section with `[data-role='top-positive-correlations']` containing `[data-role='correlation-row']` elements (at most 5)
- A section with `[data-role='top-negative-correlations']` containing `[data-role='correlation-row']` elements (at most 5)

With AI suggestions enabled, check whether these elements exist in the DOM:

- Call `mcp__vibium__browser_get_html()` and search the HTML for `top-positive-correlations` and `top-negative-correlations`
- Call `mcp__vibium__browser_is_visible(selector: "[data-role='top-positive-correlations']")` — expected false based on source review
- Call `mcp__vibium__browser_is_visible(selector: "[data-role='top-negative-correlations']")` — expected false based on source review
- Note: The current Smart mode implementation shows generic AI recommendations text and a feedback panel. It does NOT render `top-positive-correlations` or `top-negative-correlations` data-role elements with `correlation-row` children.
- Take a full-page screenshot as evidence

### Scenario 6: AI feedback interaction

- With AI suggestions enabled, click the "Helpful" button (`[data-role='feedback-helpful']`)
- Verify the feedback section transitions to `[data-role='feedback-confirmation']`
- Verify confirmation text "Thanks for your feedback" is visible
- Take a screenshot

### Scenario 7: Switch back to Raw mode from Smart mode

- Click the "Raw" button: `[data-role='mode-raw']`
- Verify `[data-role='smart-mode']` is no longer visible (or Raw mode content is shown)
- Take a screenshot

## Setup Notes

The BDD spec (criterion 4125) expects `[data-role='top-positive-correlations']` and `[data-role='top-negative-correlations']` sections within Smart mode, each containing `[data-role='correlation-row']` children limited to 5. Reading the source at `lib/metric_flow_web/live/correlation_live/index.ex`, the Smart mode template does NOT implement these data-role attributes. The Smart mode shows a generic AI recommendations card and a feedback panel but does not segment correlations into positive/negative subsections.

This gap between the BDD spec and the implementation is expected to surface as a failing scenario. Report it as an `app` scope issue if the elements are missing.

The page loads the no-data empty state when no correlation summary exists — this is expected for a fresh QA account. Smart mode is accessible regardless of whether correlation data exists (the mode toggle renders outside the `[data-role='correlation-results']` conditional block).

## Result Path

`.code_my_spec/qa/449/result.md`
