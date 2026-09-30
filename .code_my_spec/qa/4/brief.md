# Qa Story Brief

Story 4: Agency Team Auto-Enrollment

## Tool

web

## Auth

Use `run_browser_script` with the standard `browser_*` tools. Log in as the seeded QA owner via the password form:

```lua
browser_delete_cookies({})
browser_navigate({ url = "http://127.0.0.1:59302/users/log-in" })
browser_wait_for_load({})
browser_scroll_into_view({ selector = "#login_form_password" })
browser_fill({ selector = "#password_email", text = "qa@example.com" })
browser_fill({ selector = "#user_password", text = "hello world!" })
browser_click({ selector = "#login_form_password button[name='user[remember_me]']" })
browser_wait_for_url({ pattern = "/", timeout = 8000 })
```

For the non-admin visibility check, `browser_delete_cookies` then repeat with `qa-member@example.com` / `hello world!` (seeded `read_only` on the same account).

App base URL: `http://127.0.0.1:59302` — this worktree's current dev server instance (port reassigned after a harness restart earlier this session; confirmed serving commit e1ede35d). Ignore the task prompt's URL if it differs from this by the time testing starts — re-derive it the same way (`lsof`/`ps` for this worktree's `mix phx.server`).

## Seeds

Seeds already in place. `qa@example.com` is `owner` of "QA Test Account" (a `team` account, satisfying the auto-enrollment section's visibility gate). `qa-member@example.com` is `read_only` on the same account.

**Critical environment note carried over from stories 13/15:** this worktree's dev server reads database `metric_flow_dev_wc_bd0baac8`, not the default `metric_flow_dev`. Any `mix run -e` shell must `export DATABASE_NAME=metric_flow_dev_wc_bd0baac8` first.

All domain values used below are fresh, timestamp-suffixed strings chosen specifically to avoid colliding with any domain a previous QA pass may have already configured (auto-enrollment rules and registered users are both consumable, one-shot state — a domain claimed once can't be reclaimed by a different "first configure" test). Record whichever exact domain strings get used in the attempt's scenario observations.

## What To Test

- **Visibility gating** — As qa@example.com (owner), `/app/accounts/settings` shows the `data-role="agency-auto-enrollment"` card. As qa-member@example.com (read_only), the same page does not show it.
- **23/588: configure domain-based auto-enrollment** — Submit `#auto-enrollment-form` with a fresh domain (e.g. `qa4owner<ts>.example`) and Default Access Level = Account Manager. Expect a success flash and the status row to show the domain with an `.badge-success` "Active" badge and a `[data-role="disable-auto-enrollment"]` button.
- **589: domain already claimed by another agency is rejected** — Register a second, fresh agency account (account_type=agency) via `/users/register`, log in as it, configure auto-enrollment for that same domain the first agency just claimed. Expect the form to re-render with a validation error mentioning the domain is already taken/in use, and no second rule created.
- **24/590/592: matching-domain registrant is auto-enrolled at the configured access level** — Register a brand-new user (`/users/register`, no login) with an email on the exact configured domain (e.g. `newmember@qa4owner<ts>.example`). Then, back in the owner's session, visit `/app/accounts/members` and confirm the new user appears with the Account Manager role that was configured.
- **591: subdomain registrant is not auto-enrolled** — Register another new user on a *subdomain* of the configured domain (e.g. `sub@team.qa4owner<ts>.example`). Confirm this user does NOT appear on `/app/accounts/members`.
- **26/593: agency admin views and manages auto-enrolled team members** — Confirm the criterion above's members list view itself satisfies this (no separate UI beyond the existing Members page is expected).
- **27/594: agency admin disables auto-enrollment** — Click `[data-role="disable-auto-enrollment"]`. Expect a success flash, the badge to change to `.badge-ghost` "Disabled", and the Disable button to disappear. Then register one more fresh user on the same domain and confirm they are NOT auto-enrolled (disabling actually stops future enrollment).
- **28/595: auto-enrolled member inherits access to all agency client accounts** — Check whether "QA Test Account" already has any client accounts that granted it agency access (via that client's own `/app/accounts/settings` → Agency Access section, or by asking whether such a fixture already exists). If none exist and setting one up safely isn't quick, verify this criterion via the passing `criterion_595` BDD spex instead and say so explicitly in the observation rather than skipping it silently.

## Result Path

.code_my_spec/qa/4/screenshots/

## Execution Notes

`QA Test Account` (the base seeded team account) turned out to be `account_type: client`, not `agency` -- the Auto-Enrollment/White-Label section is gated on agency-type accounts specifically (confirmed by the visible "Account Type" dropdown on its own settings page), not merely "any team account" as the component moduledoc's wording suggests. Registered a fresh agency-type owner (`qa4owner20260930@example.com`) instead, and a second fresh agency (`qa4second20260930@example.com`) for the domain-collision scenario. Both needed dev-mailbox confirmation-link handling identical to prior stories' registration flow.

Domain used throughout: `qa4owner20260930.example` (fresh, timestamp-suffixed, consumed by this pass -- a future pass must pick a new one). Registrants used: `newmatch@` (exact domain, expect enrolled), `subuser@team.` (subdomain, expect not enrolled), `afterdisable@` (registered after disabling, expect not enrolled).

## Setup Notes

Results are recorded via `submit_qa_result` (a DB-backed attempt) plus `create_issue` for findings — there is no `result.md` file; the path above is where screenshot evidence is saved.
