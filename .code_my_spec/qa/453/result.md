# QA Result — Story 453: Agency White-label Configuration

## Status

fail

## Scenarios

Testing was conducted via BDD spex (`mix spex`), direct Elixir context calls (`mix run`), and curl-captured static HTML. vibium MCP browser tools were unavailable in this session (reported as Issue 4). App URL: `http://localhost:4070`. Auth user: `qa@example.com` / `hello world!` (team account owner on QA Test Account, id=2, type=team). Seeds: `mix run priv/repo/qa_seeds.exs`.

Note: `qa@example.com` had accumulated extra account memberships from previous QA runs (accounts 14–17). These placed a non-owner account first in `list_accounts` order, which would have hidden the white-label section. Those memberships were removed before testing so QA Test Account (id=2) is first. This is a test data contamination issue from prior story QA runs.

### Scenario 1 — White-Label Branding section is visible (criterion 4152, 4153, 4154)

**Result: pass**

Navigated to `http://localhost:4070/accounts/settings` as `qa@example.com` (team account owner). Verified in static HTML:

- "White-Label Branding" heading is present
- `#white-label-form` is present
- `input[name='white_label[logo_url]']` is present
- `input[name='white_label[primary_color]']` is present
- `input[name='white_label[secondary_color]']` is present
- `input[name='white_label[subdomain]']` is present
- Helper text "Lowercase letters, numbers, and hyphens only (3–63 characters)" is present

Evidence: `.code_my_spec/qa/453/screenshots/01_settings_page_white_label_section.html`

### Scenario 2 — Save with PNG logo URL (criterion 4152)

**Result: partial — data layer pass, flash text mismatch (app bug)**

`Agencies.update_white_label_config/3` called with `logo_url: "https://cdn.example.com/logo.png"` returned `{:ok, config}`. Static HTML after seeding shows the logo URL pre-filled in the input. BDD spex fails: the app emits flash `"White-label branding saved successfully"` but spec asserts `"White-label settings saved"`.

Evidence: `.code_my_spec/qa/453/screenshots/02_settings_page_with_saved_config.html`

### Scenario 3 — Save with JPG logo URL (criterion 4152)

**Result: partial — data layer pass, flash text mismatch (app bug)**

`Agencies.update_white_label_config/3` with `logo_url: "https://cdn.example.com/brand-logo.jpg"` returned `{:ok, config}`. Same flash mismatch as Scenario 2.

### Scenario 4 — Save with SVG logo URL (criterion 4152)

**Result: partial — data layer pass, flash text mismatch (app bug)**

`Agencies.update_white_label_config/3` with `logo_url: "https://cdn.example.com/vector-logo.svg"` returned `{:ok, config}`. Same flash mismatch.

### Scenario 5 — Save custom color scheme (criterion 4153)

**Result: partial — data layer pass, flash text mismatch (app bug)**

`Agencies.update_white_label_config/3` with `primary_color: "#3498DB", secondary_color: "#2ECC71"` saved both values correctly. Static HTML confirms both values pre-filled after save. BDD spex 4153 fails on flash text: emits `"White-label branding saved successfully"`, spec asserts `"White-label settings saved"`.

### Scenario 6 — Real-time preview before saving (criterion 4155)

**Result: pass**

BDD spex 4155 passes (3 tests, 0 failures). The `phx-change="validate_white_label"` handler updates `white_label_form` assigns, and the preview section (`[data-role="white-label-preview"]`) renders live color swatches from form params before the form is submitted. The preview is absent when no color is entered.

### Scenario 7 — Save custom subdomain (criterion 4154)

**Result: partial — data layer pass, flash text mismatch (app bug)**

`Agencies.update_white_label_config/3` with `subdomain: "reports-andersonthefish"` saved correctly. Static HTML shows the subdomain pre-filled in the input. BDD spex 4154 fails on flash text: same mismatch as above.

### Scenario 8 — Subdomain persists on page revisit (criterion 4154, 4157)

**Result: pass**

`Agencies.get_white_label_config/2` after save returns the record with all four fields intact. BDD spex 4157 passes (1 test, 0 failures). Static HTML after seeding confirms `value="reports-andersonthefish"` in the subdomain input on fresh page load.

Evidence: `.code_my_spec/qa/453/screenshots/02_settings_page_with_saved_config.html`

### Scenario 9 — DNS verification section after subdomain save (criterion 4158)

**Result: pass**

BDD spex 4158 passes (1 test, 0 failures). Static HTML after saving a subdomain confirms:

- `[data-role="dns-verification"]` panel is present
- "DNS Verification Required" heading rendered
- Subdomain value appears in the DNS instructions text
- `[data-role="verify-dns"]` button is present
- "Pending verification" badge is rendered
- The subdomain is not shown as "Active"

Evidence: `.code_my_spec/qa/453/screenshots/02_settings_page_with_saved_config.html`

### Scenario 10 — Reset to Default button visibility (criterion 4156)

**Result: pass**

Static HTML with a saved config confirms `[data-role="reset-white-label"]` "Reset to Default" button is present. Button is absent in the empty-state page. Conditional rendering verified in source.

Evidence: `.code_my_spec/qa/453/screenshots/02_settings_page_with_saved_config.html`

### Scenario 11 — Reset to Default clears branding (criterion 4156)

**Result: partial — data layer pass, flash text mismatch (app bug)**

`Agencies.reset_white_label_config/2` returned `:ok`. Subsequent `get_white_label_config/2` returns `nil`. BDD spex 4156 fails: app emits `"White-label branding reset to default"` but spec asserts `"Branding reset to default"`.

### Scenario 12 — Settings stored at account level (criterion 4157)

**Result: pass**

BDD spex 4157 passes (1 test, 0 failures). Settings saved by owner persist after LiveView remount. Data is stored in the `white_label_configs` table keyed by `agency_id`. Static HTML confirms all four fields are pre-filled from the database on page load.

### Scenario 13 — No Anderson Analytics branding (criterion 4159)

**Result: partial — no brand text (pass), white-label indicator absent (app bug)**

The text "Anderson Analytics" does not appear anywhere in the `/accounts/settings` HTML (confirmed via grep). The layout conditionally renders `[data-role="agency-logo"]` when a white-label config with a logo_url is loaded via the WhiteLabelHook — correct behavior.

However, the `data-white-label="true"` attribute asserted by BDD spex 4159 (`then_ "the white-label indicator is present confirming branding is active"`) is not rendered anywhere in the layout. BDD spex 4159 fails on this assertion. The WhiteLabelPlug and WhiteLabelHook are wired correctly but the layout emits no `data-white-label` marker attribute.

## Evidence

- `.code_my_spec/qa/453/screenshots/01_settings_page_white_label_section.html` — Settings page empty state: white-label form present, all fields empty, no config saved
- `.code_my_spec/qa/453/screenshots/02_settings_page_with_saved_config.html` — Settings page with seeded config: subdomain/logo/colors pre-filled, reset button visible, DNS verification panel present with "Pending verification" badge

## Issues

### Issue 1 — Flash message text mismatch on save

**Severity: MEDIUM**
**Scope: app**
**Title:** White-label save flash emits "White-label branding saved successfully" instead of "White-label settings saved"

**Description:** When the white-label form is submitted successfully, `AccountLive.Settings` emits `put_flash(:info, "White-label branding saved successfully")`. BDD specs 4152, 4153, 4154, and the save scenario in 4156 all assert `render(context.view) =~ "White-label settings saved"`, which does not match. This causes 4 BDD spec files to fail.

**Reproduction:** Submit `#white-label-form` on `/accounts/settings` as an owner of a team account. Observe flash message.

**Expected:** Flash reads "White-label settings saved".

**Files:** `lib/metric_flow_web/live/account_live/settings.ex` line 424

---

### Issue 2 — Flash message text mismatch on reset

**Severity: MEDIUM**
**Scope: app**
**Title:** White-label reset flash emits "White-label branding reset to default" instead of "Branding reset to default"

**Description:** The `reset_white_label` handler emits `put_flash(:info, "White-label branding reset to default")`. BDD spec 4156 asserts `render(context.view) =~ "Branding reset to default"`.

**Reproduction:** Save a white-label config, then click Reset to Default. Observe flash message.

**Expected:** Flash reads "Branding reset to default".

**Files:** `lib/metric_flow_web/live/account_live/settings.ex` line 446

---

### Issue 3 — `data-white-label` indicator attribute absent from layout

**Severity: LOW**
**Scope: app**
**Title:** Layout does not render `data-white-label="true"` when white-label branding is active

**Description:** BDD spec 4159 asserts that when a page is accessed via an agency subdomain with white-label active, the page contains `[data-white-label='true']` or `[data-white-label]`. The `Layouts.app` component does not render this attribute anywhere. The WhiteLabelHook assigns `white_label_config` to the socket and the layout renders `[data-role="agency-logo"]` and CSS variables, but no element is marked with `data-white-label`.

**Reproduction:** Access any page via an agency subdomain with a matching `WhiteLabelConfig` record. Inspect DOM — no `data-white-label` attribute exists.

**Expected:** An element (e.g., the navbar container) should have `data-white-label="true"` when a white-label config is active.

**Files:** `lib/metric_flow_web/components/layouts.ex` — `app/1` component; no `data-white-label` attribute rendered

---

### Issue 4 — vibium MCP browser tools unavailable in this session

**Severity: HIGH**
**Scope: qa**
**Title:** `mcp__vibium__browser_*` tools are not available; browser automation cannot be used for LiveView testing

**Description:** The QA plan and brief specify vibium MCP tools for browser-based LiveView testing. Calling `mcp__vibium__browser_launch` returned "No such tool available". Form submissions, button clicks (Reset to Default, Verify DNS), and real-time `phx-change` preview could not be tested via actual browser interaction. Testing was conducted via BDD spex (`mix spex`), direct Elixir context function calls (`mix run`), and static curl-captured HTML. All interactive scenarios were covered by the BDD spex suite, but PNG screenshots could not be captured — evidence is saved HTML snapshots instead.

**Expected:** vibium MCP tools should be available in QA agent sessions. `mcp__vibium__browser_launch` should succeed.
