# Qa Story Brief

## Tool

web

## Auth

App URL for this session: `http://127.0.0.1:59302` (this worktree's own dev server -- it was returning 503/`Phoenix.Ecto.PendingMigrationError` at session start; a pending migration `20260930160000_add_correlation_view_mode_to_users` had never been run against this worktree's DB, fixed via `DATABASE_NAME=metric_flow_dev_wc_bd0baac8 mix ecto.migrate`, filed as issue 9fe7db34).

Log in as qa@example.com (admin on multiple accounts, including "Client Alpha" where this story's test fixture lives):

```
browser_navigate(url: "http://127.0.0.1:59302/users/log-in")
browser_fill(selector: "#password_email", text: "qa@example.com")
browser_fill(selector: "#user_password", text: "hello world!")
browser_click(selector: "#login_form_password button[name='user[remember_me]']")
browser_wait_for_url(pattern: "/", timeout: 8000)
```

If `browser_fill` hangs/times out on these two fields (seen intermittently this session), use `browser_click(selector)` then `browser_type(selector, text)` instead.

**After login, switch the active account to "Client Alpha"** (account id 14) via the account switcher in the nav -- the correlation fixture below lives on that account, not qa@example.com's default account.

## Seeds

This worktree's dev DB is `metric_flow_dev_wc_bd0baac8`.

Account 14 ("Client Alpha") already had several real correlation jobs from story 24's QA session, but none had 5+ qualifying correlations on both the positive and negative side (needed to test real top-5 truncation), so a dedicated synthetic job was added for this story:

- `correlation_jobs.id = 49`, account_id=14, status=completed, goal_metric_name=`qa26_smart_goal`, time_window=days_90, completed_at=now() (the most recent job on this account, so `get_latest_correlation_summary` picks it up).
- `correlation_results` for job 49 (16 rows, metric_name prefixed `qa26_` so they're easy to distinguish from real data):
  - 7 positive, descending: `qa26_pos_1_google_ads` (0.95, provider google_ads), `qa26_pos_2_facebook_ads` (0.90, facebook_ads), `qa26_pos_3_ga` (0.85, google_analytics), `qa26_pos_4_qb` (0.80, quickbooks), `qa26_pos_5_ga` (0.75, google_analytics) -- these 5 should be the ones shown; `qa26_pos_6_ga` (0.70) and `qa26_pos_7_ga` (0.65) should NOT appear in Smart mode's top-5 list.
  - 7 negative, descending magnitude: `qa26_neg_1_google_ads` (-0.90, google_ads), `qa26_neg_2_facebook_ads` (-0.85, facebook_ads), `qa26_neg_3_ga` (-0.80, google_analytics), `qa26_neg_4_qb` (-0.75, quickbooks), `qa26_neg_5_ga` (-0.70, google_analytics) -- these 5 shown; `qa26_neg_6_ga` (-0.65) and `qa26_neg_7_ga` (-0.60) should NOT appear.
  - 2 below threshold: `qa26_below_pos` (0.25) and `qa26_below_neg` (-0.20) -- should never appear in Smart mode's top lists (criterion 199/853), but ARE visible in Raw mode's full table (criterion 202/857) since Raw mode shows everything.
  - `qa26_pos_1/2` and `qa26_neg_1/2` use provider `google_ads`/`facebook_ads` specifically to test AI highlighting (`@actionable_providers` in the source is `[:google_ads, :facebook_ads]`) -- `data-ai-highlighted="true"` is expected on those 4 rows and `"false"` on the rest.

## What To Test

All at `/app/correlations` after switching to Client Alpha:

- **Mode toggle + persistence (203/858)**: Confirm default mode is Raw (`qa@example.com.correlation_view_mode` is `"raw"` in the DB). Click `[data-role="mode-smart"]`, confirm the page switches to Smart mode content (`[data-role="smart-mode"]`). Reload the page -- it should still be in Smart mode. Query the DB (`SELECT correlation_view_mode FROM users WHERE email='qa@example.com'`) to confirm it persisted as `"smart"`, not just client-side state. Switch back to Raw and confirm that persists too.

- **Top 5 positive / top 5 negative (198/852)**: In Smart mode, `[data-role="top-positive-correlations"]` should list exactly `qa26_pos_1_google_ads` through `qa26_pos_5_ga` in descending coefficient order, and NOT `qa26_pos_6_ga`/`qa26_pos_7_ga`. Symmetric check on `[data-role="top-negative-correlations"]` for the 5 most negative, excluding `qa26_neg_6_ga`/`qa26_neg_7_ga`.

- **Threshold enforcement (199/853)**: Confirm `qa26_below_pos` (0.25) and `qa26_below_neg` (-0.20) never appear anywhere in Smart mode's positive/negative lists -- they're below the 0.3 absolute-value threshold. Confirm they DO appear in Raw mode's results table (`[data-role="results-table"]`) to establish they're real data, not simply missing.

- **Fewer-than-5 case (854)**: Switch to Raw mode, note there's other real correlation data on this account from job 48 with only 3 results above threshold (not part of this fixture) -- not required to retest here since the fixture above already exercises "exactly 5 shown, 2 hidden"; if time allows, spot-check that a goal metric with fewer than 5 qualifying results (e.g. filter mentally using job 48's data, which only has 3 positives and 0 negatives above 0.3) doesn't pad the list or error. This is lower priority than the main truncation check above since the live UI will show whichever job is "latest" for the account, which is fixture job 49.

- **Explanations (200/855)**: Each correlation row in Smart mode should have a plain-language sentence via `correlation_explanation/1`, e.g. "qa26_pos_1_google_ads shows a strong positive correlation with your goal metric at a 3-day lag." Confirm the text appears per-row and names strength, direction, and lag correctly for a couple of rows (one same-day lag=0 row would say "with same-day impact" if present -- `qa26_pos_3_ga` has lag=0, check its wording specifically).

- **AI highlighting (201/856)**: Inspect `data-ai-highlighted` on each `[data-role="correlation-row"]` within the top lists -- should be `"true"` only for `qa26_pos_1_google_ads`, `qa26_pos_2_facebook_ads`, `qa26_neg_1_google_ads`, `qa26_neg_2_facebook_ads` (the google_ads/facebook_ads rows), `"false"` for the google_analytics/quickbooks rows. Note: the UI doesn't appear to render this flag visually anywhere obvious in the template read so far (no distinct badge/icon tied to `data-ai-highlighted` beyond the attribute itself) -- check the rendered HTML/CSS carefully before concluding whether this is a real visual highlight or just a DOM attribute with no visible effect, since that would affect whether this criterion is genuinely met from a user's perspective.

- **Full ranked list still accessible (202/857)**: From Smart mode, click `[data-role="mode-raw"]` and confirm all 16 rows (plus any other real data on the account) are visible in the full sortable/filterable table, including the two below-threshold rows and the excluded 6th/7th-ranked rows on each side.

## Result Path

.code_my_spec/qa/26/result.md

## Setup Notes

The `@smart_mode_threshold` in `CorrelationLive.Index` is a strict absolute-value comparison (`r.coefficient > 0.3` / `r.coefficient < -0.3`), confirmed by code read before writing this brief -- a coefficient of exactly 0.3 would NOT qualify. The fixture avoids testing that exact boundary since it's a straightforward `>`/`<` and not worth a dedicated row.

Don't delete job 49 or its results after testing -- leave them as a reusable fixture, consistent with how story 24's synthetic data was left in place and reused by later sessions.
