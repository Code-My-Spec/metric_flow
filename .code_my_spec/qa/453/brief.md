# QA Story Brief

Story 453: Agency White-label Configuration

## Tool

web (vibium MCP browser tools — LiveView page at `/accounts/settings`)

## Auth

Log in as the agency owner using the password form:

```
mcp__vibium__browser_launch(headless: true)
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll_into_view(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait(selector: "body", timeout: 5000)
```

## Seeds

The base seeds create a team account (`"QA Test Account"`) with `qa@example.com` as owner. The white-label section only renders for team accounts with an owner or admin role, so the seeded user is the correct test user.

```bash
mix run priv/repo/qa_seeds.exs
```

Run with `dangerouslyDisableSandbox: true` — the CloudflareTunnel supervisor writes to `~/.cloudflared/config.yml` on startup, which the sandbox blocks.

No additional seed scripts are required for this story.

## Setup Notes

The white-label configuration section (`[data-role="agency-white-label"]`) renders inside `/accounts/settings` only when:
- The active account type is `"team"` (the QA seed account satisfies this)
- The current user holds an `owner` or `admin` role (qa@example.com is the owner)

**Important flash message discrepancy:** The source code (`AccountLive.Settings`) emits the flash `"White-label branding saved successfully"` on a successful save, and `"White-label branding reset to default"` on reset. The BDD specs assert `"White-label settings saved"` and `"Branding reset to default"` respectively. These will not match. Document these as app-level bugs if the flash text does not match the spec assertions.

The DNS verification panel (`[data-role="dns-verification"]`) only appears after a subdomain has been saved and a `WhiteLabelConfig` record exists with a non-empty subdomain. It will not appear for a new form submission until the page re-renders with the persisted config.

The Reset to Default button (`[data-role="reset-white-label"]`) only renders when `@white_label_config` is non-nil — i.e., after a successful save.

The live preview panel (`[data-role="white-label-preview"]`) only appears when the primary or secondary color fields have non-empty values in the current form params — it responds to `phx-change="validate_white_label"` (form change events), not to saved state.

## What To Test

### Scenario 1 — White-Label Branding section is visible (criterion 4152, 4153, 4154)

- Navigate to `http://localhost:4070/accounts/settings`
- Verify the text "White-Label Branding" is present on the page
- Verify the form `#white-label-form` is present
- Verify `#white-label-form input[name='white_label[logo_url]']` is present
- Verify `#white-label-form input[name='white_label[primary_color]']` is present
- Verify `#white-label-form input[name='white_label[secondary_color]']` is present
- Verify `#white-label-form input[name='white_label[subdomain]']` is present
- Verify the subdomain helper text "Lowercase letters, numbers, and hyphens only" is visible
- Capture screenshot: `01_settings_page_white_label_section.png`

### Scenario 2 — Save with PNG logo URL (criterion 4152)

- Navigate to `http://localhost:4070/accounts/settings`
- Fill `input[name='white_label[subdomain]']` with `agency-png-test`
- Fill `input[name='white_label[logo_url]']` with `https://cdn.example.com/logo.png`
- Fill `input[name='white_label[primary_color]']` with `#FF5733`
- Fill `input[name='white_label[secondary_color]']` with `#3498DB`
- Click the "Save Branding" submit button
- Wait for page update
- Verify a success flash message appears (expected: "White-label branding saved successfully")
- Verify the logo URL `https://cdn.example.com/logo.png` is reflected in the page (pre-filled in the input)
- Capture screenshot: `02_save_png_logo_url.png`

### Scenario 3 — Save with JPG logo URL (criterion 4152)

- Navigate to `http://localhost:4070/accounts/settings`
- Fill the white-label form with `https://cdn.example.com/brand-logo.jpg` as logo URL, a unique subdomain, and valid color values
- Submit the "Save Branding" button
- Verify a success flash message appears
- Verify `https://cdn.example.com/brand-logo.jpg` is reflected in the page
- Capture screenshot: `03_save_jpg_logo_url.png`

### Scenario 4 — Save with SVG logo URL (criterion 4152)

- Navigate to `http://localhost:4070/accounts/settings`
- Fill the white-label form with `https://cdn.example.com/vector-logo.svg` as logo URL, a unique subdomain, and valid color values
- Submit the "Save Branding" button
- Verify a success flash message appears
- Verify `https://cdn.example.com/vector-logo.svg` is reflected in the page
- Capture screenshot: `04_save_svg_logo_url.png`

### Scenario 5 — Save custom color scheme (criterion 4153)

- Navigate to `http://localhost:4070/accounts/settings`
- Fill the white-label form: primary color `#3498DB`, secondary color `#2ECC71`, unique subdomain, empty logo URL
- Submit the "Save Branding" button
- Verify success flash appears
- Verify `#3498DB` and `#2ECC71` are both reflected in the page (pre-filled in inputs after save)
- Capture screenshot: `05_save_color_scheme.png`

### Scenario 6 — Real-time preview before saving (criterion 4155)

- Navigate to `http://localhost:4070/accounts/settings`
- Change (but do not submit) the primary color field to `#E74C3C` — trigger a change event (type into the input)
- Verify the page shows `#E74C3C` in the live preview panel (`[data-role="white-label-preview"]`) before the form is submitted
- Verify no success flash message is shown yet
- Also change the secondary color to `#9B59B6` without submitting
- Verify `#9B59B6` appears in the preview panel
- Capture screenshot: `06_live_preview_before_save.png`

### Scenario 7 — Save custom subdomain (criterion 4154)

- Navigate to `http://localhost:4070/accounts/settings`
- Fill subdomain with `reports-andersonthefish`, leave logo URL empty, set valid colors
- Submit the "Save Branding" button
- Verify success flash appears
- Verify `reports-andersonthefish` appears in the page (pre-filled in subdomain input)
- Capture screenshot: `07_save_subdomain.png`

### Scenario 8 — Subdomain persistence on page revisit (criterion 4154, 4157)

- After saving `reports-andersonthefish` (Scenario 7 or a fresh save), navigate away and return to `http://localhost:4070/accounts/settings`
- Verify the subdomain input is pre-filled with the previously saved value
- Capture screenshot: `08_subdomain_persists_on_revisit.png`

### Scenario 9 — DNS verification section after subdomain save (criterion 4158)

- After saving a subdomain (e.g., `reports-myagency`), verify the DNS verification panel appears:
  - `[data-role="dns-verification"]` is present
  - Text "DNS Verification Required" is visible
  - The saved subdomain value is shown in the DNS instructions
  - Text containing "verif" is present (e.g., "Pending verification")
  - A "Verify DNS" button (`[data-role="verify-dns"]`) is present
  - The subdomain status badge shows "Pending verification" (not "Active")
- Capture screenshot: `09_dns_verification_section.png`

### Scenario 10 — Reset to Default button visibility (criterion 4156)

- After saving any white-label settings, verify the `[data-role="reset-white-label"]` button ("Reset to Default") is visible
- Capture screenshot: `10_reset_button_visible.png`

### Scenario 11 — Reset to Default clears branding (criterion 4156)

- Starting from a state where white-label settings are saved (logo URL, colors, subdomain all set)
- Click the `[data-role="reset-white-label"]` button
- Wait for page update
- Verify a success flash message appears (expected: "White-label branding reset to default")
- Verify the saved logo URL no longer appears in the page
- Verify the saved subdomain no longer appears in the form inputs
- Verify the saved color values no longer appear in the form inputs
- Verify the Reset to Default button is no longer visible (config is nil)
- Capture screenshot: `11_after_reset_to_default.png`

### Scenario 12 — Settings stored at account level (criterion 4157)

- Save white-label settings as `qa@example.com` (logo URL `https://cdn.agencytest.com/stored-logo.png`, subdomain `storedagency`, colors `#AA1122` / `#334455`)
- Navigate away to `/accounts` then back to `/accounts/settings`
- Verify all four saved values are pre-filled in the form
- Capture screenshot: `12_settings_persist_across_navigation.png`

### Scenario 13 — No Anderson Analytics branding on white-labeled access (criterion 4159)

- Check the current page at `/accounts/settings` (on the main domain)
- Verify the page does not contain the text "Anderson Analytics"
- Check the dashboard at `/dashboard` (on the main domain)
- Verify the page does not contain the text "Anderson Analytics"
- Capture screenshot: `13_no_anderson_analytics_branding.png`

## Result Path

`.code_my_spec/qa/453/result.md`
