# QA Story Brief

Story 516: Sync Google Search Console Data — testing via the Sync History LiveView
(`/integrations/sync-history`). The story introduces `google_search_console` as a
provider. The BDD specs verify the LiveView handles `{:sync_completed, ...}` and
`{:sync_failed, ...}` broadcasts for this provider (unit-test level). Browser tests
verify the Sync History page loads correctly, the page structure matches the spec,
filter tabs work, and the empty state is shown when no syncs have run — all of which
are observable without triggering an actual sync.

## Tool

web (Vibium MCP browser tools — `/integrations/sync-history` is a LiveView behind
`:require_authenticated_user`)

## Auth

Log in as `qa@example.com` using the password form:

```
mcp__vibium__browser_launch(headless: true)
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait_for_url(pattern: "/", timeout: 5000)
```

## Seeds

The base seed script is sufficient. It creates `qa@example.com` with a Google
integration and clears sync history so the empty state is shown on a fresh run.

If the server is already running, skip the seed script and verify login works instead.
Only run seeds if `qa@example.com` does not exist:

```bash
# Only run if login fails:
mix run priv/repo/qa_seeds.exs
```

The seed script creates:
- `qa@example.com` / `hello world!` — owner of "QA Test Account"
- Google integration with provider `:google` and no sync history (cleared)

No story-specific seeds are required. The sync history page will show the empty state
("No sync history yet.") because seeds clear all sync history records.

## What To Test

### Scenario 1 — Unauthenticated redirect

Visit `/integrations/sync-history` without being logged in and verify the page
redirects to the login page.

- Use `curl` to check the HTTP redirect:
  ```bash
  curl -s -o /dev/null -w "%{http_code}" http://localhost:4070/integrations/sync-history
  ```
  Expected: `302`
- Screenshot: `01-unauthenticated-redirect.png` (optional — curl output is sufficient)

### Scenario 2 — Page loads for authenticated user

After logging in, navigate to `/integrations/sync-history` and verify:

- The page renders with H1 "Sync History"
- Subtitle "View automated sync results and status" is visible
- The automated sync schedule card is present (`data-role="sync-schedule"`)
  - Contains H2 "Automated Sync Schedule"
  - Contains "Daily at 2:00 AM UTC" in the schedule description
  - Contains `.badge.badge-info` labeled "Daily"
- The date range section is present (`data-role="date-range"`)
  - Shows "Showing data through {yesterday's ISO date} (yesterday — today excluded, incomplete day)"
- Screenshot: `02-page-loaded.png`

### Scenario 3 — Empty state shown when no syncs have run

With no sync history records in the database (seeds clear them), verify:

- The sync history list (`data-role="sync-history"`) shows the empty state card
- Text "No sync history yet." is visible
- Secondary text about Initial Sync is visible
- A `.badge.badge-ghost` labeled "Initial Sync" with `data-sync-type="initial"` is present
- No `data-role="sync-history-entry"` elements exist
- Screenshot: `03-empty-state.png`

### Scenario 4 — Filter tabs are rendered and functional

Verify the three filter buttons are present and the default active state is correct:

- "All" button has `data-role="filter-all"` and is active (`.btn-primary` class)
- "Success" button has `data-role="filter-success"` and is inactive (`.btn-ghost` class)
- "Failed" button has `data-role="filter-failed"` and is inactive (`.btn-ghost` class)

Click "Success" and verify:
- "Success" button becomes `.btn-primary`
- "All" and "Failed" buttons become `.btn-ghost`
- Page still shows the empty state (no entries to show)

Click "Failed" and verify:
- "Failed" button becomes `.btn-primary`

Click "All" and verify:
- "All" button becomes `.btn-primary` again

Screenshot: `04-filter-tabs.png` (after clicking through filters)

### Scenario 5 — Google Search Console provider display name (known risk)

This scenario checks whether the LiveView's `provider_display_name/1` function handles
the `:google_search_console` atom correctly. The `@provider_names` map in
`SyncHistory` does NOT include `:google_search_console` — it falls through to
`derive_display_name/1` which converts underscores to spaces and capitalizes each
word, producing "Google Search Console".

To verify this without triggering an actual sync, inspect the source code (already
confirmed above) and note as a finding. The BDD spex test (`criterion_4806`) covers
this by sending a `{:sync_completed, %{provider: :google_search_console, ...}}`
message directly to the LiveView process in the test suite.

Run the BDD spex tests to check:
```bash
cd /Users/johndavenport/Documents/github/metric_flow && mix spex test/spex/516_sync_google_search_console_data/
```

Capture the test output. A passing result confirms the LiveView correctly renders
"Google Search Console" (or "google_search_console" as fallback) for this provider.
Screenshot: `05-spex-results.png` (terminal/text output)

### Scenario 6 — Google Search Console not in @provider_names map (architectural note)

Navigate to the sync history page and read the page HTML to confirm the `@provider_names`
map only covers `google_ads`, `facebook_ads`, `google_analytics`, `quickbooks`, `google`.

- Visit `http://localhost:4070/integrations/sync-history`
- Get page text and confirm no "Google Search Console" entry exists in the live history
  (since no sync has occurred — this is expected)
- Note as an INFO-level finding: `:google_search_console` is not in the `@provider_names`
  map in `SyncHistory`. The derive_display_name fallback will render "Google Search Console"
  correctly at runtime, but the provider is not explicitly registered. This is consistent
  with the acceptance criterion's note about architectural inconsistency.

Screenshot: `06-sync-history-final.png`

## Setup Notes

The BDD spex files for story 516 test the LiveView at the process-message level — they
send `{:sync_completed, ...}` directly to the LiveView pid. These tests do not require
an actual sync to run. Run them with `mix spex` to verify the LiveView handles the
`:google_search_console` provider atom.

The acceptance criteria include several ARCHITECTURAL NOTEs (fetcher writes directly
to DB, inconsistent with other integrations; overall metrics without valid date anchor
is a known bug). These are implementation-layer concerns not visible in the Sync
History UI. Do not attempt to trigger an actual Google Search Console sync — the QA
test environment does not have valid Google OAuth tokens configured for this provider.

The `@provider_names` map in `sync_history.ex` does not include `:google_search_console`.
The fallback `derive_display_name/1` function will produce "Google Search Console"
correctly, but this should be flagged as a low-severity gap (the provider should be
explicitly named to avoid relying on string manipulation).

## Result Path

`.code_my_spec/qa/516/result.md`
