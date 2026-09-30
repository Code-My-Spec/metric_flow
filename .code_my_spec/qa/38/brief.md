# Qa Story Brief

## Tool

web

## Auth

App URL for this session: `http://127.0.0.1:59302` (this worktree's own dev server, serving commit e6d1d8fc — not main's).

Log in as the QA owner via the password form:

```
browser_navigate(url: "http://127.0.0.1:59302/users/log-in")
browser_scroll_into_view(selector: "#login_form_password")
browser_fill(selector: "#password_email", text: "qa@example.com")
browser_fill(selector: "#user_password", text: "hello world!")
browser_click(selector: "#login_form_password button[name='user[remember_me]']")
browser_wait_for_url(pattern: "/", timeout: 5000)
```

If login fails (user doesn't exist), run the base seed script first:
`mix run priv/repo/qa_seeds.exs` (server must not already be running when you do, or use the `--no-start` form from `.code_my_spec/qa/plan.md`).

## Seeds

This worktree's dev DB is `metric_flow_dev_wc_bd0baac8` (confirmed via the running server's env, not the `metric_flow_dev` default — check `ps eww -p <phx.server pid>` if the server has since been restarted on a different PID).

qa@example.com (user_id=2) already has a **real, live, connected Google Business Profile integration** (id 59, provider=`google_business`) with a real, currently-valid OAuth access token/refresh token and one real location: `accounts/102071280510983396749/locations/13342875221580615303`. This is a genuine opportunity to test against the real Google Business Profile API rather than fixtures — reuse its tokens.

**Step 1 — clone a fresh `google_business_reviews` integration (for criteria 981 and 983's "first sync" check):**

```bash
PGPASSWORD=postgres psql -h localhost -U postgres -d metric_flow_dev_wc_bd0baac8 -c "
INSERT INTO integrations (provider, access_token, refresh_token, expires_at, granted_scopes, provider_metadata, user_id, inserted_at, updated_at)
SELECT 'google_business_reviews', access_token, refresh_token, expires_at, granted_scopes,
       jsonb_build_object('included_locations', jsonb_build_array('accounts/102071280510983396749/locations/13342875221580615303')),
       user_id, now(), now()
FROM integrations WHERE id = 59;
"
```

This row has NO prior sync history — its first sync is the one criterion 983 cares about. Do the 981/983 testing (below) before touching this row again.

**Step 2 — reconfigure the same row for the no-locations case (982, 988):**

```bash
PGPASSWORD=postgres psql -h localhost -U postgres -d metric_flow_dev_wc_bd0baac8 -c "
UPDATE integrations SET provider_metadata = '{}'::jsonb, updated_at = now()
WHERE provider = 'google_business_reviews' AND user_id = 2;
"
```

**Step 3 — reconfigure for the partial-failure case (987): one real location + one that doesn't exist:**

```bash
PGPASSWORD=postgres psql -h localhost -U postgres -d metric_flow_dev_wc_bd0baac8 -c "
UPDATE integrations SET provider_metadata = jsonb_build_object('included_locations',
  jsonb_build_array('accounts/102071280510983396749/locations/13342875221580615303', 'locations/does-not-exist')), updated_at = now()
WHERE provider = 'google_business_reviews' AND user_id = 2;
"
```

Optional cleanup after the session (not required, but keeps the real account tidy for future passes):

```bash
PGPASSWORD=postgres psql -h localhost -U postgres -d metric_flow_dev_wc_bd0baac8 -c "DELETE FROM integrations WHERE provider = 'google_business_reviews' AND user_id = 2;"
```

## What To Test

All testing happens at `/app/integrations/sync-history` — log in, navigate there, click `[data-role='trigger-daily-sync']`, wait for the page to update (Oban runs the job synchronously-ish via PubSub broadcast; poll/wait a couple seconds and reload if needed), then inspect the sync-history entries.

- **Criterion 981** (after Step 1's insert, before any other mutation): trigger sync. Expect a `[data-role='sync-history-entry'][data-status='success']` entry with `[data-role='sync-provider']` text "Google Business Reviews". Check the actual `records_synced` count is plausible (real review + performance metrics for one location) — confirms the real Google OAuth token and the real My Business v4 API call actually worked, not just that the code path didn't crash.

- **Criterion 983** (same first sync as above, don't skip this — do it before Step 2): the spex's own selector for this (`[data-role='sync-history-entry'][data-sync-type='initial']`) is structurally broken — `data-sync-type="initial"` is rendered on an inner `<span>` badge, never on the same element as `data-role='sync-history-entry'`, so the compound CSS selector can never match regardless of whether the badge is actually present. **Don't trust the spex pass for this criterion — check the raw HTML directly** with `browser_get_html` and look for whether an "Initial Sync" badge / `data-sync-type="initial"` span appears anywhere near the "Google Business Reviews" entry. Code inspection (`sync_worker.ex` `determine_sync_type/1`) suggests it likely WILL show, since sync_type is determined purely by `has_prior_sync_history?(integration_id)` with no provider-aware exemption for reviews — if that's confirmed live, this is a real criterion-983 violation masked by a broken spex assertion; file it. Also trigger a **second** sync on the same integration afterward and confirm the review count/history is still a full re-fetch (not narrowed), consistent with "no backfill window, ever."

- **Criterion 982 / 988** (after Step 2): trigger sync. Expect `[data-role='sync-history-entry'][data-status='failed']` with `[data-role='sync-provider']` text "Google Business Reviews", and a `[data-role='sync-error']` element present. Read the actual error text — code inspection shows the raw reason atom `no_locations_configured` falls through to a generic `Atom.to_string/1` formatter (unlike other failure reasons like `:missing_property_id`, which get a human-readable sentence). Judge whether the displayed text is actually "a clear error" per the criterion's own wording, or just a raw atom string — file a finding if it's the latter.

- **Criterion 987** (after Step 3): trigger sync. Expect the sync to still complete with `[data-role='sync-history-entry'][data-status='success']` for "Google Business Reviews" (the real location's reviews are fetched; the fake location is skipped per-location without failing the whole thing). Check server logs (`tail` the dev log or check Logger output if accessible) for a warning about the failing location, to confirm criterion 988's logging applies here too, not just the no-locations case.

## Result Path

.code_my_spec/qa/38/result.md

## Setup Notes

The existing real integration (id 59, provider `google_business`) belongs to qa@example.com and is a standing QA fixture used by prior sessions (stories 13/14) — safe to read its tokens but don't modify or delete that row. Only the new `google_business_reviews` row (created in Step 1) should be mutated/deleted during this session.

If `browser_click` on `[data-role='trigger-daily-sync']` seems to not register (a known intermittent LiveView issue in this app, documented elsewhere this session), retry via `browser_evaluate` calling `.requestSubmit()`/dispatching a click event, or just re-click.
