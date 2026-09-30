# QA Result: Story 38 — Sync Google Business Profile Reviews

Status: partial

## Summary

Tested against a real, live Google Business Profile OAuth connection (cloned from qa@example.com's existing integration id 59, real location `accounts/102071280510983396749/locations/13342875221580615303`), not fixtures.

- **981** (fetch reviews from real API): PASS. Real sync fetched 6034 records on first sync, 10929 on second — genuine data from the live My Business v4 / Performance v1 APIs via the account's own OAuth token.
- **982 / 988** (no locations → clear, logged failure): PASS on the letter of the criteria (failed status, error element present, logged with integration_id/provider/reason), but the displayed error text is the raw atom `no_locations_configured`, not a humanized sentence like sibling failures. Filed as low-severity issue `b340b02f`.
- **983** (no backfill window / no Initial Sync marker): FAIL. The first-ever sync of a new google_business_reviews integration shows the "Initial Sync" badge and "Backfilled the maximum history..." notice, exactly like a real backfill-windowed provider — contradicting the criterion. The story's own spex passes only because its CSS selector is structurally broken (compound selector spanning two different DOM elements, so it can never match). Filed as high-severity issue `534f7d2b`.
- **987** (partial location failure doesn't fail whole sync): PASS. With one real + one nonexistent location configured, sync still completed successfully (10929 records, same as the single-location second sync — the fake location contributed nothing but didn't break the sync).

## Issues filed

- `534f7d2b` (high, app) — Initial Sync badge/backfill notice incorrectly shown on first review sync; masks a real criterion-983 violation behind a broken spex selector.
- `b340b02f` (low, app) — no_locations_configured error shown as raw atom instead of humanized text.

`qa_complete` stays open pending a fix to issue `534f7d2b` (the real criterion violation); the low-severity text issue does not block.
