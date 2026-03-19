# QA Story Brief

Story 448: View Correlation Analysis Results (Raw Mode)

## Tool

web (vibium MCP browser tools — all pages are LiveView)

## Auth

Log in as the QA owner user via the password form:

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

The base QA seeds create `qa@example.com` / `hello world!` and the "QA Test Account". No
correlation data exists by default — the page will show the no-data empty state.

Verify seeds are in place by successfully logging in. If login fails, run:

```bash
cd /Users/johndavenport/Documents/github/metric_flow
mix run priv/repo/qa_seeds.exs
```

No additional correlation data seeds are required. The no-data state and the "Run Now /
insufficient data" flow are both testable without pre-existing correlation records. The
navigation link test does not require correlation data either.

## What To Test

### Scenario 1 — Navigation link exists (AC: User can access correlation analysis from main navigation)

- Navigate to `http://localhost:4070/dashboard` after login
- Verify the main navigation contains a link labeled "Correlations"
- Capture a screenshot of the navigation area
- Expected: `<a href="/correlations">Correlations</a>` (or equivalent) is visible in the nav

### Scenario 2 — Correlations page is accessible via navigation (AC: same as above)

- Click the "Correlations" link in the navigation
- Wait for the URL to change to `/correlations`
- Verify the page heading "Correlations" is rendered
- Capture a screenshot of the page
- Expected: H1 "Correlations" and subtitle "Which metrics drive your goal?" are visible

### Scenario 3 — Unauthenticated redirect (AC: access control)

- Clear browser cookies with `mcp__vibium__browser_delete_cookies()`
- Navigate directly to `http://localhost:4070/correlations`
- Expected: redirected to `/users/log-in` (URL contains "log-in")
- Capture a screenshot of the redirect destination

### Scenario 4 — No-data empty state (AC: If insufficient data, user sees a message)

- Log in as `qa-empty@example.com` / `hello world!` (personal account only, no team membership, no correlation data) and navigate to `http://localhost:4070/correlations`
- Verify the `[data-role="no-data-state"]` element is present
- Verify the text "No Correlations Yet" appears
- Verify a "Connect Integrations" link is present pointing to `/integrations`
- Capture a screenshot
- Expected: empty state card with explanation text and CTA link

### Scenario 5 — Mode toggle is present (AC: User can toggle between Raw and Smart modes)

- Switch back to `qa@example.com` (delete cookies, log in again) and navigate to `http://localhost:4070/correlations`
- Verify `[data-role="mode-toggle"]` is present
- Verify `[data-role="mode-raw"]` button is present and has `.btn-primary` styling (active by default)
- Verify `[data-role="mode-smart"]` button is present
- Capture a screenshot of the mode toggle
- Expected: "Raw" button is primary-styled (active), "Smart" button is ghost-styled (inactive)

### Scenario 6 — Switch to Smart mode (AC: User can toggle between Raw and Smart modes)

- On the correlations page, click the `[data-role="mode-smart"]` button
- Verify `[data-role="smart-mode"]` element appears
- Verify `[data-role="enable-ai-suggestions"]` button is present
- Verify `[data-role="raw-mode"]` is no longer visible (or absent)
- Capture a screenshot
- Expected: Smart mode panel with "Enable AI Suggestions" button

### Scenario 7 — Switch back to Raw mode

- While in Smart mode, click the `[data-role="mode-raw"]` button
- Verify `[data-role="smart-mode"]` is no longer visible
- Verify `[data-role="mode-raw"]` button returns to `.btn-primary` styling
- Capture a screenshot

### Scenario 8 — Run Now button and insufficient data (AC: If insufficient data, message is shown)

- While still logged in as `qa-empty@example.com` on the correlations page (no data), click `[data-role="run-correlations"]`
- Verify a flash error message appears containing "Not enough data" or similar
- Verify `[data-role="insufficient-data-warning"]` badge appears with text "Insufficient data — 30 days of metrics required"
- Capture a screenshot
- Expected: error flash + warning badge both visible

### Scenario 9 — Configure Goals link

- On the correlations page, verify `[data-role="configure-goals"]` link is present and navigates to `/correlations/goals`
- Capture a screenshot showing the link

## Setup Notes

The correlations page is a LiveView at `/correlations`. It mounts with `mode: :raw` by default.
When no correlation data exists (`summary.no_data == true`), the `[data-role="raw-mode"]` section
is hidden and the `[data-role="no-data-state"]` is shown instead.

The `Run Now` button calls `Correlations.run_correlations/2`. With no integration data seeded,
it returns `{:error, :insufficient_data}`, which is the expected path for Scenario 8.

The BDD spec (`criterion_4115`) tests three scenarios: nav link presence, direct navigation to
`/correlations`, and unauthenticated redirect — these map to Scenarios 1, 2, and 3 above.

## Result Path

`.code_my_spec/qa/448/result.md`
