# Qa Story Brief

Story 15: Manual Sync Trigger (Admin)

## Tool

web

## Auth

Use `run_browser_script` with the standard `browser_*` tools. Log in as the seeded QA owner via the password form:

```lua
browser_navigate({ url = "http://localhost:4070/users/log-in" })
browser_wait_for_load({})
browser_scroll_into_view({ selector = "#login_form_password" })
browser_fill({ selector = "#password_email", text = "qa@example.com" })
browser_fill({ selector = "#user_password", text = "hello world!" })
browser_click({ selector = "#login_form_password button[name='user[remember_me]']" })
browser_wait_for_url({ pattern = "/", timeout = 8000 })
```

For the non-admin check, clear cookies (`browser_delete_cookies`) and repeat the same sequence with `qa-member@example.com` / `hello world!` (seeded as `read_only` on "QA Test Account").

App base URL: `http://localhost:4070` — this worktree's own dev server, confirmed live during story 13's QA pass on this same checkout today. Ignore the task prompt's stale "erroring" note.

## Seeds

Seeds already in place. `qa@example.com` (owner) has 7 personally-connected integrations (see story 13's brief). `qa-member@example.com` (read_only) has none of their own.

**Critical environment note carried over from story 13's QA pass:** this worktree's dev server reads database `metric_flow_dev_wc_bd0baac8`, NOT the default `metric_flow_dev`. Any `mix run -e` shell must `export DATABASE_NAME=metric_flow_dev_wc_bd0baac8` first, or it silently writes to the wrong database.

For the ownership-vs-role scenario below, a synthetic integration row is inserted directly for `qa-member@example.com`'s own `user_id` by copying an existing row's already-valid encrypted `access_token`/`refresh_token` bytes (Cloak-encrypted binaries decrypt fine regardless of which row they're copied onto, so the app doesn't crash loading it — the copied plaintext itself is nonsensical but irrelevant for a UI-only check). This row is a consumable, single-use setup for this pass only — delete it after observing the result so it doesn't leak into other QA passes as a phantom "connected" platform for qa-member.

## What To Test

- **110/580** — As qa@example.com (owns integrations, is account owner): `/app/integrations` shows a "Sync Now" button on each connected card.
- **111/582** — Click "Sync Now" on an integration with a selected account (e.g. google_ads); expect the button to disable, an info flash "Sync started for ...", and the card badge to show "Syncing" with a spinner.
- **112/583** — Same click: confirm the loading indicator (spinner + "Syncing" badge) appears immediately, before completion.
- **113/584** — Wait for the async sync to finish (subscribed via PubSub `user:<id>:sync`); confirm a completion badge "Synced N records at TIMESTAMP UTC" replaces the syncing indicator. If the underlying provider isn't really reachable in dev, note whatever real terminal state is reached (success or failure) rather than waiting indefinitely.
- **114/585** — If a sync fails (e.g. an integration with no valid provider access), confirm the error flash names what went wrong rather than failing silently.
- **115/586** — Not independently testable live (would require inspecting the automated daily scheduler's own run alongside a manual one); verify via code review of `MetricFlow.DataSync`/the scheduler that a manual `sync_integration/2` call doesn't touch or cancel the scheduled job, and note this as a code-review-backed pass.
- **587** — Click "Sync Now" once, then immediately try clicking it again (or re-dispatch the same event) while still syncing; confirm the button is disabled and/or a second attempt is rejected with an "already in progress" message rather than starting a second sync.
- **581 (the real question)** — As qa-member@example.com (read_only, owns nothing): confirm `/app/integrations` shows zero "Sync Now" buttons. Then, with the synthetic integration row inserted for qa-member's own `user_id` (see Seeds), reload as qa-member and check whether a "Sync Now" button now appears for *that* card despite the read_only role — this distinguishes real admin-role gating from incidental per-user-ownership gating, since `lib/metric_flow_web/live/integration_live/index.ex` and its test file have no visible role/admin check anywhere in the Sync Now button's rendering.

## Result Path

.code_my_spec/qa/15/screenshots/

## Retest Notes (post-fix)

Issue a2063fdc resolved: `mount/3` now computes `can_sync` from the user's actual account role (`owner`/`admin` only) via `Accounts.get_user_role/3`, gating both the button's rendering and the `sync` event handlers server-side (not just a hidden button). Confirmed live: qa@example.com (owner) still sees and can use Sync Now on http://127.0.0.1:59302 -- no regression. The specific "non-admin who personally owns an integration" case is covered by the coder's own passing story 15 spex suite (14/14); a live repro of that exact combination still isn't practical here for the same DB-encryption reasons noted in the original issue, so this is accepted on the strength of the code fix (role check is now unconditional and independent of ownership) plus the passing automated suite.

## Setup Notes

Results are recorded via `submit_qa_result` (a DB-backed attempt) plus `create_issue` for findings — there is no `result.md` file; the path above is where screenshot evidence is saved.

`MetricFlow.Integrations.list_integrations/1` (confirmed reading the source during story 13's QA pass) filters strictly by `i.user_id == scope.user.id` — integrations are private to the individual `User` who connected them, not shared at the team/account level. This means criterion 581's spex (`given_ :agency_member_registered`) may be passing because the fresh member simply owns zero integrations, not because of any admin-role check.

**Follow-up on the synthetic-row test:** attempted during this pass by inserting a second integration row for qa-member's own user_id, copying a real row's encrypted `access_token`/`refresh_token` bytes. The card still rendered "Not connected" for it, unexpectedly. Debugging this needs the *actual* `CLOAK_KEY` this worktree's `mix phx.server` process was started with — the literal value checked into `.env.dev` decodes to only 33 raw bytes (`Cloak.Ciphers.AES.GCM` needs exactly 32), so it cannot be the real runtime key; the harness must inject a corrected value into the server's OS environment that differs from the file on disk. Don't waste time re-deriving it from `.env.dev` directly; if this needs resolving, ask how the running server's actual `CLOAK_KEY` can be obtained, or drive the check from inside a live `IEx.attach`-style hook on the running node instead of a fresh `mix run` process. The row was deleted after this pass (id 60, user_id 6) so it doesn't linger as a phantom platform for qa-member.
