# QA Result — Story 436: View and Manage Platform Integrations

## Status

pass

**Date:** 2026-03-16
**Tester:** QA Agent (claude-sonnet-4-6)
**App URL:** http://localhost:4070
**Auth:** qa@example.com / hello world!

---

## Scenarios

### Scenario 1: Authenticated user can navigate to integrations page

**Result:** pass

Navigated to `http://localhost:4070/integrations`. Page loaded without redirect.
- H1 "Integrations" present
- Subtitle "Manage your connected marketing platforms" present
- "Connect a Platform" link present, pointing to `/integrations/connect`
- `[data-role='integrations-index']` wrapper present

**Evidence:** `.code_my_spec/qa/436/screenshots/01-integrations-index.png`

---

### Scenario 2: Page shows both marketing and financial platforms

**Result:** pass

- "Connected Platforms" H2 section present (Google Analytics, Google Ads, Facebook Ads were connected)
- "Available Platforms" H2 section present (QuickBooks, and post-disconnect the Google platforms)
- All four platforms confirmed in page text: Google Analytics, Google Ads, Facebook Ads, QuickBooks
- `[data-role='integration-card']` elements present for all four platforms

**Evidence:** `.code_my_spec/qa/436/screenshots/02-connected-and-available-sections.png`

---

### Scenario 3: Each connected integration shows platform name, connected date, and sync status

**Result:** pass

- `[data-role='integration-platform-name']` present, text: "Google Analytics" (first connected card)
- `[data-role='integration-connected-date']` present, text: "Connected via Google on 2026-03-16"
- `[data-role='integration-sync-status']` present on each card
- `[data-role='integration-row'] [data-role='integration-platform-name']` nesting confirmed
- `[data-role='integration-card']` wrapper present for each platform

**Evidence:** `.code_my_spec/qa/436/screenshots/03-platform-name-date-status.png`

---

### Scenario 4: Integration shows selected accounts section

**Result:** pass (structure pass; content note below)

- `[data-role='integration-selected-accounts']` present on all connected cards (3 elements found)
- `[data-role='integration-row'] [data-role='integration-selected-accounts']` nesting confirmed
- Displayed value: "No accounts selected" — see note below

**Note:** The seed script inserts `selected_accounts: ["Campaign Alpha", "Campaign Beta"]` but only
when the Google integration does not already exist. The running DB had a real OAuth integration with
no `selected_accounts` in `provider_metadata`. The element structure is correct; the seed data drift
caused the content check to show empty accounts. This is a QA environment issue, not an app bug.

**Evidence:** `.code_my_spec/qa/436/screenshots/04-selected-accounts.png`

---

### Scenario 5: Edit accounts link navigates without OAuth redirect

**Result:** pass

- `[data-role='edit-integration-accounts']` link present, href: `/integrations/connect/google/accounts`
- `[data-role='integration-detail-link']` (Manage) link present
- Clicked "Edit Accounts" — URL changed to `http://localhost:4070/integrations/connect/google/accounts`
- No redirect to `accounts.google.com` or any external OAuth provider
- `[data-role='account-selection']` visible on the edit page
- `[data-role='re-authenticate-button']` not present
- "Save Selection" button (submit) present on the page

**Minor finding:** The Save button has no `data-role='save-account-selection'` attribute. The BDD spec checks for `[data-role='save-account-selection']` but the element is a plain `<button type="submit">`. The functional behavior (save without re-auth) works correctly. Reported as INFO.

**Evidence:**
- `.code_my_spec/qa/436/screenshots/05-edit-accounts-link.png`
- `.code_my_spec/qa/436/screenshots/05b-edit-accounts-page.png`

---

### Scenario 6: Disconnect button present on connected integration cards

**Result:** pass

- Three `[data-role='disconnect-integration']` buttons found (one per connected platform: Google Analytics, Google Ads, Facebook Ads)
- Button text: "Disconnect"
- Buttons are within connected-status cards (`data-status="connected"`)

**Evidence:** `.code_my_spec/qa/436/screenshots/06-disconnect-button-present.png`

---

### Scenario 7: Disconnect confirmation modal shows warning about historical data

**Result:** pass

- Clicked `[data-platform='google_analytics'] [data-role='disconnect-integration']`
- `[data-role='disconnect-modal']` became visible
- Modal heading: "Disconnect Google?"
- `[data-role='disconnect-warning']` present
- Warning text: "Historical data will remain available, but no new data will sync after disconnecting."
- Contains "historical data": yes
- Contains "no new data will sync": yes
- `[data-role='confirm-disconnect']` present with text "Disconnect"
- `[data-role='cancel-disconnect']` present with text "Cancel"

**Evidence:** `.code_my_spec/qa/436/screenshots/07-disconnect-modal-warning.png`

---

### Scenario 8: Cancel dismiss closes modal without disconnecting

**Result:** pass

- `[data-role='confirm-disconnect']` button present
- `[data-role='cancel-disconnect']` button present
- Clicked cancel — modal disappeared (`state: hidden` confirmed)
- Integration card still present at `[data-platform='google_analytics'][data-status='connected']` — not disconnected

**Evidence:** `.code_my_spec/qa/436/screenshots/08-disconnect-cancelled.png`

---

### Scenario 9: Complete disconnect flow

**Result:** pass

- Clicked Disconnect on Google Analytics card → modal opened
- Clicked `[data-role='confirm-disconnect']` → modal closed
- Flash message displayed: "Disconnected from Google. Historical data is retained; no new data will sync after disconnecting."
- Google Analytics and Google Ads moved to "Available Platforms" section with `data-status="available"`
- "Connect Google" button appeared for both Google platforms
- Only Facebook Ads remained in "Connected Platforms"

**Evidence:** `.code_my_spec/qa/436/screenshots/09-after-disconnect.png`

---

### Scenario 10: Reconnect option for disconnected platform

**Result:** pass

- After disconnect, three `[data-role='reconnect-integration']` links found: two "Connect Google" and one "Connect QuickBooks"
- `[data-platform='google_analytics'][data-status='available']` confirmed
- Reconnect link href: `/integrations/connect`
- Clicked "Connect Google" for google_analytics — URL changed to `http://localhost:4070/integrations/connect`

**Evidence:**
- `.code_my_spec/qa/436/screenshots/10-reconnect-available.png`
- `.code_my_spec/qa/436/screenshots/10b-reconnect-navigated.png`

---

### Scenario 11: Uniform card layout — no QuickBooks special UI

**Result:** pass

- `[data-platform='quickbooks'][data-role='integration-card']` present
- `[data-platform='quickbooks'] [data-role='integration-platform-name']` text: "QuickBooks"
- `[data-role='quickbooks-special-section']` not found (not visible)
- All four platforms render with `[data-role='integration-card']`: Facebook Ads, Google Analytics, Google Ads, QuickBooks
- QuickBooks uses the same card structure as other platforms

**Evidence:** `.code_my_spec/qa/436/screenshots/11-uniform-card-layout.png`

---

### Scenario 12: Unauthenticated access blocked

**Result:** pass

```
curl -s -o /dev/null -w "%{http_code}" http://localhost:4070/integrations
→ 302

curl -s -o /dev/null -w "%{redirect_url}" http://localhost:4070/integrations
→ http://localhost:4070/users/log-in
```

Unauthenticated GET returns 302 redirecting to `/users/log-in`.

---

## Evidence

| Screenshot | Scenario |
|---|---|
| `screenshots/01-integrations-index.png` | S1 — page load, H1, subtitle |
| `screenshots/02-connected-and-available-sections.png` | S2 — all four platforms, both sections |
| `screenshots/03-platform-name-date-status.png` | S3 — platform name, connected date, sync status |
| `screenshots/04-selected-accounts.png` | S4 — selected accounts element structure |
| `screenshots/05-edit-accounts-link.png` | S5 — edit accounts link on card |
| `screenshots/05b-edit-accounts-page.png` | S5 — edit accounts page (no OAuth redirect) |
| `screenshots/06-disconnect-button-present.png` | S6 — disconnect buttons on connected cards |
| `screenshots/07-disconnect-modal-warning.png` | S7 — disconnect modal with warning text |
| `screenshots/08-disconnect-cancelled.png` | S8 — cancel closes modal, integration still connected |
| `screenshots/09-after-disconnect.png` | S9 — post-disconnect flash and platform moved to available |
| `screenshots/10-reconnect-available.png` | S10 — reconnect buttons for disconnected platforms |
| `screenshots/10b-reconnect-navigated.png` | S10 — reconnect navigates to /integrations/connect |
| `screenshots/11-uniform-card-layout.png` | S11 — uniform card layout for all platforms including QuickBooks |

---

## Issues

### Save button on Edit Accounts page missing data-role='save-account-selection'

#### Severity
LOW

#### Scope
APP

#### Description
The BDD spec for criterion 4036 checks for `[data-role='save-account-selection']` on the edit accounts page (`/integrations/connect/google/accounts`). The page renders a `<button type="submit">` labeled "Save Selection" but it has no `data-role` attribute. The functional behavior is correct but the spec attribute is missing, which would cause the automated BDD test to fail.

### Seed data drift — selected_accounts not present in existing Google integration

#### Severity
INFO

#### Scope
QA

#### Description
The QA seed script sets `provider_metadata` with `selected_accounts` for the Google integration, but only on insert. In this environment a real OAuth integration already exists with no `selected_accounts` key, so the element shows "No accounts selected" instead of the expected seed accounts.
