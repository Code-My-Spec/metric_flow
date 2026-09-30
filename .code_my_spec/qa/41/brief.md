# Story 41 QA Brief: Sync Google Business Profile Performance Metrics

## Tool

web

## Auth

Log in via the password form at `http://127.0.0.1:59302/users/log-in`:

- Email: `qa@example.com`
- Password: `hello world!`

This worktree serves its own instance on port 59302 (not the shared 4070 dev server). This worktree's dev DB is `metric_flow_dev_wc_bd0baac8` (confirmed via the running beam process's `DATABASE_NAME` env var), reachable directly with `psql metric_flow_dev_wc_bd0baac8` for evidence verification the UI can't show directly (e.g. exact per-day row counts).

## Seeds

Base QA seeds already present (`qa@example.com` / `hello world!`, "QA Test Account"). No additional seeding needed for this story.

Integration id 59 (`google_business`, owned by `qa@example.com`) already holds a real Google OAuth token and a real configured location (`accounts/102071280510983396749/locations/13342875221580615303`) reused from prior stories' testing — this lets the sync hit the real Business Profile Performance API rather than a stub.

**Consumable state used this pass:** before testing, `metrics` rows for `provider='google_business'` and `sync_history` rows for `integration_id=59 AND provider='google_business'` were deleted, to get a clean, uncontaminated "never synced" starting state (the pre-existing rows were heavily duplicated — 4x per day for `2026-09-23`..`2026-09-29` — accumulated noise from many earlier ad-hoc QA sessions repeatedly clicking "Trigger Sync Now", not a controlled test). `google_business_reviews` rows/history for the same integration were left untouched. A retest should check current row counts before assuming this reset is still in effect.

## What To Test

- **993/1002** (fetch engagement metrics): trigger a sync from `/app/integrations/sync-history` (`[data-role='trigger-daily-sync']`). Confirm via `psql` that all 11 metric names appear for the location: `impressions_desktop_maps`, `impressions_desktop_search`, `impressions_mobile_maps`, `impressions_mobile_search`, `conversations`, `direction_requests`, `call_clicks`, `website_clicks`, `bookings`, `food_orders`, `food_menu_clicks`.
- **1003** (performance vs. reviews synced separately, different APIs): confirm the sync produces separate Sync History entries for "Google Business Profile" (performance, `provider=google_business`) vs. reviews (`provider=google_business_reviews`), and that `google_business` records never appear with `metric_type='reviews'` or vice versa.
- **1004** (stored daily, per location, per metric): for a handful of days across the backfilled range, confirm exactly one row per (location, metric, day) combination in `metrics` — no duplicates from a single sync.
- **1005** (missing/null value stored as zero, not a gap): pick several low-activity metrics (`bookings`, `food_orders`, `food_menu_clicks` — a small real business is likely to have zero activity on most days) and confirm every day in the synced range has an explicit row with `value=0` for that metric, not an absent row. Cross-check total row count per metric against the number of days in the range (should match 1:1, not be short).
- **1006** (first sync backfills up to 548 days; subsequent syncs incremental): confirm the first sync's earliest `recorded_at` date is `Date.utc_today() - 548` (or the location's actual history start if shorter — see 1007) and the UI shows the "Initial Sync" badge (`[data-sync-type='initial']`). Then trigger a second "Trigger Sync Now" immediately and confirm: (a) no duplicate rows appear for days already synced, (b) the new sync's `sync_history` entry is `sync_type=incremental`, (c) it does not silently accumulate duplicate rows for the day(s) it re-touches — compare row counts before/after.
- **1007** (backfill shorter than 548 days when location has less history): compare the actual earliest `recorded_at` date against `Date.utc_today() - 548` — if the location's real history is shorter, the earliest date should reflect that rather than being artificially padded.
- **1008** (failing location skipped, others unaffected): add a second, bogus location (`locations/does-not-exist`) to `provider_metadata.included_locations` via `psql`, trigger sync, and confirm: the sync still shows `status=success` for `google_business` in Sync History, the real location's metrics are still written/updated, and no error is surfaced for the whole integration. Revert `provider_metadata` afterward.
- **1009** (failures logged with detail, visible in Sync History): force a failure (e.g. temporarily corrupt `access_token` and clear `refresh_token` via `psql`, or remove `included_locations` entirely) and trigger sync. Confirm a `failed` entry appears in Sync History with a descriptive `error_message` (not a bare atom or blank), then restore the integration's original `access_token`/`refresh_token`/`provider_metadata`.

## Result Path

No result.md — findings go through `create_issue` as discovered; the pass is closed with `submit_qa_result`.

## Setup Notes

This integration's row-level history predates this QA pass and includes artifacts from other stories' sessions (duplicate rows, a stray `google_business_reviews` history entry). Treat any pre-existing `sync_history`/`metrics` state for `google_business_reviews` as out of scope for this story (story 38 owns reviews); only `google_business` state was reset here.
