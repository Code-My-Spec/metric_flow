# Qa Story Brief

Story 13: View and Manage Platform Integrations

## Tool

web

## Auth

Use `run_browser_script` with the standard `browser_*` tools. Log in as the seeded QA owner via the password form:

```lua
browser_navigate({ url = "http://localhost:4070/users/log-in" })
browser_wait_for_load({})
browser_scroll_into_view({ selector = "#login_form_password" })
browser_fill({ selector = "#password_email", text = "qa@example.com" })
browser_fill({ selector = "#user_password", text = "hello world!" })
browser_click({ selector = "#login_form_password button[name='user[remember_me]']" })
browser_wait_for_url({ pattern = "/", timeout = 8000 })
```

App base URL: `http://localhost:4070` (this worktree's own dev server; confirmed live and rendering real integration data while writing this brief, so despite the task prompt's "erroring" note, testing proceeds against this copy rather than main's preview).

## Seeds

Seeds are already in place — logging in as `qa@example.com` / `hello world!` lands on "QA Test Account", which already has all six platforms connected (Google Analytics, Google Ads, Google Search Console, Google Business, Facebook Ads, QuickBooks), confirmed live before writing this brief. Do not re-run `mix run priv/repo/qa_seeds.exs` unless login fails.

For the error/revoked-access scenarios (criteria 571, 574, 578), none of the seeded integrations are expired, so one needs to be expired directly. Use Google Search Console (not otherwise exercised by a scenario below) as the disposable target, and restore it afterward so later scenarios that assume a healthy connection still work:

Expire it:
```bash
mix run --no-start -e 'Application.ensure_all_started(:postgrex); Application.ensure_all_started(:ecto); MetricFlow.Repo.start_link([]); user = MetricFlow.Users.get_user_by_email("qa@example.com"); import Ecto.Query; from(i in MetricFlow.Integrations.Integration, where: i.user_id == ^user.id and i.provider == :google_search_console) |> MetricFlow.Repo.update_all(set: [expires_at: DateTime.add(DateTime.utc_now(), -3600, :second) |> DateTime.truncate(:second)])'
```

Restore it after those scenarios are done (pick any future expiry, e.g. 30 days out):
```bash
mix run --no-start -e 'Application.ensure_all_started(:postgrex); Application.ensure_all_started(:ecto); MetricFlow.Repo.start_link([]); user = MetricFlow.Users.get_user_by_email("qa@example.com"); import Ecto.Query; from(i in MetricFlow.Integrations.Integration, where: i.user_id == ^user.id and i.provider == :google_search_console) |> MetricFlow.Repo.update_all(set: [expires_at: DateTime.add(DateTime.utc_now(), 2592000, :second) |> DateTime.truncate(:second)])'
```

This mutation is consumable exactly like a repro input: once expired and observed, restore it before moving on so later scenarios (and any retest) see the account's normal healthy state, not a leftover error badge.

## What To Test

- **93/569** — Navigate to `/app/integrations`. Confirm the connected list shows every platform type together (marketing: Google Analytics/Ads/Search Console/Business, Facebook Ads; financial: QuickBooks) with no separation or special-casing.
- **94/570** — For each connected card, confirm platform name, a "Connected as ... via ... on YYYY-MM-DD" date line, and a status badge (Connected/error) plus a sync-status region are all present.
- **95/572** — Confirm each connected card shows its selected account/property/income-account identifier (e.g. `properties/...`, a numeric ads account id, a site URL, an income account id) or "No accounts selected" when none chosen.
- **96/573/97/575** — deferred to code-path checks below; also confirm "Edit Accounts" link navigates to `/app/integrations/connect/{provider}/accounts` without any re-authentication prompt (no redirect to an OAuth URL).
- **571** — After expiring the Google Search Console integration (see Seeds), reload `/app/integrations` and confirm its card shows `data-status="error"` with the "Connection error — reconnect required" badge instead of "Connected".
- **574** — With Google Search Console still expired, navigate directly to `/app/integrations/connect/google_search_console/accounts` and confirm the page does not offer a normal save-selection control and instead prompts to reconnect (or redirects to a connect flow).
- **97/575** — Click "Disconnect" on a connected platform (e.g. Facebook Ads), confirm the confirmation modal (`data-role="disconnect-modal"`) opens, then confirm; the card should move to "Available Platforms" afterward.
- **98/576** — Before confirming disconnect, read the modal's warning text (`data-role="disconnect-warning"`) and confirm it explains historical data is retained but no new data will sync.
- **99/577** — After disconnecting Facebook Ads, confirm it appears under "Available Platforms" with a "Connect Facebook" button (`data-role="reconnect-integration""`), i.e. reconnectable through the same UI (full OAuth reconnect is out of scope live — this platform's Stripe-style OAuth limitation note in plan.md applies to real external OAuth flows; confirm the UI affordance is present and correctly routes to `/app/integrations/connect`).
- **578** — Not exercisable live without a real OAuth provider denial; verify by reading the BDD spec (`criterion_578...spex.exs`) and the connect/callback controller code instead, and note this in the scenario observation.
- **579/100** — Confirm the QuickBooks card and a marketing-platform card (e.g. Google Ads) render through identical structure: both have `data-role="integration-sync-status"` and `data-role="disconnect-integration"`, no QuickBooks-specific markup or separate section.
- General regression sweep: take a full-page screenshot of `/app/integrations` at the start (baseline, all six connected) and after the disconnect/reconnect scenario, saved under the screenshots directory below.

## Result Path

.code_my_spec/qa/13/screenshots/

## Setup Notes

Results are recorded via `submit_qa_result` (a DB-backed attempt) plus `create_issue` for findings — there is no `result.md` file; the path above is where screenshot evidence is saved. Criterion 578 (OAuth denial) cannot be driven end-to-end live without a real third-party provider denying access; back it with the exunit spex and controller source instead of a live repro, and say so explicitly in that scenario's observation rather than skipping it silently.

**Critical environment gotcha, worth its own paragraph:** this worktree's `mix phx.server` (port 4070) does NOT read the default `metric_flow_dev` database. It was started by the harness with `DATABASE_NAME=metric_flow_dev_wc_bd0baac8` (a per-worktree DB, per the comment at `config/dev.exs:12`). Any `mix run` shell invocation that doesn't set that same `DATABASE_NAME` env var silently connects to a *different*, unrelated database — writes succeed with no error, but the running app never sees them. Confirm which DB is real by checking `psql -l` for `metric_flow_dev_wc_*` names and cross-referencing against what the browser shows, or just always export `DATABASE_NAME=metric_flow_dev_wc_bd0baac8` before any `mix run -e` against this checkout. This generalizes the DB-mismatch gotcha already filed as `qa`-scope issue `ea943c9c` (story 3) with the concrete DB name and root cause for this specific worktree.

**Seed data is already naturally expired, which is useful and a trap.** All 7 of qa@example.com's seeded integrations (including quickbooks, google_search_console, facebook_ads) have `expires_at` in April/May 2026, and the server's real wall-clock time is 2026-09-30 — so `Integration.expired?/1` is `true` for all of them already, with no seed mutation needed to exercise criteria 571/574. Don't bother writing a fresh expiry via SQL; just use any already-connected platform directly.

**Facebook Ads was disconnected during this pass** (criteria 97/98/99/575-577 exercise real disconnect) and is now gone from qa@example.com's integrations — `Integrations.disconnect/2` hard-deletes the row, and `priv/repo/qa_seeds.exs` does not recreate platform integrations (it only seeds users/accounts). Restoring it needs a real OAuth reconnect through `/app/integrations/connect`, which needs live third-party credentials this environment doesn't have configured for an automated repro. A future pass should either reconnect it manually first or pick a different already-connected platform to disconnect.
