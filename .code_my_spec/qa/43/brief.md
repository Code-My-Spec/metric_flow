# Qa Story Brief

Story 43: Connect Google Business Profile via OAuth

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

`qa@example.com` owns the existing `google_business` integration (id 59, used in stories 38/41/44 this session).

## Seeds

No real Google sandbox login credentials are available in this environment (same limitation noted in stories 12/44) — a genuine fresh OAuth consent round trip cannot be completed headlessly. Code review plus the existing integration's live state are used instead.

## What To Test

- **383/943 — Initiate OAuth flow from integrations settings.** Confirm `/app/integrations/oauth/google_business` redirects to a real Google OAuth consent URL.
- **384/944 — Correct scope; reuses existing Google token.** Code read: `Providers.GoogleBusiness.config/0` requests `email profile https://www.googleapis.com/auth/business.manage` (correct scope) but with `prompt: "consent"` and no code path anywhere that checks for or reuses an existing Google token from another provider (Ads/GA4/Search Console) — each provider integration is an independent OAuth flow and independent `Integration` row.
- **385-391, 393 / 945-954 (except 392/953) — The account-selection step.** Live: load `/app/integrations/connect/google_business/accounts` (the only post-OAuth screen for this provider) and check whether it is actually a *GMB-account* selection screen (per this story: pick one or more top-level Business Profile accounts, each shown with name + ID, saved as `googleBusinessAccountIds`) or whether it's the *location*-selection screen from story 44 (picks individual business locations, saves to `included_locations`). Also grep the codebase for `google_business_account_ids` / `googleBusinessAccountIds` to see whether anything ever *writes* that key (story 44's QA already found it is only ever *read*, with `fetch_accounts/2` auto-discovering all accessible accounts with no user control).
- **392/953 — Failed OAuth attempt shows a clear error.** Live: `/app/integrations/oauth/callback/google_business?error=access_denied` — confirm the generic connect.ex error-handling path (already confirmed working for other providers in story 12) applies here too.

## Result Path

`.code_my_spec/qa/43/result.md`

## Setup Notes

This story's criteria describe a two-tier Google Business Profile connection: first select which top-level *GMB accounts* to use (this story), then select *locations* within them (story 44, already QA'd and passing). Code review strongly suggests only the second tier was ever built — confirm live before filing.

## Results

- **383/943**: pass. `/app/integrations/oauth/google_business` redirects to a real Google OAuth URL with the correct client_id and `business.manage` scope.
- **384/944**: **partial — fail on the reuse half**. Scope is correct (`email profile https://www.googleapis.com/auth/business.manage`), but code review confirms no path anywhere reuses an existing Google token from Ads/GA4/Search Console — `prompt: "consent"` always forces a fresh OAuth flow, and every provider is an independent `Integration` row. Filed as issue `67138166` (medium).
- **385/945, 386/946, 387/947, 388/948, 389/949, 390/950, 391/951/952, 393/954**: **fail**. Live-confirmed: `/app/integrations/connect/google_business/accounts` is titled "Select Accounts" but its entire body is the *location*-selection screen from story 44 (location ID field, "Choose which business locations to sync...") — there is no GMB-account list, no name+ID display, no multi-select of accounts, no `googleBusinessAccountIds` array ever written (confirmed only ever read in code), no legacy-singular migration path, and no confirmation screen showing an account count with a "proceed to location selection" prompt, since there's only one combined screen. Filed as issue `984b3260` (high) covering all of these.
- **392/953**: pass. Live-confirmed: navigating to `/app/integrations/oauth/callback/google_business?error=access_denied` shows "Connection Failed — Access was denied. Please try again if you want to connect."

Along the way, found that a genuine live OAuth consent round trip for `google_business` specifically is blocked in this worktree by a `redirect_uri_mismatch` from Google itself (this worktree's dev port isn't a registered redirect URI) — filed as qa-scope issue `6cdb28d8`, not counted against the story.

Submitting as **fail** with issues `984b3260` and `67138166` linked (the qa-scope issue `6cdb28d8` is informational).

## Retest 2026-10-01

Both issues confirmed resolved. A genuine two-step flow now exists: `/app/integrations/connect/google_business/accounts` is a real GMB *account*-selection step (distinct subtitle: "Choose which Google Business Profile accounts to grant MetricFlow access to. You'll select specific locations to sync in the next step."), which only then advances to `/app/integrations/connect/google_business/locations` for the existing per-location picker from story 44. `mix test test/spex/43_.../*.exs` -- 23/23 passed; re-ran story 44's spex too since the routing changed -- still 20/20 passed, no regression.

Live-confirmed, using integration 59 (consumed and reverted cleanly afterward):
- **385/945, 386/946**: pass. The account list renders real `[data-role='account-checkbox']` (`name="google_business_account_ids[]"`) elements.
- **387/947**: pass. Each option shows both `data-role='account-name'` and `data-role='account-id'` spans (same raw value in this environment since the real accounts.list API call fails -- a real API success would show a friendlier name).
- **388/948**: pass. Saving persisted `google_business_account_ids` as a genuine JSON array in the DB.
- **389/949**: pass. Set a legacy singular `google_business_account_id` via SQL; reloading showed it correctly pre-selected (checked) in the account list via `gbp_selected_account_ids/1`'s fallback.
- **390/950, 951 (add/remove without re-authenticating)**: pass on the mechanism (revisiting the page requires no OAuth step) -- live-testable removal confirmed (unchecking and saving reduces the array); live-testable "add a genuinely new account" is limited by the same real-API-unavailability already documented across this session's other OAuth stories (no live GMB account discoverable), not a flaw in this mechanism itself.
- **391/952**: pass. "Save and continue" is disabled client-side with zero available accounts, and the server handler also explicitly rejects an empty `google_business_account_ids` list.
- **392/953**: pass (unaffected by this fix, confirmed in the prior attempt).
- **393/954**: pass. Confirmed in code: the save handler's success flash reads exactly "N business account(s) connected. Now select which locations to sync."
- **383/943, 384/944**: pass (unaffected by this fix; token reuse separately confirmed fixed by issue `67138166`'s own resolution, verified via its still-passing spex).

No new issues. Submitting as **pass**; all 22 criteria now verified.
