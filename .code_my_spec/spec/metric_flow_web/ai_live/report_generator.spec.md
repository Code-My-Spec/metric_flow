# MetricFlowWeb.AiLive.ReportGenerator

Natural language report generation. Allows authenticated users to describe a visualization in plain language, generate a Vega-Lite chart spec via the AI context, preview the rendered chart, and optionally save it as a named visualization. Unauthenticated requests are redirected to `/users/log-in` by the router's `:require_authenticated_user` pipeline.

## Type

liveview

## Route

`/reports/generate`

## Params

None

## Dependencies

- MetricFlow.Ai
- MetricFlow.Dashboards

## Components

None

## User Interactions

- **mount**: Reads `current_scope` from socket assigns. Assigns `prompt: ""`, `generating: false`, `vega_spec: nil`, `error: nil`, `save_name: ""`, `saving: false`, `save_error: nil`, `saved: false`, and `page_title: "Generate Report"`. Requires authentication; unauthenticated requests redirect to `/users/log-in` via the router authentication plug.

- **phx-change="update_prompt"** (prompt: string): Updates the `prompt` assign on each keystroke. Clears any existing `error` assign. Does not call any context function.

- **phx-submit="generate"** (prompt: string): Ignores the event if `generating` is true or the trimmed prompt is blank. Sets `generating: true`, `vega_spec: nil`, `error: nil`, `saved: false`, and `save_name: ""`. Calls `Ai.generate_vega_spec(scope, prompt)`. On `{:ok, spec}`, assigns `vega_spec: spec` and sets `generating: false`. On `{:error, reason}`, sets `generating: false` and assigns a user-facing `error` string. The submit button is disabled while `generating` is true.

- **phx-change="update_save_name"** (name: string): Updates the `save_name` assign. Clears any existing `save_error`.

- **phx-click="save_visualization"** (`data-role="save-visualization-btn"`): Validates that `save_name` is non-blank and that `vega_spec` is present. If either is missing, assigns a field-level `save_error` without persisting. Otherwise sets `saving: true` and calls `Dashboards.save_visualization(scope, %{name: save_name, vega_spec: vega_spec, chart_type: "custom", shareable: false})`. On `{:ok, _visualization}`, assigns `saved: true`, `saving: false`, and `save_error: nil`. On `{:error, changeset}`, assigns `saving: false` and assigns a `save_error` message derived from the changeset. The save button is disabled when `saving` is true, `vega_spec` is nil, or `save_name` is blank.

## Design

Layout: Centered single-column page within the `Layouts.app` shell, content constrained to `max-w-3xl mx-auto px-4 py-8`.

### Page header

- H1: "Generate Report" (bold)
- Subtitle paragraph: "Describe the chart or report you want and AI will build it for you." (`.text-base-content/60 mt-1`)

### Prompt form (`data-role="prompt-form"`)

`.mf-card p-5 mb-6`.
- Label: "What do you want to visualize?" (`font-semibold text-sm`)
- Textarea (`data-role="prompt-input"`, `phx-change="update_prompt"`, `rows="4"`, placeholder "e.g. Show me weekly revenue and ad spend over the last 90 days", `.textarea.textarea-bordered.w-full`, disabled when `generating` is true)
- Generate button (`data-role="generate-btn"`, `.btn.btn-primary.mt-4`, disabled when `generating` is true or prompt is blank):
  - Shows `.loading.loading-spinner.loading-xs` and label "Generating…" while `generating` is true
  - Shows label "Generate Chart" otherwise
- Error message (`data-role="generate-error"`, `.text-error.text-sm.mt-2`): shown only when `error` is non-nil

### Chart preview section (`data-role="chart-preview-section"`)

`.mf-card p-5 mb-6`. Shown only when `vega_spec` is non-nil.
- Section header flex row:
  - Label "Chart Preview" (`font-semibold text-sm`)
  - Small muted note: "AI-generated — review before saving" (`.text-xs.text-base-content/40`)
- Vega-Lite chart container (`data-role="vega-lite-chart"`, `phx-hook="VegaLite"`, `data-spec={Jason.encode!(vega_spec)}`)

### Save section (`data-role="save-section"`)

`.mf-card p-5 mb-6`. Shown only when `vega_spec` is non-nil and `saved` is false.
- Label: "Save this visualization" (`font-semibold text-sm`)
- Name input (`data-role="save-name-input"`, `.input.input-bordered.w-full.mt-2`, `phx-change="update_save_name"`, placeholder "Visualization name"):
  - Shows `.input-error` class and inline error (`data-role="save-error"`, `.text-error.text-sm.mt-1`) when `save_error` is non-nil
- Save button (`data-role="save-visualization-btn"`, `.btn.btn-primary.btn-sm.mt-3`, `phx-click="save_visualization"`, disabled when `saving` is true, `vega_spec` is nil, or `save_name` is blank):
  - Shows `.loading.loading-spinner.loading-xs` and label "Saving…" while `saving` is true
  - Shows label "Save Visualization" otherwise

### Saved confirmation (`data-role="save-confirmation"`)

`.mf-card p-5 mb-6`. Shown only when `saved` is true.
- Success badge (`badge badge-success`) and text "Visualization saved!"
- `.link` navigating to `/visualizations` with label "View in Visualizations"
- `.btn.btn-ghost.btn-sm` "Generate Another" button that resets state by navigating to `/reports/generate` via `push_patch`

### Empty / initial state (`data-role="empty-state"`)

Shown when `vega_spec` is nil and `generating` is false and no error is present. Centered muted text below the prompt form:
- "Enter a prompt above and click Generate Chart to get started." (`.text-base-content/40.text-sm.text-center.py-8`)

Components: `.mf-card`, `.btn`, `.btn-primary`, `.btn-ghost`, `.btn-sm`, `.btn-disabled`, `.textarea`, `.textarea-bordered`, `.input`, `.input-bordered`, `.input-error`, `.badge`, `.badge-success`, `.loading`, `.loading-spinner`, `.loading-xs`, `.text-error`, `.link`

Responsive: All cards stack vertically. Textarea and inputs span full width. Generate and save buttons span full width on mobile (`w-full sm:w-auto`).

## Test Assertions

- renders report generator page with prompt form and Generate Chart button
- shows empty state when no chart has been generated
- updates prompt text on change without calling any context
- disables generate button when prompt is blank or generation is in progress
- shows chart preview section with Vega-Lite container after successful generation
- shows error message when generation fails
- shows save section with name input after chart is generated
- saves visualization and shows confirmation with link to visualizations
- shows save error when save name is blank
- disables save button when vega_spec is nil or save name is blank
- resets state when Generate Another is clicked after saving
