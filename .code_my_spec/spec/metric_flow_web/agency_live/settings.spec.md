# MetricFlowWeb.AgencyLive.Settings

Agency configuration: auto-enrollment, white-label. A function component module rendered within the `/accounts/settings` page. Renders two configuration cards — auto-enrollment and white-label branding — conditionally for team account owners and admins.

## Type

liveview

## Route

`/accounts/settings`

## Params

None

## Dependencies

- MetricFlow.Agencies
- MetricFlow.Agencies.AutoEnrollmentRule
- MetricFlow.Agencies.WhiteLabelConfig

## Components

None

## User Interactions

- **phx-submit="save_auto_enrollment"**: Submit the auto-enrollment form with domain and default access level. Calls `Agencies.configure_auto_enrollment/3`. On success, flash "Auto-enrollment enabled" and reload the rule. On validation error, re-render with inline field errors.
- **phx-click="disable_auto_enrollment"**: Disable the active auto-enrollment rule. Calls `Agencies.configure_auto_enrollment/3` with `enabled: false`. On success, flash "Auto-enrollment disabled" and reload the rule. Status badge updates from Active to Disabled and the Disable button is hidden.
- **phx-submit="save_white_label"**: Submit the white-label branding form with subdomain, logo URL, and color values. Calls `Agencies.update_white_label_config/3`. On success, flash "White-label settings saved" and reload the config. On validation error, re-render with inline field errors.
- **phx-change="validate_white_label"**: Live-validate white-label form inputs as the user types. Updates the live color preview panel when primary or secondary color fields contain non-empty values.
- **phx-click="reset_white_label"**: Delete the white-label branding config. Calls `Agencies.reset_white_label_config/2`. On success, clear the form and reload.
- **phx-click="verify_dns"**: Trigger DNS verification for the configured subdomain. Shown only when a subdomain is saved. Updates verification status badge.

## Design

Layout: Two stacked cards rendered inside the parent `/accounts/settings` page. Both cards are visible only when the active account is a team account and the current user holds an `owner` or `admin` role. Both are hidden for `read_only` and `account_manager` roles, and for personal accounts.

**Auto-Enrollment card** (`data-role="agency-auto-enrollment"`):
- Section header: "Auto-Enrollment"
- Description text: explains domain-based automatic team membership
- Status row (shown only when a rule exists): email domain label, Active/Disabled badge, Disable button (enabled rules only)
  - Active rule: `.badge-success` "Active" + `[data-role="disable-auto-enrollment"]` button
  - Disabled rule: `.badge-ghost` "Disabled", no Disable button
- Form (`id="auto-enrollment-form"`, `phx-submit="save_auto_enrollment"`):
  - Email Domain input (`[data-role="auto-enrollment-domain-input"]`), pre-filled from existing rule or empty, placeholder "e.g., myagency.com", `.input-error` class on validation failure
  - Default Access Level select (`[data-role="auto-enrollment-default-role"]`) with options: Read Only, Account Manager, Admin; defaults to Read Only
  - Submit button: "Enable Auto-Enrollment"

**White-Label Branding card** (`data-role="agency-white-label"`):
- Section header: "White-Label Branding"
- Description text: explains client-facing branding customization
- Live preview panel (`[data-role="white-label-preview"]`, shown only when primary or secondary color fields are non-empty): color swatches and hex value labels
- Form (`id="white-label-form"`, `phx-submit="save_white_label"`, `phx-change="validate_white_label"`):
  - Subdomain input (`name="white_label[subdomain]"`), monospace font, hint "Lowercase letters, numbers, and hyphens only (3–63 characters)"
  - Logo URL input (`name="white_label[logo_url]"`)
  - Primary Color input (`name="white_label[primary_color]"`), monospace font, placeholder "#RRGGBB"
  - Secondary Color input (`name="white_label[secondary_color]"`), monospace font, placeholder "#RRGGBB"
  - Reset to Default button (`[data-role="reset-white-label"]`, `phx-click="reset_white_label"`), shown only when a config exists
  - Submit button: "Save Branding"
- DNS Verification panel (`[data-role="dns-verification"]`, shown only when a subdomain is saved):
  - Header: "DNS Verification Required"
  - Instructions to create a CNAME record pointing to `app.metricflow.io`
  - `.badge-warning` "Pending verification" status badge
  - Verify DNS button (`[data-role="verify-dns"]`, `phx-click="verify_dns"`)

Components: `.card`, `.card-body`, `.card-title`, `.badge-success`, `.badge-ghost`, `.badge-warning`, `.form-control`, `.input`, `.input-error`, `.select`, `.btn-primary`, `.btn-ghost`, `.btn-sm`
Responsive: Submit buttons stack full-width on mobile, shrink to auto on `sm:` breakpoint

## Test Assertions

- renders auto-enrollment and white-label cards for team account owners
- hides agency settings cards for non-owner/admin roles and personal accounts
- enables auto-enrollment with domain and access level and shows success flash
- shows validation errors on auto-enrollment form with invalid data
- disables active auto-enrollment rule and updates status badge
- saves white-label branding settings and shows success flash
- shows validation errors on white-label form with invalid data
- live-validates white-label fields and shows color preview
- resets white-label config to default on reset click
- shows DNS verification panel when subdomain is saved
