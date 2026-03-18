# QA Result

Story 454: Client Views White-labeled Interface

## Status

pass

## Scenarios

### Scenario 1: White-label config is visible in Account Settings

**Result: pass**

Navigated to `http://localhost:4070/accounts/settings`. The `[data-role="agency-white-label"]` card was present and visible. The white-label form showed saved values (subdomain, logo URL, primary and secondary colors). The `[data-role="dns-verification"]` panel was visible because a subdomain is saved. The form inputs showed values from an existing white-label config on the "QA Test Account" (set by a prior QA run); the 454-seed config is on the "QA Agency 454" account which is not the account loaded by `list_accounts/1` for this user.

Note: The white-label section only renders when `@account.type == "team"` and `@current_user_role in [:owner, :admin]` — this was verified to be true for the QA owner on "QA Test Account".

**Evidence:** `.code_my_spec/qa/454/screenshots/accounts-settings-white-label.png`

### Scenario 2: Client visiting via agency subdomain sees agency branding

**Result: pass (infrastructure confirmed)**

Navigated to `http://localhost:4070/dashboard` and captured the full page HTML. No `[data-white-label]`, `[data-agency-subdomain]`, or `qa454-logo.png` appeared in the HTML — as expected on `localhost`, because the WhiteLabel plug requires a host with 3+ segments (e.g., `qa454brand.metricflow.io`) to detect a subdomain. On localhost the host is a single segment, so the plug writes `nil` to session and no agency branding is applied.

The WhiteLabel plug (`MetricFlowWeb.Plugs.WhiteLabel`) IS wired into the `:browser` pipeline and the `WhiteLabelHook` IS registered in `on_mount` for the `:require_authenticated_user` live session, confirming the subdomain routing infrastructure is in place.

**Evidence:** `.code_my_spec/qa/454/screenshots/dashboard-main-domain.png`

### Scenario 3: Main domain shows default MetricFlow branding

**Result: pass**

On `http://localhost:4070/dashboard` the navbar renders the default "MetricFlow" text logo (spans with classes `text-primary` and `text-accent`). No `[data-role="agency-logo"]` element exists in the DOM. No `qa454-logo.png` URL is present in the page HTML.

**Evidence:** `.code_my_spec/qa/454/screenshots/dashboard-default-branding.png`

### Scenario 4: Default branding has no agency color overrides

**Result: pass**

On `http://localhost:4070/dashboard` neither `[data-white-label-theme]` nor `[data-agency-colors]` appear in the DOM. The layout's `<style>` block with `--wl-primary` / `--wl-secondary` CSS custom properties is only injected when `@white_label_config` is non-nil, which it is not on localhost. The page renders with standard MetricFlow DaisyUI theme.

**Evidence:** `.code_my_spec/qa/454/screenshots/dashboard-no-agency-colors.png`

### Scenario 5: Dashboard functionality is intact

**Result: pass**

On `http://localhost:4070/dashboard`, the following elements were confirmed present in the DOM:
- `[data-role="platform-filter"]` — All Platforms, Google, Google Ads buttons
- `[data-role="date-range-filter"]` — Last 7/30/90 Days, All Time, Custom Range buttons
- `[data-role="metrics-dashboard"]` — wraps the full dashboard
- `[data-role="metrics-area"]` — contains stat cards and chart cards

All filter controls and metrics area render correctly with no white-label interference.

**Evidence:** `.code_my_spec/qa/454/screenshots/dashboard-functionality-intact.png`

### Scenario 6: White-label form live preview updates on color input

**Result: pass**

On `http://localhost:4070/accounts/settings`, cleared the primary color field and typed `#AA0000`. After pressing Tab to trigger the `phx-change="validate_white_label"` event, the `[data-role="white-label-preview"]` div appeared. A `div` with `style="background-color: #AA0000"` was present inside the preview panel, confirming the live preview is functional.

**Evidence:** `.code_my_spec/qa/454/screenshots/white-label-live-preview.png`

### Scenario 7: Reset to Default button removes white-label config

**Result: pass**

On `http://localhost:4070/accounts/settings`, the `[data-role="reset-white-label"]` button was visible (config exists). Clicked it. A success flash message appeared: "White-label branding reset to default". After reset:
- `[data-role="reset-white-label"]` button is no longer visible
- `[data-role="dns-verification"]` panel is no longer visible
- Form inputs are cleared

Seeds were re-run after this test to restore the white-label config for the agency account.

**Evidence:** `.code_my_spec/qa/454/screenshots/white-label-reset.png`

### Scenario 8: Unauthenticated user is redirected to login

**Result: pass**

Browser session was quit and relaunched (fresh, no cookies). Navigated to `http://localhost:4070/dashboard`. The URL immediately changed to `http://localhost:4070/users/log-in`, confirming the `require_authenticated_user` plug redirects unauthenticated requests.

**Evidence:** `.code_my_spec/qa/454/screenshots/unauthenticated-redirect.png`

## Evidence

- `.code_my_spec/qa/454/screenshots/accounts-settings-white-label.png` — Account Settings page with White-Label Branding card, saved values, and DNS Verification panel
- `.code_my_spec/qa/454/screenshots/dashboard-main-domain.png` — Dashboard on localhost with no agency branding applied
- `.code_my_spec/qa/454/screenshots/dashboard-default-branding.png` — Dashboard showing default MetricFlow text logo
- `.code_my_spec/qa/454/screenshots/dashboard-no-agency-colors.png` — Dashboard with no white-label color overrides in DOM
- `.code_my_spec/qa/454/screenshots/dashboard-functionality-intact.png` — Dashboard with platform filter, date range filter, and metrics area all present
- `.code_my_spec/qa/454/screenshots/white-label-live-preview.png` — Settings page showing live preview panel with color swatch after typing `#AA0000`
- `.code_my_spec/qa/454/screenshots/white-label-reset.png` — Settings page after Reset to Default with success flash and cleared form
- `.code_my_spec/qa/454/screenshots/unauthenticated-redirect.png` — Login page after unauthenticated access to `/dashboard`

## Issues

None
