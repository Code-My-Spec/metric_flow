# QA Result

Story 436 — View and Manage Platform Integrations

## Status

pass

## Scenarios

### Scenario 1: Authenticated user can navigate to integrations page

**Result: PASS**

Navigated to `http://localhost:4070/integrations` while authenticated as `qa@example.com`. Page loaded without redirect. H1 heading "Integrations" confirmed present. Subtitle "Manage your connected marketing platforms" confirmed present. "Connect a Platform" link confirmed present.

Screenshot: `.code_my_spec/qa/436/screenshots/01-integrations-index.png`

### Scenario 2: Integrations page shows marketing and financial platforms

**Result: PASS**

"Connected Platforms" H2 heading confirmed present. "Available Platforms" H2 heading confirmed present. After seeding: Google Analytics and Google Ads both show under Connected Platforms (via Google provider). QuickBooks shows under Available Platforms. Facebook Ads was also connected (from a previous test run that did not seed correctly — see Issues). All four platform names rendered correctly in the page.

Screenshot: `.code_my_spec/qa/436/screenshots/02-connected-and-available-sections.png`

### Scenario 3: Each integration shows platform name, connected date, and sync status

**Result: PASS**

- `[data-role='integration-platform-name']` confirmed present inside `[data-role='integration-row']` — first element shows "Google Analytics"
- `[data-role='integration-connected-date']` confirmed present — shows "Connected via Google on 2026-03-17"
- `[data-role='integration-sync-status']` confirmed present (empty span when no sync has occurred)
- `[data-role='integration-card']` confirmed as the outer wrapper for each platform

Screenshot: `.code_my_spec/qa/436/screenshots/03-platform-name-date-status.png`

### Scenario 4: Integration shows selected accounts

**Result: PASS**

`[data-role='integration-selected-accounts']` confirmed present inside `[data-role='integration-row']` for the Google Analytics card. Text "Campaign Alpha, Campaign Beta" confirmed visible as seeded.

Screenshot: `.code_my_spec/qa/436/screenshots/04-selected-accounts.png`

### Scenario 5: Edit accounts link present

**Result: PASS**

`[data-role='edit-integration-accounts']` ("Edit Accounts" link) confirmed present. `[data-role='integration-detail-link']` ("Manage" link) confirmed present. Clicking "Edit Accounts" navigated to `http://localhost:4070/integrations/connect/google/accounts` without triggering an OAuth redirect.

Screenshots:
- `.code_my_spec/qa/436/screenshots/05-edit-accounts-link.png`
- `.code_my_spec/qa/436/screenshots/05b-edit-accounts-page.png`

### Scenario 6: Disconnect button is present

**Result: PASS**

`[data-role='disconnect-integration']` button confirmed visible inside connected Google platform cards. Button text is "Disconnect".

Screenshot: `.code_my_spec/qa/436/screenshots/06-disconnect-button-present.png`

### Scenario 7: Disconnect confirmation modal — warning text

**Result: PASS**

Clicked `[data-platform='google_analytics'] [data-role='disconnect-integration']`. Modal with `[data-role='disconnect-modal']` became visible. Modal heading confirmed as "Disconnect Google?" (previously was a bug — now resolved). `[data-role='disconnect-warning']` element confirmed present. Warning text includes "Historical data will remain available" and "no new data will sync after disconnecting."

Screenshot: `.code_my_spec/qa/436/screenshots/07-disconnect-modal-warning.png`

### Scenario 8: Disconnect modal has confirm and cancel options

**Result: PASS**

`[data-role='confirm-disconnect']` button confirmed present with text "Disconnect" (previously was a bug "Confirm" — now resolved). `[data-role='cancel-disconnect']` button confirmed present with text "Cancel". Clicked Cancel — modal disappeared (state "hidden" reached). Google Analytics confirmed still in `data-status="connected"` state after cancel.

Screenshot: `.code_my_spec/qa/436/screenshots/08-disconnect-cancelled.png`

### Scenario 9: Complete disconnect flow

**Result: PASS**

Re-opened modal, clicked `[data-role='confirm-disconnect']`. Modal dismissed. Flash message shown: "Disconnected from Google. Historical data is retained; no new data will sync after disconnecting." (previously the "no new data will sync" phrase was missing — now resolved). Google Analytics and Google Ads both moved to "Available Platforms" section.

Screenshot: `.code_my_spec/qa/436/screenshots/09-after-disconnect.png`

### Scenario 10: Reconnect option for disconnected platform

**Result: PASS**

After disconnect, `[data-role='reconnect-integration']` confirmed present with text "Connect Google". Both `[data-platform='google_analytics']` and `[data-platform='google_ads']` confirmed with `data-status="available"`. Clicking "Connect Google" navigated to `http://localhost:4070/integrations/connect`.

Screenshots:
- `.code_my_spec/qa/436/screenshots/10-reconnect-available.png`
- `.code_my_spec/qa/436/screenshots/10b-reconnect-navigated.png`

### Scenario 11: Uniform card layout — no QuickBooks special UI

**Result: PASS**

`[data-platform='quickbooks'][data-role='integration-card']` confirmed present. `[data-role='quickbooks-special-section']` confirmed not visible. `[data-platform='quickbooks'] [data-role='integration-platform-name']` confirmed present with text "QuickBooks". All four platforms rendered with the same `[data-role='integration-card']` structure.

Screenshot: `.code_my_spec/qa/436/screenshots/11-uniform-card-layout.png`

### Scenario 12: Unauthenticated access is blocked

**Result: PASS**

`curl -s -o /dev/null -w "%{http_code}" http://localhost:4070/integrations` returned `302`. Unauthenticated requests are correctly redirected.

## Evidence

- `.code_my_spec/qa/436/screenshots/01-integrations-index.png` — page load with H1 heading and Connect a Platform button
- `.code_my_spec/qa/436/screenshots/02-connected-and-available-sections.png` — Connected Platforms and Available Platforms sections (full page)
- `.code_my_spec/qa/436/screenshots/03-platform-name-date-status.png` — platform name, connected date, and sync status attributes visible
- `.code_my_spec/qa/436/screenshots/04-selected-accounts.png` — selected accounts "Campaign Alpha, Campaign Beta" displayed
- `.code_my_spec/qa/436/screenshots/05-edit-accounts-link.png` — Edit Accounts and Manage links visible
- `.code_my_spec/qa/436/screenshots/05b-edit-accounts-page.png` — Edit Accounts page loaded at `/integrations/connect/google/accounts`
- `.code_my_spec/qa/436/screenshots/06-disconnect-button-present.png` — Disconnect button visible in connected platform card
- `.code_my_spec/qa/436/screenshots/07-disconnect-modal-warning.png` — Disconnect modal with heading "Disconnect Google?" and warning text
- `.code_my_spec/qa/436/screenshots/08-disconnect-cancelled.png` — modal dismissed after Cancel; Google still connected
- `.code_my_spec/qa/436/screenshots/09-after-disconnect.png` — Google disconnected, flash message shown, moved to Available Platforms
- `.code_my_spec/qa/436/screenshots/10-reconnect-available.png` — "Connect Google" button visible, platforms data-status="available"
- `.code_my_spec/qa/436/screenshots/10b-reconnect-navigated.png` — navigated to /integrations/connect after clicking reconnect
- `.code_my_spec/qa/436/screenshots/11-uniform-card-layout.png` — all four platforms with uniform card structure (full page)
- `.code_my_spec/qa/436/screenshots/12-final-state.png` — final page state after all scenarios

## Issues

### Seed data leaves stale Facebook integration after previous test run

#### Severity
LOW

#### Scope
QA

#### Description

After running `mix run priv/repo/qa_seeds.exs`, the integrations page showed Facebook Ads as the only Connected Platform, while Google Analytics and Google Ads appeared under Available Platforms. The seed script creates a Google integration only if one does not already exist (`Repo.get_by(Integration, user_id: qa_user.id, provider: :google)`). However, a Facebook integration from a previous test run was still present and was not cleaned up by seeds.

The seeds ran successfully (Google integration created on the second run attempt, once seeds ran with the full app started via `mix run` rather than `--no-start`). After running seeds properly, Google appeared under Connected Platforms as expected.

The seed script should also delete any non-Google integrations for `qa@example.com` to restore a clean baseline, or the QA plan should document that the `--no-start` seed approach does not work (Cloak encryption requires the full app to start).

Reproduced: before running seeds the second time with `mix run priv/repo/qa_seeds.exs`.
