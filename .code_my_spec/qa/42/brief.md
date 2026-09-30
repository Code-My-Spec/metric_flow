# Qa Story Brief

## Tool

web

## Auth

App URL for this session: `http://127.0.0.1:59302` (this worktree's own dev server). This checkout was returning 503 for all routes at session start -- a pending migration (20260930150000_create_derived_metric_definitions) had never been run against this worktree's DB. Fixed via `DATABASE_NAME=metric_flow_dev_wc_bd0baac8 mix ecto.migrate` before testing (filed as issue e960701c, qa scope).

Log in as the QA owner via the password form. Note: browser_fill consistently timed out on #password_email/#user_password this session (filed as framework issue 793e01f8) -- use browser_click then browser_type instead:

```
browser_navigate(url: "http://127.0.0.1:59302/users/log-in")
browser_click(selector: "#password_email")
browser_type(selector: "#password_email", text: "qa@example.com")
browser_click(selector: "#user_password")
browser_type(selector: "#user_password", text: "hello world!")
browser_click(selector: "#login_form_password button[name='user[remember_me]']")
browser_wait_for_url(pattern: "/", timeout: 8000)
```

## Seeds

This worktree's dev DB is `metric_flow_dev_wc_bd0baac8`.

qa@example.com (user_id=2) has a **real QuickBooks integration** (id 58, realm_id=9130355098863166, income_account_id=212) with a **genuinely expired, unrefreshable sandbox refresh token** (QuickBooks sandbox refresh tokens expire ~100 days; this one's `expires_at` is 2026-04-05, six months in the past relative to "today" 2026-09-30). 2196 real historical metric rows already exist (2024-10-04 through 2026-04-05, 549 distinct days) from when the connection was live -- this is genuine evidence of the sync having worked correctly, not a fixture.

## What To Test

All testing happens at `/app/integrations/sync-history` -- trigger via `[data-role='trigger-daily-sync']`.

- **Criterion 1010** (real fetch via existing QuickBooks OAuth): Confirmed by the 2196 historical rows -- sync worked via the shared QuickBooks OAuth token with no separate financial-platform connection step anywhere in the UI.

- **Criterion 1012/1013** (separate credit/debit metrics, zero-value continuity): Query the historical data directly: `SELECT metric_name, count(*), count(*) FILTER (WHERE value=0) FROM metrics WHERE provider='quickbooks' GROUP BY metric_name` should show two distinct metric_name series (QUICKBOOKS_ACCOUNT_DAILY_CREDITS / _DEBITS) with real zero-value days interspersed; `SELECT count(DISTINCT recorded_at) FROM metrics WHERE provider='quickbooks' AND metric_name='QUICKBOOKS_ACCOUNT_DAILY_CREDITS'` should equal `(max(recorded_at)::date - min(recorded_at)::date) + 1` (no gaps).

- **Criterion 1014** (up to 548-day backfill, incremental afterward): The historical range spans exactly the full backfill window with no gaps, confirming the mechanism worked. `sync_worker.ex`'s `determine_date_range/3` anchors incremental syncs to `last_stored_metric_date + 1` (code review).

- **Criterion 1015** (less than 548 days when account has less history): Not independently testable live -- no shorter-history fixture account available; same code path as 1014.

- **Criterion 1011** (missing company/income account fails with clear error): The real expired token masks this check (ensure_fresh_tokens runs before the provider's own resolve_realm_id/resolve_account_id, so a dead token always produces "Token expired" first). To isolate it: clear `provider_metadata` to `{}` **and** temporarily bump `expires_at` into the future using `(now() AT TIME ZONE 'UTC') + interval '1 hour'` (plain `now() + interval` uses local session time and silently produces a timestamp in the past for a `timestamp without time zone` column -- caught and corrected live this pass). Trigger sync: expect `data-status='failed'` with error text `missing_realm_id`. **Restore both fields immediately after** (provider_metadata and expires_at back to their real values) -- this integration is a real fixture other stories may rely on.

- **Criterion 1016** (API rejects with expired authorization): Already naturally and repeatedly demonstrated live -- every trigger on this integration produces a real `{:error, :token_expired}` from `Integrations.refresh_token/2` attempting a genuine (failing) OAuth refresh against Intuit's sandbox, surfaced as "Token expired and could not be refreshed".

- **Criterion 1017** (failures logged, visible in Sync History): Confirmed by every entry above -- provider name, error message, and timestamp all present in `sync_history` and rendered on the page.

## Result Path

.code_my_spec/qa/42/result.md

## Setup Notes

Integration 58 is a real, shared fixture -- its refresh token cannot be un-expired (Intuit's sandbox has no live refresh path for it), so criteria 1010/1012/1013/1014 rely on the historical data it already produced rather than a fresh live trigger. Don't delete this row; other stories may depend on its historical metrics.
