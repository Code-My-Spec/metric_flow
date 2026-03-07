# QA Story Brief

Story 454: Client Views White-labeled Interface

## Tool

web (Vibium MCP browser tools — all routes are LiveView behind `:require_authenticated_user`)

## Auth

Run seeds first (see Seeds section), then launch the browser and log in as the QA owner:

```
mcp__vibium__browser_launch(headless: true)
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll_into_view(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait(selector: "body", timeout: 5000)
```

Credentials:
- Owner: `qa@example.com` / `hello world!`

## Seeds

Run in order. Both scripts are idempotent.

```bash
mix run priv/repo/qa_seeds.exs
mix run priv/repo/qa_seeds_454.exs
```

The story-454 seed script (`priv/repo/qa_seeds_454.exs`) must be created before running tests. It sets up:

- An agency account ("QA Agency 454") with a white-label config (subdomain `qa454brand`, logo URL `https://example.com/qa454-logo.png`, primary color `#FF5733`, secondary color `#33FF57`)
- An `AgencyClientAccessGrant` linking the agency to `qa@example.com`'s "QA Test Account" with `origination_status: :originator`

Write the seed script to `priv/repo/qa_seeds_454.exs` using the same patterns as `priv/repo/qa_seeds_story_431.exs`. Key context functions to use:
- `MetricFlow.Agencies.update_white_label_config/3` — upsert white-label config for an agency account
- `MetricFlow.Agencies.grant_client_account_access/5` — create an `AgencyClientAccessGrant`
- `MetricFlow.Agencies.AgencyClientAccessGrant` schema (fields: `agency_account_id`, `client_account_id`, `access_level`, `origination_status`)

## What To Test

### Scenario 1: Agency white-label config is visible in Account Settings (AC: white-labeling exists)

1. Navigate to `http://localhost:4070/accounts/settings`
2. Verify the page loads and the "White-Label Branding" card is present (`[data-role="agency-white-label"]`)
3. Verify the white-label form shows the saved values: subdomain `qa454brand`, logo URL `https://example.com/qa454-logo.png`, primary color `#FF5733`, secondary color `#33FF57`
4. Verify the DNS Verification panel is visible (`[data-role="dns-verification"]`) since a subdomain is saved
5. Screenshot: `accounts-settings-white-label.png`

### Scenario 2: Client visiting via agency subdomain sees agency branding (AC: agency subdomain shows agency branding)

This scenario tests the subdomain-based branding lookup. The app uses `conn.host` to detect agency subdomains and apply white-label config. Because the browser cannot change the `Host` header directly, this test uses `mcp__vibium__browser_evaluate` to inspect the HTML after modifying the request host via JavaScript or by checking what the server would render.

Since the running dev server is bound to `localhost:4070` and the subdomain routing depends on the `Host` header, test this scenario by:

1. Navigate to `http://localhost:4070/dashboard`
2. Capture the page HTML with `mcp__vibium__browser_get_html()`
3. Check if the page HTML contains `[data-white-label]`, `[data-agency-subdomain]`, or the logo URL `qa454-logo.png` — these would appear if the subdomain detection middleware ran
4. Screenshot: `dashboard-main-domain.png`
5. Note: if the app does not apply white-labeling on `localhost` (expected on main domain), this confirms AC "main domain shows default branding"

### Scenario 3: Main domain shows default MetricFlow branding, not agency branding (AC: main domain default branding)

1. Log in as `qa@example.com` and navigate to `http://localhost:4070/dashboard`
2. Verify the page renders the default logo — look for `img[src*='logo.svg']` or `[data-role='default-logo']` in the header
3. Verify agency branding is NOT present — confirm `qa454-logo.png` does not appear in the HTML and `[data-role='agency-logo']` does not exist
4. Screenshot: `dashboard-default-branding.png`

### Scenario 4: Default branding has no agency color overrides (AC: main domain default branding)

1. On the dashboard page (`http://localhost:4070/dashboard`) verify:
   - `[data-white-label-theme]` is not present in the DOM
   - `[data-agency-colors]` is not present in the DOM
2. Use `mcp__vibium__browser_evaluate` to check:
   ```
   expression: "!!document.querySelector('[data-white-label-theme]') || !!document.querySelector('[data-agency-colors]')"
   ```
   Expected result: `false`
3. Screenshot: `dashboard-no-agency-colors.png`

### Scenario 5: Dashboard functionality is intact — filter controls present (AC: functionality unaffected)

1. Navigate to `http://localhost:4070/dashboard`
2. Verify filter controls are present: `[data-role='platform-filter']`, `[data-role='date-range-filter']`, or text "All Platforms"
3. Verify metrics area is present: `[data-role='metrics-dashboard']`, `[data-role='metrics-area']`, or text "All Metrics"
4. Screenshot: `dashboard-functionality-intact.png`

### Scenario 6: White-label form live preview updates on color input (AC: preview in real-time — from story 453 linked via Settings component)

1. Navigate to `http://localhost:4070/accounts/settings`
2. Clear the primary color field and type `#AA0000`
3. Verify the preview panel appears (`[data-role="white-label-preview"]`)
4. Verify a color swatch shows (a `div` with `style` containing `background-color: #AA0000`)
5. Screenshot: `white-label-live-preview.png`

### Scenario 7: Reset to Default button removes white-label config (AC: functionality works, config is resettable)

1. Navigate to `http://localhost:4070/accounts/settings`
2. Verify the "Reset to Default" button is visible (`[data-role="reset-white-label"]`) since a config exists
3. Click the Reset to Default button
4. Verify a success flash message appears (e.g., text containing "reset" or the form clears)
5. Screenshot: `white-label-reset.png`
6. Re-run seeds (`mix run priv/repo/qa_seeds_454.exs`) to restore the config for any subsequent tests

### Scenario 8: Unauthenticated user on any domain is redirected to login (AC: unauthenticated access)

1. Clear cookies: `mcp__vibium__browser_delete_cookies()`
2. Navigate to `http://localhost:4070/dashboard`
3. Verify redirect to `/users/log-in`
4. Screenshot: `unauthenticated-redirect.png`

## Setup Notes

The white-label branding feature is configured at the agency (team account) level via `MetricFlow.AgencyLive.Settings`, which renders as a function component within `AccountLive.Settings` at `/accounts/settings`. The component is only shown to users with `owner` or `admin` role on a team account.

The BDD specs simulate subdomain-based branding by manipulating `conn.host` in unit tests. In browser-based QA, the running dev server listens on `localhost:4070` — there is no real subdomain routing active unless the server is configured with a wildcard host or the `Host` header is overridden. As a result:

- Scenarios testing "client sees agency branding via subdomain" confirm the UI infrastructure is in place (white-label config saved, `data-role` attributes present in settings) rather than testing actual subdomain DNS routing
- Scenarios testing "main domain shows default branding" are fully testable via the browser

If the app has a Plug that reads `conn.host` to look up white-label config (e.g., a `WhiteLabelPlug`), document whether it is wired into the router. If it is, the subdomain branding test can be performed by setting a `Host` header override via JavaScript or by checking what the AccountLive.Settings page shows as the currently saved subdomain.

## Result Path

`.code_my_spec/qa/454/result.md`
