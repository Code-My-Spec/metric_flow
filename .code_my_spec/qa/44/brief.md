# Qa Story Brief

Story 44: Fetch and Select Google Business Profile Locations Across Multiple Accounts

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

`qa@example.com` owns the real, previously-connected Google Business integrations (id 59 performance, id 63 reviews) used in stories 38/41 this session.

## Seeds

The only existing GBP integration has exactly one real account/location configured (`accounts/102071280510983396749/locations/13342875221580615303`) and no `google_business_account_ids` metadata key at all — there is no second real GBP account available in this environment, so a genuine live end-to-end multi-account merge against the real Google API cannot be exercised. The multi-account fetch/merge/pagination logic (`MetricFlow.Integrations.GoogleBusinessLocations`) was instead verified by direct, thorough code reading.

## What To Test

- **394/934, 396 — Iterates all configured account IDs, handles pagination.** Code read: `GoogleBusinessLocations.list_locations/2` reads `google_business_account_ids` (falling back to a live `fetch_accounts` call when empty) and `collect_locations/3` reduces over every account ID, calling `fetch_all_pages/5` per account, which recurses on `nextPageToken` until exhausted, merging every page's results.
- **395 — Correct API and fields.** Code read: uses `mybusinessbusinessinformation.googleapis.com/v1`, but the `readMask` query param only requests `name,title,storeCode,storefrontAddress,websiteUri` — **`regularHours` and `primaryCategory` are both missing from the readMask**, even though `extract_locations/2` attempts to read `primaryCategory.displayName` (which will always come back `nil` since it was never requested) and `regularHours` isn't referenced in the extraction at all. File as an issue if confirmed.
- **397/935 — Merge into one flat list.** Code read: `collect_locations/3` concatenates (`acc ++ locations`) across every account, into one list passed up to the LiveView.
- **398/936, 399/937 — User selects locations; row shows account/name/store code/address.** Live: open `/app/integrations/connect/google_business/accounts` with a non-expired token, confirm the location list shows a disambiguating account label alongside name, store code, and address for the one real location.
- **400/938 — Selected IDs prefixed with accountId.** Code read: `qualified_id = "#{account_id}/#{location_name}"` (e.g. `accounts/123/locations/abc`), confirmed stored verbatim in `included_locations` for the real integration (DB).
- **401/939 — Update selection without re-authenticating.** Live: toggle the location checkbox and save; confirm it persists without any OAuth redirect.
- **402/940 — Missing location flagged, not silently dropped.** Live: temporarily add a bogus location ID to `included_locations` via SQL, reload the accounts page, confirm it's shown as unavailable/flagged rather than vanishing. Revert afterward.
- **403/941 — Reviews and performance sync across all accounts.** Code read: `DataProviders.GoogleBusiness.resolve_locations/1` reads the full `included_locations` list (which already carries each location's own account prefix) and `fetch_metrics/2` iterates every one of them for both performance and reviews — correctly sync across accounts without needing separate per-account looping, since the qualified location ID already disambiguates.
- **404/942 — 548-day backfill for a new location.** Code read: `resolve_date_range/1` defaults to `Date.add(today, -548)` when no prior sync date is passed — same mechanism confirmed live for the single-account case in story 41's pass.

## Result Path

`.code_my_spec/qa/44/result.md`

## Setup Notes

**Significant finding before any live testing**: `mix test test/spex/44_.../*.exs` currently shows 14/20 passing, with all 6 failures (935–940) sharing the exact same root cause — `capture_log(fn -> live(...) end) |> elem(1)` in the spex fixture code. `capture_log/1` returns only the captured log *string*, discarding the inner function's actual `{:ok, view, html}` return value, so `elem(1)` crashes with `ArgumentError: not a tuple` before any real assertion runs. This is a broken spex fixture, not an application bug — confirmed by reading the underlying implementation directly, which is correct for all 6 of those criteria except the readMask field gap noted above. Filed as a qa-scope issue (`1a6a1af7`).

## Results

- **394/934, 396/397/935**: pass (code review). `collect_locations/3` iterates every configured account ID, `fetch_all_pages/5` recurses on `nextPageToken` per account, and all results are concatenated into one flat list.
- **395**: **fail**. `build_url/2`'s `readMask` omits `regularHours` and `primaryCategory` entirely -- confirmed by direct code read. Filed as issue `9c865621` (medium).
- **398/936, 399/937**: pass (code review, markup confirmed). `connect.ex`'s google_business branch renders `[data-role='location-title']`, `[data-role='location-account-name']`, `[data-role='location-address']`, `[data-role='location-store-code']`, each wired to the exact fields `extract_locations/2` returns.
- **400/938**: pass (code + DB). `qualified_id = "#{account_id}/#{location_name}"` confirmed stored verbatim in the real integration's `included_locations`.
- **401/939**: pass (code review). Saving a selection is a plain `update_provider_metadata` call with no re-auth step.
- **402/940**: **pass, confirmed live** (and unplanned): the real GBP integration's token turned out to be genuinely invalid at Google (not just locally expired -- bumping `expires_at` didn't help), so `/app/integrations/connect/google_business/accounts` naturally exercised this exact scenario: the previously-configured location `accounts/.../locations/...` is shown under "Previously configured location(s) are no longer available" with a clear message, rather than silently vanishing.
- **403/941**: pass (code review). `DataProviders.GoogleBusiness.resolve_locations/1` reads the full `included_locations` list (each entry already account-prefixed) and `fetch_metrics/2` iterates every one for both performance and reviews -- correctly covers all accounts without needing separate account-level looping, since the qualified location ID is self-describing.
- **404/942**: pass (code review). `resolve_date_range/1` defaults to a 548-day lookback with no prior sync date, consistent with the live-confirmed single-account behavior from story 41's pass.

Six of this story's own spex (935-940) currently crash on a broken `capture_log/1 |> elem(1)` test fixture pattern, unrelated to any of the above -- filed as qa-scope issue `1a6a1af7` with the fix needed. None of the six affected criteria's real behavior is actually broken.

Submitting as **partial** with issue `9c865621` linked (the readMask gap); the qa-scope spex-fixture issue `1a6a1af7` is informational.
