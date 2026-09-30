# Qa Story Brief

## Tool

web

## Auth

App URL for this session: `http://127.0.0.1:59302` (this worktree's own dev server).

```
browser_navigate({ url = "http://127.0.0.1:59302/users/log-in" })
browser_wait_for_load({})
-- fill via ref if #password_email selector doesn't bind (known LiveView quirk this session):
browser_fill({ selector = "#password_email", text = "qa@example.com" })
browser_fill({ selector = "#user_password", text = "hello world!" })
-- if the email field reads back empty, set it directly via JS input events, then:
browser_evaluate({ expression = "document.getElementById('login_form_password').requestSubmit()" })
```

## Seeds

Base seeds already in place (qa@example.com / hello world!). This account has a real, connected Google Search Console integration (provider `google_search_console`, site `https://desertfirstcleaning.com/`) already showing "Connection error — reconnect required" from a prior story's testing — this is useful as-is for exercising criterion 1000 (expired/rejected token) without any setup.

## What To Test

- **994** (sync fetches organic search data via Search Console API using existing Google OAuth): confirmed by code review — `google_search_console.ex` uses `integration.access_token` (the same OAuth token shared with Google Ads/Analytics), calls the real Webmasters v3 `searchAnalytics/query` endpoint. Live: trigger Sync Now on the connected integration at `/app/integrations` and confirm a sync-history entry appears.
- **995** (integration with no site configured fails clearly, not silently skipped): insert a fresh `google_search_console` integration via SQL with `provider_metadata` containing no `site_url` key, trigger sync, confirm a `failed` sync-history entry appears (not silently absent) with a readable error.
- **996** (core metrics clicks/impressions/ctr/position stored daily): after a successful sync (see 1000 below — likely blocked by the existing expired token, so may need a workaround), query `metrics` table for `provider = 'google_search_console'` and confirm all 4 `metric_name` values are present.
- **997** (pagination until all rows retrieved): code review — `fetch_all_rows/8` loops while `length(rows) == @rows_per_page` (25,000), up to `@max_pages` (10), accumulating across pages. Not practically live-testable (would need >25k days of real data); code-review pass only.
- **998/999** (548-day backfill on first sync, less if site has less history): code review — `sync_worker.ex`'s `determine_date_range/3` passes `nil` for `:initial` syncs, and `resolve_date_range/1` in the provider defaults to `{today - 548, today - 1}` when no `:date_range` opt given — same pattern already verified correct for GA4 in story 35 this session. Live value can't be distinguished from a shorter backfill without controlling the site's actual indexed history length.
- **1000** (expired token or API rejection fails clearly, surfaced): the account's real Search Console integration already shows "Connection error — reconnect required" — trigger Sync Now on it live and confirm a `failed` sync-history entry with a real error surfaces (not a silent no-op or crash).
- **1001** (failures logged with enough detail to diagnose, including site and date range, visible in Sync History): **expected gap** — `format_error/1` in `sync_worker.ex` has no clause for `:missing_site_url`, `:site_not_found`, or `:insufficient_permissions`; they fall through to `Atom.to_string/1`, producing bare strings like "missing_site_url" with no site URL or date range ever included. `sync_history` itself has no `site_url`/`date_range` columns. Criterion 1001's own spex only asserts a generic `[data-role='sync-error']` element exists, not its content, so it can't catch this. Confirm live, then file.

## Result Path

.code_my_spec/qa/40/result.md

## Retest 2026-09-30

Issue d1bff983 (Search Console sync failure messages missing site/date-range context) verified fixed live. Reproduced the :missing_site_url path by temporarily clearing integration 36's site_url, clicking "Trigger Sync Now (Dev)" on /app/integrations/sync-history, and confirming sync_history row 297 now reads "No Search Console site URL configured (date range: 2026-09-29 to 2026-09-29). Go to the integration's account selection to choose a site." instead of the bare atom `missing_site_url` seen in the prior attempt's rows 273/278. Also confirmed the message renders on the Sync History page. Restored the original site_url afterward.

## Setup Notes

The expected primary finding is criterion 1001: sync failure messages never include which site or date range was being synced, contradicting the criterion's own explicit text, even though its BDD spex passes (it only checks for the presence of an error element). This is analogous to gaps found in several other Sync-* stories this session (GA4, Correlation) where a criterion's specific wording isn't matched by a generic, loosely-asserting spex.

## Results

- **994** pass (code review + live): real connected Search Console integration successfully synced using the shared Google OAuth token; token was transparently refreshed by `ensure_fresh_tokens` before the provider call (confirmed via `sync_history` showing a `success` status despite a stale "Connection error" UI badge from an expired `expires_at`).
- **995** pass (live): temporarily removed `site_url` from the real integration's `provider_metadata`, triggered the daily sync via `[data-role='trigger-daily-sync']` on `/app/integrations/sync-history` (the actual repro path used by the story's own spex — the per-card "Sync Now" button is disabled client-side when no site is selected, so it can't reach this path at all), and confirmed a `Google Search Console` entry with status `Failed` and error `missing_site_url` appeared in Sync History — not silently skipped. Restored `site_url` afterward.
- **996** pass (live): confirmed via direct DB query that all 4 required metric names (`clicks`, `impressions`, `ctr`, `position`) exist for `provider = 'google_search_console'`, backed by real historical syncs with up to 1992 records.
- **997** pass (code review only): `fetch_all_rows/8` in `google_search_console.ex` loops while `length(rows) == @rows_per_page` (25,000), accumulating across pages up to `@max_pages` (10). Not practically live-testable at that volume.
- **998/999** pass (code review only): `determine_date_range/3` in `sync_worker.ex` passes `nil` for `:initial` syncs; the provider's own `resolve_date_range/1` then defaults to `{today - 548, today - 1}`. Same pattern already verified correct for GA4 in story 35 this session.
- **1000** pass (live, via other providers + code review for Search Console): the daily-sync trigger surfaced real, live token-expiry failures for QuickBooks and Facebook Ads ("Token expired and could not be refreshed. Please reconnect."), confirming the mechanism this criterion describes works and surfaces clearly. Search Console's own `check_not_expired/1` uses identical `Integration.expired?/1` logic; its 401/403/404 response-handling clauses (`:unauthorized`, `:insufficient_permissions`, `:site_not_found`) were verified by code review since this account's Search Console token happened to still be refreshable during this session.
- **1001** **fail** — filed `d1bff983`: the `missing_site_url` failure captured above shows only that bare atom string, never the site URL or date range the criterion explicitly requires. `format_error/1` has no clause for the Search Console provider's own error atoms; `sync_history` has no columns for site/date-range context either.

`qa_complete` stays open pending a fix to `d1bff983`.
