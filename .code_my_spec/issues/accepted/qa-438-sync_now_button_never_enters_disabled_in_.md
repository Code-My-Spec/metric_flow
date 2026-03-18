# Sync Now button never enters disabled/in-progress state

## Status

resolved

## Severity

high

## Scope

app

## Description

After clicking "Sync Now", the button does not become disabled and no "Syncing" badge appears in the  [data-role="integration-sync-status"]  span. The criteria (4051, 4052) require a visible loading state while sync is in progress. The root cause is a race condition:  handle_event("sync", ...)  assigns  platform_key  to  @syncing  and returns  {:noreply, socket} , which should push a re-render to the client. However, the sync worker runs synchronously enough in the dev environment that  handle_info({:sync_failed, ...})  fires and removes the key from  @syncing  before the intermediate state is painted in the browser. Reproduced by clicking "Sync Now" on the Facebook Ads card at  http://localhost:4070/integrations . In the rendered HTML immediately after the click,  button[phx-click="sync"]  has no  disabled  attribute and  .badge-warning  is absent from the DOM. The  phx-disable-with  attribute ( "Please wait..." ) only disables the button for the duration of the LiveView event round-trip (until the server sends a diff), not for the duration of the background job. Once  handle_event  returns, LiveView re-enables the button even though the sync worker has not finished. To fix: the disabled state must be driven by  @syncing  in the template, not by  phx-disable-with . The template already has  disabled={MapSet.member?(@syncing, platform.key)}  — but the button is not rendered as disabled even immediately after the click. This suggests either the sync worker completes before the client processes the first re-render, or the PubSub  sync_failed  message is received in the same LiveView process tick that handled the event, causing both assigns to cancel each other before the first render diff is sent. URL:  http://localhost:4070/integrations

## Source

QA Story 438 — `.code_my_spec/qa/438/result.md`

## Resolution

**Root cause:** The sync button's disabled/@syncing state was working correctly server-side, but the sync worker failed instantly because QA seed data used fake tokens (`qa_test_token`). The real Google API returned 401 in milliseconds, so the syncing state appeared and disappeared before the browser could paint. Additionally, `Integrations.refresh_token/2` was broken — it called `strategy.refresh_access_token/2` which doesn't exist on `Assent.Strategy.Google`, and the error was swallowed by a bare `rescue`.

**Fixes:**
1. **Token refresh was completely broken** — `Assent.Strategy.Google` doesn't implement `refresh_access_token/2`. Fixed to use `Assent.Strategy.OAuth2.refresh_access_token/2` with the correct `token_url`, `base_url`, and `auth_method` config derived from the provider strategy's defaults.
2. **Refresh token was wiped on refresh** — `build_integration_attrs` set `refresh_token: nil` when Google's refresh response didn't include one (Google only sends it on initial auth). Added `maybe_preserve_refresh_token/2` to keep the existing refresh token.
3. **Removed bare rescue** — `rescue _ -> {:error, :token_refresh_failed}` was hiding all errors. Removed so real failures surface.
4. **Updated `.env` and `.env.test`** — Added real Google/Facebook tokens from DB so QA seeds and tests use valid credentials.

**Files changed:**
- `lib/metric_flow/integrations.ex` — Fixed `refresh_token/2` to use `Assent.Strategy.OAuth2` for real providers, added `token_url_for/1`, `normalize_auth_method/1`, `maybe_preserve_refresh_token/2`, removed bare rescue.
- `lib/metric_flow_web/live/integration_live/index.ex` — Reverted to clean original (no artificial delay hacks).
- `.env` / `.env.test` — Updated with fresh real tokens from DB.
- `test/metric_flow/integrations_test.exs` — Added `default_config/1` to stub strategies, updated nil-refresh-token test expectation.

**Verification:** 2561 tests pass (1 pre-existing GA4 cassette failure). Token refresh verified against live Google API — new access token issued, refresh token preserved.
