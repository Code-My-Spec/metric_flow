# QA Result — Story 16 (Integration Sync Status Visibility)

## Outcome: pass

## Scenarios

1. **116/621** (last successful sync timestamp per integration) — pass. Live: all 6 connected platforms on `/app/integrations` show `[data-role='last-sync-at']` with distinct, accurate per-platform timestamps (Google Analytics 18:47 UTC, Google Ads/Search Console/Business 19:32 UTC, Facebook Ads/QuickBooks Apr 05), each matching that provider's most recent entry in Sync History.
2. **622** (never-synced integration shows no misleading timestamp) — pass via code review. `lib/metric_flow_web/live/integration_live/index.ex:165-170`: `last-sync-at` renders "Never synced" whenever `@last_synced_at[platform.provider]` is nil — a clean, unambiguous conditional. All 6 UI-visible platforms in this account already have real sync history, so no live never-synced case was available without disrupting shared fixtures; the code path is simple enough that review is conclusive.
3. **117/623** (next scheduled sync time per integration) — pass. Live: all 6 connected platforms show `[data-role='next-sync-at']` = "Next sync Oct 01, 2026 02:00 UTC" (uniform daily cron time).
4. **624** (disconnected integration shows no next scheduled sync) — pass via code review. `index.ex:254-296`: disconnected platforms render in a wholly separate "Available Platforms" block that has no `last-sync-at` or `next-sync-at` markup at all — just a "Not connected" badge and a "Connect X first" prompt. Structurally impossible for a disconnected platform to show a next-sync time. Not re-verified live in this pass to avoid consuming one of this account's real OAuth connections (reused across other stories' sessions this week); story 13's QA pass already exercised the live disconnect flow end-to-end.
5. **118/625** (30+ sync history entries) — pass. Live: `/app/integrations/sync-history` shows 95 total `[data-role='sync-history-entry']` rows (57 failed + 38 success), well above the 30-entry minimum, not truncated.
6. **119/626** (entry shows timestamp, status, records, errors) — pass. Live: success entry shows provider, "Success" badge, "6 records synced", "Completed at Sep 30, 2026 19:32 UTC". Failed entry shows provider, "Failed" badge, "0 records synced", and `[data-role='sync-error']` = "bad_request".
7. **120/627** (failed syncs highlighted) — pass. Live: failed entries use `badge-error` (vs `badge-success`) and the error text uses `text-error` — visually distinct.
8. **121/628** (filter by status) — pass. Live: `[data-role='filter-success']` → 38 entries, 0 failed; `[data-role='filter-failed']` → 57 entries, 0 success; `[data-role='filter-all']` → restores all 95.

## Issues filed

None. The two issues previously on record for this story (BDD spex reference to an unimplemented `:owner_with_integrations`, and a seed-script/sandbox permission problem) were already dismissed as unrelated before this pass began.

## Notes

Early in this session, the browser's connectivity looked broken ("We can't find the internet" / "Attempting to reconnect" text appeared in full-page text dumps). This is a red herring: those are hidden template elements for the disconnected-websocket state, always present in the DOM with `hidden=""`, and `browser_get_text` returns their text content regardless of visibility. The actual login and navigation succeeded once retried; there was no real connectivity problem.
