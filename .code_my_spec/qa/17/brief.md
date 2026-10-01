# Qa Story Brief

Story 17: Handle Expired or Invalid OAuth Credentials

## Tool

web

## Auth

Log in via the password form at `http://127.0.0.1:59302/users/log-in`:

```lua
browser_delete_cookies({})
browser_navigate({ url = "http://127.0.0.1:59302/users/log-in" })
browser_wait_for_load({})
browser_scroll_into_view({ selector = "#login_form_password" })
browser_fill({ selector = "#password_email", text = "qa@example.com" })
browser_fill({ selector = "#user_password", text = "hello world!" })
browser_click({ selector = "#login_form_password button[name='user[remember_me]']" })
```

`qa@example.com` owns real integrations, several already genuinely expired this session (confirmed across stories 13/35/36/37/42/44).

## Seeds

No fresh seeding needed. The app was down (503, PendingMigrationError) at session start due to this story's own unrun migration (`add_reconnection_notified_at_to_integrations`) — fixed by running `DATABASE_NAME=metric_flow_dev_wc_bd0baac8 mix ecto.migrate`, filed as qa-scope issue `c0554833`.

## What To Test

- **122/728 — Status changes to Needs Reconnection on refresh failure.** Code read confirms `integration_status/2` returns `"error"` whenever `Integration.expired?/1` is true; live-confirm the dashboard badge for an existing expired integration.
- **123/729 — Warning indicator on dashboard.** Live: `/app/integrations` shows a `badge-error` "Connection error — reconnect required" for an expired integration's card.
- **124/730 — Email notification about expired credentials.** Live: reload `/app/integrations` for a user with a freshly-expired integration whose `reconnection_notified_at` is nil, confirm a real email appears in `/dev/mailbox`, and confirm reloading again does NOT send a second one (the whole point of the newly-migrated `reconnection_notified_at` column).
- **125/731 — Reconnect button re-initiates OAuth.** The dashboard integration card itself has no direct "Reconnect" CTA — only "Sync Now" (which just shows an error flash) and "Edit Accounts" (blocked for expired integrations per story 13's fix). The real Reconnect path is on the separate `/app/integrations/connect` page, where an already-connected provider's button label flips from "Connect" to "Reconnect". Live-confirm this label and that clicking it redirects to a real OAuth URL.
- **126/733 — Sync resumes automatically after reconnection.** Code read: once `expires_at` is pushed forward (reconnection succeeds), `integration_status/2` returns `"connected"` and the normal cron-driven sync picks it up on its next run — no special re-enable step. No separate "resume" mechanism exists or is needed.
- **127/734 — Historical data remains intact.** Live: confirm an expired integration's existing `metrics`/`sync_history` rows are untouched (query counts before/after triggering the expiry-notification flow).
- **732 — Abandoned reconnect attempt leaves integration in Needs Reconnection.** Trivially true by construction: nothing about the integration's `expires_at`/token changes unless the OAuth callback actually succeeds, confirmed by the identical pattern already verified for incomplete-OAuth-leaves-no-integration in stories 11/12/43.

## Result Path

`.code_my_spec/qa/17/result.md`

## Setup Notes

The one real open question is whether criterion 125/731's "Reconnect button" being on a separate page (rather than directly on the dashboard's warning card) is a gap or an acceptable design — confirm live that it's genuinely reachable and correctly labeled before deciding.

## Results

Used this account's 8 already-genuinely-expired integrations (all with `reconnection_notified_at` nil going into this pass) for a clean, unconsumed repro of the full notification cycle.

- **122/728**: pass (code review). `integration_status/2` returns `"error"` for any `Integration.expired?/1` integration.
- **123/729**: pass. Live: `/app/integrations` shows a real `badge-error` "Connection error — reconnect required" for each expired card.
- **124/730**: pass. Live: reloading `/app/integrations` sent 8 real emails (one per expired integration) and set each `reconnection_notified_at`; reloading again sent zero additional emails (mailbox count unchanged at 45), confirming the dedup mechanism this story's own migration (`reconnection_notified_at`) exists to support.
- **125/731**: pass. The dashboard card itself has no direct Reconnect CTA (only "Sync Now", which just flashes an error, and "Edit Accounts", correctly blocked for expired integrations per story 13's fix) — the real Reconnect button lives on `/app/integrations/connect`, where an already-connected provider's button label flips from "Connect" to "Reconnect". Live-confirmed clicking it for Google Ads triggers a real OAuth redirect to accounts.google.com (hitting the same known qa-scope `redirect_uri_mismatch` already documented in story 43 — the app-side redirect itself is correct).
- **126/733**: pass (code review). Once `expires_at` is pushed forward by a successful reconnection, `integration_status/2` returns `"connected"` again and the normal cron-driven sync naturally picks it up — no separate "resume" gate exists or is needed.
- **127/734**: pass. Live: confirmed 1505 existing `google_ads`-family metric rows were untouched after triggering the full expiry-notification cycle on that integration.
- **732**: pass (by construction, consistent with the identical incomplete-OAuth pattern already verified in stories 11/12/43 — nothing about an integration's token changes unless its OAuth callback actually succeeds).

One low-severity, non-blocking finding: the expiry-notification sweep has no platform filter, so an expired `codemyspec` integration (an unrelated AI/dev-tool connection, not a marketing/financial platform) also gets a reconnection email in the same batch. Filed as issue `92915864`, doesn't violate any criterion's literal text.

No blocking issues. Submitting as **pass** with issue `92915864` linked (informational).
