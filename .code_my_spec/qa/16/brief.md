# Qa Story Brief

## Tool

web

## Auth

App URL for this session: `http://127.0.0.1:59302` (this worktree's own dev server).

```
browser_navigate(url: "http://127.0.0.1:59302/users/log-in")
browser_scroll_into_view(selector: "#login_form_password")
browser_fill(selector: "#password_email", text: "qa@example.com")
browser_fill(selector: "#user_password", text: "hello world!")
browser_click(selector: "#login_form_password button[name='user[remember_me]']")
browser_wait_for_url(pattern: "/", timeout: 5000)
```

## Seeds

Base seeds already in place (qa@example.com / hello world!). This account already has substantial real sync history (dozens of entries spanning March–September 2026 across Google Ads, Google Analytics, Google Search Console, Google Business Profile, Facebook Ads, QuickBooks) — no extra seeding needed for the history-volume criterion.

For the "never synced" and "disconnected" scenarios, use a fresh throwaway integration rather than touching the account's real connected ones (those rows are reused across sessions this week). Insert directly via SQL against this worktree's DB (`metric_flow_dev_wc_bd0baac8`, confirm via `ps eww -p <phx.server pid> | grep DATABASE_NAME` if the server has restarted since):

```bash
PGPASSWORD=postgres psql -h localhost -U postgres -d metric_flow_dev_wc_bd0baac8 -c "
INSERT INTO integrations (provider, access_token, refresh_token, expires_at, granted_scopes, provider_metadata, user_id, inserted_at, updated_at)
SELECT 'google_business_reviews', access_token, refresh_token, expires_at, granted_scopes, '{}'::jsonb, user_id, now(), now()
FROM integrations WHERE id = 59 RETURNING id;
"
```

(Reuses real OAuth tokens from the account's existing `google_business` integration id 59, but under a provider slug -- `google_business_reviews` -- that has never had a sync history row, so it's guaranteed "never synced." Clean up afterward: `DELETE FROM integrations WHERE provider = 'google_business_reviews' AND user_id = 2;`)

## What To Test

- **116/621** (last successful sync timestamp per integration): Visit `/app/integrations`. For a platform with real sync history (e.g. Google Business, Google Ads), confirm `[data-role='last-sync-at']` shows "Last synced <date>" matching the most recent successful entry in Sync History for that provider.
- **622** (never-synced integration shows no misleading timestamp): the fresh `google_business_reviews`-provider integration has no prior sync history. Since it isn't in the `@data_platforms` list (only the 6 UI-visible platforms are), confirm instead via a UI-visible platform with no sync history if one exists, OR read `last_sync_at` template logic directly and confirm via code review that `@last_synced_at[platform.provider]` being `nil` renders "Never synced" (already confirmed by source read — verify live if a genuinely-never-synced UI platform is available; otherwise this is a code-review pass).
- **117/623** (next scheduled sync time per integration): confirm `[data-role='next-sync-at']` shows "Next sync <date> 02:00 UTC"-ish time for a connected platform.
- **624** (disconnected integration shows no next scheduled sync): use the fresh inserted integration OR a disposable one — actually since `google_business_reviews` isn't a UI platform, this needs a real UI-visible platform's Disconnect flow. Reproducible input: pick a platform whose disconnect/reconnect doesn't destroy data you need again (this consumes the connection — re-run the relevant OAuth exchange script from the QA plan if you need it reconnected afterward for other stories). Click Disconnect → Confirm on the integrations index, then confirm `[data-role='next-sync-at']` is absent for that platform's card (it moves to "Available Platforms" section).
- **118/625** (30+ sync history entries): Visit `/app/integrations/sync-history`. Count `[data-role='sync-history-entry']` — qa@example.com's account already has far more than 30 real entries; confirm the count returned is >=30 and entries aren't artificially truncated below that.
- **119/626** (entry shows timestamp, status, records, errors): Inspect a handful of entries — both a success entry (has records_synced count + completed timestamp) and a failed entry (has `[data-role='sync-error']` with message text).
- **120/627** (failed syncs highlighted): Confirm failed entries render with `data-status='failed'` and a distinct error-colored badge/text (`badge-error`, `text-error` classes per source).
- **121/628** (filter by status): Click `[data-role='filter-success']`, confirm only success entries shown; click `[data-role='filter-failed']`, confirm only failed entries shown; click `[data-role='filter-all']` to restore.

## Result Path

.code_my_spec/qa/16/result.md

## Setup Notes

This story's UI spans two LiveViews: `/app/integrations` (IntegrationLive.Index — per-integration last/next sync, connect/disconnect) and `/app/integrations/sync-history` (IntegrationLive.SyncHistory — detailed log, filtering). Already explored both extensively this session while testing stories 14 and 38; qa@example.com's account has abundant real sync history data across all 6 platforms spanning March–September 2026, so most scenarios are testable without fresh seeding.
