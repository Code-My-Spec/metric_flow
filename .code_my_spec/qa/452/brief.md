# QA Story Brief

Story 452: LLM-Generated Custom Reports — `MetricFlowWeb.AiLive.ReportGenerator`

## Tool

web (vibium MCP browser tools)

## Auth

Log in via the password form using vibium MCP tool calls:

```
mcp__vibium__browser_launch(headless: true)
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait_for_url(pattern: "/", timeout: 5000)
mcp__vibium__browser_get_url()   # verify — should be http://localhost:4070/
```

## Seeds

No story-specific seeds required. The base QA seeds provide the authenticated user. Verify seeds are in place by confirming login succeeds. If login fails, run:

```bash
mix run priv/repo/qa_seeds.exs
```

Credentials:
- Owner: `qa@example.com` / `hello world!`

## What To Test

### Scenario 1: Unauthenticated access redirects to login

- Visit `http://localhost:4070/reports/generate` without logging in (use a fresh browser or clear cookies first)
- Expected: redirected to `/users/log-in`

### Scenario 2: Page renders with correct initial state

- Navigate to `http://localhost:4070/reports/generate` while authenticated
- Expected: page title "Generate Report" appears in an H1
- Expected: subtitle "Describe the chart or report you want and AI will build it for you." is visible
- Expected: `[data-role="prompt-form"]` card is present
- Expected: textarea `[data-role="prompt-input"]` is visible and editable
- Expected: "Generate Chart" button (`[data-role="generate-btn"]`) is present and disabled (prompt is blank)
- Expected: `[data-role="empty-state"]` paragraph "Enter a prompt above and click Generate Chart to get started." is visible
- Expected: chart preview section (`[data-role="chart-preview-section"]`) is NOT present
- Expected: save section (`[data-role="save-section"]`) is NOT present
- Capture screenshot: `s1_initial_state.png`

### Scenario 3: Typing a prompt enables the Generate Chart button

- On `http://localhost:4070/reports/generate`, fill the textarea `[data-role="prompt-input"]` with text: "Show me a bar chart of monthly revenue for the past 6 months"
- Expected: the Generate Chart button (`[data-role="generate-btn"]`) becomes enabled (loses `btn-disabled` class / `disabled` attribute)
- Expected: the empty state remains visible (no chart yet)
- Capture screenshot: `s2_prompt_filled.png`

### Scenario 4: Submitting a prompt triggers LLM generation and shows chart preview

- On `http://localhost:4070/reports/generate`, fill the textarea with a prompt (e.g. "Show me a bar chart of monthly revenue for the past 6 months")
- Submit the form by clicking `[data-role="generate-btn"]`
- While generating: verify the button is disabled and shows "Generating…" spinner text
- Wait for the response to complete (wait for `[data-role="chart-preview-section"]` to appear, or for `[data-role="generate-error"]` to appear if generation fails)
- On success:
  - Expected: `[data-role="chart-preview-section"]` is visible with "Chart Preview" label and "AI-generated — review before saving" note
  - Expected: `[data-role="vega-lite-chart"]` element is present with a non-empty `data-spec` attribute
  - Expected: `[data-role="save-section"]` is visible
  - Expected: `[data-role="empty-state"]` is NOT present
  - Capture screenshot: `s3_chart_generated.png`
- On LLM error (if AI is unavailable or returns error):
  - Expected: `[data-role="generate-error"]` is visible with an error message
  - Expected: `[data-role="chart-preview-section"]` is NOT present
  - Capture screenshot: `s3_generate_error.png`
  - Note this as an issue if the error message is unclear or missing

### Scenario 5: Save section — validation prevents save with blank name

- After a chart has been generated (chart preview visible), verify the save section is shown
- Do not fill the save name input (`[data-role="save-name-input"]`)
- Click the "Save Visualization" button (`[data-role="save-visualization-btn"]`)
- Expected: button is disabled when save name is blank (should not be clickable)
- Try clicking anyway — expected: `[data-role="save-error"]` appears with "Name is required." message
- Capture screenshot: `s4_save_validation_blank_name.png`

### Scenario 6: Save section — saving with a valid name produces confirmation

- After a chart has been generated, fill `[data-role="save-name-input"]` with "QA Test Report"
- Expected: "Save Visualization" button becomes enabled
- Click `[data-role="save-visualization-btn"]`
- Expected: `[data-role="save-confirmation"]` appears with "Visualization saved!" text (badge + text)
- Expected: a "View in Visualizations" link pointing to `/visualizations` is visible
- Expected: a "Generate Another" button is present
- Expected: save section (`[data-role="save-section"]`) is no longer visible
- Capture screenshot: `s5_save_confirmation.png`

### Scenario 7: "Generate Another" resets state

- From the save confirmation state, click the "Generate Another" button
- Expected: URL remains `http://localhost:4070/reports/generate` (push_patch, no full reload)
- Expected: page returns to initial state: prompt textarea is empty, empty state visible, no chart preview, no save section
- Capture screenshot: `s6_generate_another_reset.png`

### Scenario 8: "View in Visualizations" link works

- From the save confirmation state (after saving), click "View in Visualizations"
- Expected: navigates to `/visualizations` without error
- Capture screenshot: `s7_visualizations_page.png`

## Setup Notes

The `generate` event calls `MetricFlow.Ai.generate_vega_spec/3`, which calls `MetricFlow.Ai.ReportGenerator.generate/3` and then validates the returned Vega-Lite spec. The LLM call goes to an external API. In a live QA run this will make a real LLM request unless the server is configured with a stub.

If the LLM API key is not configured or the API is unavailable, the generate step will return an error. Test the error path (Scenario 4 error branch) in that case and note the error message shown. The main UI flow (all other scenarios) can still be validated by confirming the page structure and disabled-state behavior.

The `generate` event handler runs synchronously in the LiveView process (not async), so the browser will appear to hang while the LLM responds. Wait up to 30 seconds for `[data-role="chart-preview-section"]` to appear before concluding the LLM call failed.

The save flow calls `MetricFlow.Dashboards.save_visualization/2`. This requires the `current_scope` to have an active account. The base QA seeds create "QA Test Account" with `qa@example.com` as owner — this is sufficient.

## Result Path

`.code_my_spec/qa/452/result.md`
