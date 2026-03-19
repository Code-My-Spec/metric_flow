# QA Result

Story 452: LLM-Generated Custom Reports

## Status

complete

## Scenarios

### Scenario 1: Unauthenticated access redirects to login

pass

Navigated to `http://localhost:4070/reports/generate` without an authenticated session. The browser redirected to `http://localhost:4070/users/log-in` immediately. After logging in, the browser redirected back to `/reports/generate`, confirming the return-to path is preserved.

### Scenario 2: Page renders with correct initial state

pass

After authenticating as `qa@example.com`, navigated to `http://localhost:4070/reports/generate`. Confirmed:
- H1 "Generate Report" visible
- Subtitle "Describe the chart or report you want and AI will build it for you." visible
- `[data-role="prompt-form"]` card present
- `[data-role="prompt-input"]` textarea visible and editable
- `[data-role="generate-btn"]` present and disabled (prompt is blank)
- `[data-role="empty-state"]` paragraph visible
- `[data-role="chart-preview-section"]` not present
- `[data-role="save-section"]` not present

Screenshot: `.code_my_spec/qa/452/screenshots/s1_initial_state.png`

### Scenario 3: Typing a prompt enables the Generate Chart button

pass

Typed "Show me a bar chart of monthly revenue for the past 6 months" into `[data-role="prompt-input"]`. The `[data-role="generate-btn"]` transitioned from disabled (grayed out) to enabled (primary/purple color). The `[data-role="empty-state"]` remained visible, confirming no premature chart rendering.

Note: `browser_fill` failed on the textarea — `browser_type` was used instead. The textarea accepts typed input normally via `phx-change="update_prompt"`.

Screenshot: `.code_my_spec/qa/452/screenshots/s2_prompt_filled.png`

### Scenario 4: Submitting a prompt triggers LLM generation and shows chart preview

pass

Clicked `[data-role="generate-btn"]`. Immediately after click, the button became disabled and showed the grayed-out state (spinner was not captured due to timing, but the disabled state was confirmed). The LLM call completed within ~10 seconds. After completion:
- `[data-role="chart-preview-section"]` appeared with "Chart Preview" label and "AI-generated — review before saving" note
- `[data-role="vega-lite-chart"]` element was present with a non-empty `data-spec` attribute
- `[data-role="save-section"]` appeared
- `[data-role="empty-state"]` was no longer visible
- `[data-role="generate-error"]` was not present

The chart rendered a bar chart with title "Monthly Revenue - Past 6 Months" with Month and Revenue axes. Bars are empty (no real data), which is expected behavior since no live data source is connected.

Screenshots: `.code_my_spec/qa/452/screenshots/s3_generating_spinner.png`, `.code_my_spec/qa/452/screenshots/s3_chart_generated.png`

### Scenario 5: Save section — validation prevents save with blank name

pass

With no text in `[data-role="save-name-input"]`, the `[data-role="save-visualization-btn"]` was confirmed disabled via `browser_is_enabled`. Pressing Enter on the empty input did not trigger a save or error. The save button's disabled state correctly prevents saves with a blank name.

Note: The brief states to also verify `[data-role="save-error"]` appears when clicking a disabled button. Since the button is actually disabled (HTML `disabled` attribute), the click event does not fire and no `save-error` is rendered. The button's disabled state is the correct prevention mechanism here. The server-side `handle_event("save_visualization")` also validates and would return "Name is required." if called directly.

Screenshot: `.code_my_spec/qa/452/screenshots/s4_save_validation_blank_name.png`

### Scenario 6: Save section — saving with a valid name produces confirmation

pass

Typed "QA Test Report" into `[data-role="save-name-input"]`. The `[data-role="save-visualization-btn"]` became enabled. Clicked the button. The `[data-role="save-confirmation"]` appeared promptly with:
- "Saved" badge (badge-success)
- "Visualization saved!" text
- "View in Visualizations" link — confirmed to navigate to `/visualizations` (fixed)
- "Generate Another" button present
- `[data-role="save-section"]` no longer visible

Screenshot: `.code_my_spec/qa/452/screenshots/s5_save_confirmation.png`

### Scenario 7: "Generate Another" resets state

pass

From the save confirmation state, clicked the "Generate Another" button. URL remained `http://localhost:4070/reports/generate` (push_patch, no full page reload). The page returned to initial state:
- Textarea empty (showing placeholder text only)
- `[data-role="empty-state"]` visible
- `[data-role="chart-preview-section"]` not present
- `[data-role="save-section"]` not present
- Generate Chart button disabled

Screenshot: `.code_my_spec/qa/452/screenshots/s6_generate_another_reset.png`

### Scenario 8: "View in Visualizations" link works

pass

After saving "QA Test Report", clicked "View in Visualizations" from the save confirmation. The `navigate` attribute on the link was verified to be `/visualizations` (fixed from the previous `/dashboards` bug). Navigation succeeded — the browser loaded `http://localhost:4070/visualizations` without error. The Visualizations page rendered correctly with the heading "Visualizations" and "Your saved charts and visualizations" subtitle, and the newly saved "QA Test Report" was visible in the list.

Screenshots: `.code_my_spec/qa/452/screenshots/s8_save_confirmation_fixed.png`, `.code_my_spec/qa/452/screenshots/s8_visualizations_page_final.png`

## Evidence

- `.code_my_spec/qa/452/screenshots/s1_initial_state.png` — Initial page state (authenticated, no prompt)
- `.code_my_spec/qa/452/screenshots/s2_prompt_filled.png` — Prompt entered, Generate Chart button enabled
- `.code_my_spec/qa/452/screenshots/s3_generating_spinner.png` — Button disabled immediately after click (during LLM call)
- `.code_my_spec/qa/452/screenshots/s3_chart_generated.png` — Chart preview section rendered after LLM response
- `.code_my_spec/qa/452/screenshots/s4_save_validation_blank_name.png` — Save button disabled with blank name
- `.code_my_spec/qa/452/screenshots/s5_save_confirmation.png` — Save confirmation with "Visualization saved!" and link/buttons
- `.code_my_spec/qa/452/screenshots/s6_generate_another_reset.png` — Page reset to initial state after "Generate Another"
- `.code_my_spec/qa/452/screenshots/s8_save_confirmation_fixed.png` — Save confirmation showing "View in Visualizations" link with href="/visualizations"
- `.code_my_spec/qa/452/screenshots/s8_visualizations_page_final.png` — /visualizations page showing saved "QA Test Report"

## Issues

### Chart renders with empty data (no bars visible)

#### Severity
INFO

#### Scope
app

#### Description
The AI-generated Vega-Lite spec produces a valid chart structure (title, axes, correct chart type) but the embedded data values are zero/empty, resulting in a chart with labeled axes and no visible bars or data points. This is expected behavior since the feature generates illustrative specs without a live data source, but users may find the empty chart confusing. The chart is still structurally correct and demonstrable.

Observed on: `http://localhost:4070/reports/generate` after submitting "Show me a bar chart of monthly revenue for the past 6 months".
