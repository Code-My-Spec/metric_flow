# Qa Story Brief

Story 30: Agency White-label Configuration

## Tool

web

## Auth

Use `run_browser_script` with the standard `browser_*` tools. Reuse the fresh agency owner created during story 4's QA pass this session (still live on this checkout): `qa4owner20260930@example.com` / `SecurePassword123!`, owner of an agency-type team account.

```lua
browser_delete_cookies({})
browser_navigate({ url = "http://127.0.0.1:59302/users/log-in" })
browser_wait_for_load({})
browser_scroll_into_view({ selector = "#login_form_password" })
browser_fill({ selector = "#password_email", text = "qa4owner20260930@example.com" })
browser_fill({ selector = "#user_password", text = "SecurePassword123!" })
browser_click({ selector = "#login_form_password button[name='user[remember_me]']" })
browser_wait_for_url({ pattern = "/", timeout = 8000 })
```

White-label settings live on `/app/accounts/settings` alongside the auto-enrollment and agency-access sections tested in stories 4/8.

App base URL: `http://127.0.0.1:59302` -- re-derive via `lsof`/`ps` if changed.

## Seeds

No new base seeds needed beyond the agency account from story 4's pass. All white-label field values below are fresh/timestamp-suffixed where uniqueness matters (subdomain), since a subdomain is a one-shot claim (`has already been taken` on reuse) -- consumed once tested, pick a new one for any future pass.

**Critical environment note carried over from stories 13/15/8/18/33 this session:** this worktree's dev server reads database `metric_flow_dev_wc_bd0baac8`, not the default `metric_flow_dev`. Any `mix run -e` shell must `export DATABASE_NAME=metric_flow_dev_wc_bd0baac8` first.

**Environment blocker found and cleared before this pass:** the checkout was serving `Phoenix.Ecto.PendingMigrationError` (503) on every request at the start of this session -- one migration (`20260930000000_add_accent_color_to_white_label_configs`, part of this story's own feature) had never been run against this database. Fixed by running `DATABASE_NAME=metric_flow_dev_wc_bd0baac8 mix ecto.migrate`; filed as issue 61f6b4f9 (qa scope). If this recurs, re-run that migrate command before assuming a new regression.

## What To Test

- **735/250: agency uploads a supported logo format** -- Submit `#white-label-form` with `logo_url` ending in `.png` (or `.jpg`/`.svg`), a fresh subdomain, and primary/secondary colors. Confirm a "White-label settings saved" flash and the logo URL persists in the field.
- **736: unsupported logo file type is rejected** -- Submit the same form with `logo_url` ending in `.exe` (or another non-image extension). Confirm no success flash and an inline validation error ("is invalid"/"must be"/"unsupported").
- **737/251: agency sets a custom color scheme** -- Submit primary, secondary, and accent colors (hex values). Confirm all three persist as the saved values in their respective fields after submit.
- **740/253: changes preview in real-time before saving** -- Without submitting, type into the primary/secondary color inputs (triggers `phx-change="validate_white_label"`) and confirm `[data-role="white-label-preview"]` appears showing swatches/hex text matching the in-progress (unsaved) values.
- **738/252: agency configures a custom subdomain** -- Submit a fresh subdomain with colors. Confirm `[data-role="dns-verification"]` appears showing the subdomain with a `.badge-warning` "Pending" badge (not verified yet), and no `.badge-success`.
- **739: subdomain already claimed by another agency is rejected** -- As the story-4 agency owner, claim a fresh subdomain. Then register a second fresh agency account and, logged in as it, attempt to configure the *same* subdomain. Confirm a "has already been taken" validation error and no change to the first agency's claim.
- **741/254: agency resets to default branding** -- With logo/colors/subdomain configured, click `[data-role="reset-white-label"]`. Confirm the subdomain and logo URL disappear from the page, the reset button itself disappears, and `[data-role="dns-verification"]` is no longer shown.
- **255/742: white-label settings stored/apply at agency account level** -- Not independently re-verified with a second team member's session in this pass (would require a second seeded member on the same agency account); the `WhiteLabelConfig` schema's `agency_id` foreign key and the settings LiveView loading by `current_scope`'s active account is verifiable via code review, and criterion 742's own BDD spex passes. Note as code-review-backed if not exercised live.
- **256/743/744/745: DNS verification gates white-label activation, no Anderson Analytics branding once active** -- These require serving a request with a `Host` header matching the configured subdomain (`<subdomain>.metricflow.io` per the BDD fixtures), which a normal browser navigation to `127.0.0.1:59302` cannot exercise directly (no DNS entry routes that hostname here). Verify via the passing BDD spex (`criterion_743`, `criterion_744`, `criterion_745`) and a code read of how the plug/LiveView resolves the active account from `conn.host` before falling back to Anderson Analytics defaults, rather than a live repro. Say so explicitly in the observation.

## Result Path

.code_my_spec/qa/30/screenshots/

## Setup Notes

Results are recorded via `submit_qa_result` (a DB-backed attempt) plus `create_issue` for findings -- there is no `result.md` file; the path above is where screenshot evidence is saved.

## Results

- 735/250, 737/251: pass. A PNG logo, subdomain, and primary/secondary/accent colors all submitted successfully with a "White-label settings saved" flash; all five values persisted correctly in their fields after save (verified via browser_get_value, not just visible text).
- 740/253: pass. Typing into primary/secondary color fields (unsaved) immediately shows `[data-role="white-label-preview"]` with matching swatches/hex text, before any submit.
- 738/252: pass. Submitting a fresh subdomain shows `[data-role="dns-verification"]` with a `.badge-warning` "Pending" state and no `.badge-success`.
- 736: pass. Submitting a `.exe` logo URL is rejected with an inline "must be a PNG, JPG, or SVG image file" error and no success flash; the invalid value is not persisted (confirmed empty on fresh reload).
- 739: pass. A second, independently-registered agency attempting the first agency's already-claimed subdomain is rejected with "has already been taken" (verified after correcting a timing artifact in the test script -- an initial attempt without a post-navigation settle delay produced a stale "can't be blank" result instead, from filling the input before the LiveView socket had reconnected).
- 741/254: pass. Clicking "Reset to Default" removes the reset button and the DNS-verification section immediately, and a fresh page reload confirms the subdomain and logo URL fields are genuinely empty (not just visually cleared) -- the underlying `WhiteLabelConfig` was actually deleted/nilled, not just hidden.
- 255/742 (settings stored/apply at agency account level): pass (code-review-backed). Not independently re-verified with a second team member's session in this pass; `WhiteLabelConfig` has an `agency_id` foreign key scoping it to the account, matching the passing BDD spex for this criterion.
- 256/743/744/745 (DNS-gated activation, no Anderson Analytics branding on a verified white-labeled instance): pass (code-review + BDD-spex-backed, not live-reproduced). These require serving a request with a `Host` header matching the configured subdomain, which a normal browser navigation to `127.0.0.1:59302` in this environment cannot exercise (no DNS routes that hostname here). All three BDD specs (`criterion_743`, `744`, `745`) pass in the exunit suite and exercise exactly this via a spoofed `conn.host`.

## Discovered during this pass, unrelated to story 30 itself

`AccountLive.Settings` resolves the account to show via `ActiveAccountHook.primary_account(accounts)`, not necessarily the account most recently switched to via `/app/accounts` -- this caused an early false negative in this pass (qa4owner's own agency settings were hidden behind "QA Test Account", a client account they also have agency-derived membership on from story 8's testing, even though /app/accounts correctly reported the agency account as "Active"). Worked around by testing with a brand-new, single-account agency owner instead. Not filed as a new issue since this exact quirk was already noted as an open question during story 8's QA pass this session and doesn't block any of story 30's own criteria once accounted for -- but future QA passes touching `/app/accounts/settings` for a multi-membership user should be aware of it.
