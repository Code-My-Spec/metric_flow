# Qa Story Brief — Story 49: Agency Customer Billing Routing

## Tool

web (MCP browser) for checkout/agency-settings LiveViews; curl for `/billing/webhooks` (the `:api` pipeline, no session); `mix test` for the two criteria that require a real Stripe Connect account this platform's Stripe test account doesn't have.

## Auth

App URL for this pass: `http://127.0.0.1:59302` (this working copy's own instance — not main's).

Log in via the password form (see `.code_my_spec/qa/plan.md` Tools Registry for the exact MCP sequence):
- `qa@example.com` / `hello world!` — base QA owner, no agency affiliation by default.

Switch users by `browser_delete_cookies` then re-login.

## Seeds

1. `mix run priv/repo/qa_seeds.exs` (or verify login works first — server may already be seeded).
2. This story needs three agency fixtures beyond the base seed. None can go through the real Stripe API (platform test account has Connect disabled — plan.md "Known limitation"). Seed directly via SQL, same synthetic-`StripeAccount`-row pattern already used for stories 47/48/49-adjacent work:
   - **Agency A ("QA49 Connected")** — team account, `type: agency`, owner `qa49-connected@example.com`. One `billing_stripe_accounts` row (`agency_account_id` = its account id, `onboarding_status: 'complete'`, synthetic `stripe_account_id` e.g. `acct_qa49connected`). One `billing_plans` row (`agency_account_id` = its account id, synthetic `stripe_price_id` e.g. `price_qa49_agency`).
   - **Agency B ("QA49 No Plans")** — same as A but zero `billing_plans` rows (StripeAccount still connected). Used for criterion 485.
   - **Agency C ("QA49 Not Connected")** — has a `billing_plans` row but no `billing_stripe_accounts` row at all. Used for criterion 487.
3. For each agency, register one client user through its real referral link (Agencies.generate_referral_token/1, called via a script — see scenario 1) rather than a raw SQL grant, so the client relationship itself is genuine.

## What To Test

- **427/482 — signup via valid referral link stores agency association.** Generate a token for Agency A with `Agencies.generate_referral_token(agency_a_account_id)` (call via script, not UI — no UI surface exposes this token currently). Visit `/users/register?ref=<token>`, register a fresh user, confirm via the dev mailbox magic link, log in, visit `/app/subscriptions/checkout` and confirm the plan shown is Agency A's plan name (not the platform default). Cross-check with `Agencies.find_client_agency_account_id/1` via script.
- **483 — expired/invalid referral token proceeds without association.** Visit `/users/register?ref=not-a-real-token`, register, confirm via mailbox, log in. Verify `Agencies.find_client_agency_account_id/1` returns nil and checkout shows the platform's own default plan, not an error.
- **428/484 — agency client sees the agency's plan, not the platform's.** As Agency A's client (from scenario 1), visit `/app/subscriptions/checkout`; confirm the agency's plan name/price render and the platform default does not.
- **485 — agency with zero plans shows nothing to subscribe to, NOT the platform's default.** As Agency B's client, visit `/app/subscriptions/checkout`. **This is the most likely real bug in this story**: `load_plans/1` in `checkout.ex` falls back to `BillingRepository.list_plans(nil)` (platform plans) whenever the resolved `agency_account_id`'s own plan list is empty — with no distinction between "this account has no agency at all" (where falling back to the platform's plan is correct) and "this account IS a client of an agency that simply hasn't configured a plan yet" (where criterion 485's own spex explicitly asserts `refute html =~ "$49.99"`, i.e. the platform plan must NOT appear). Confirm live whether the platform's plan (or a "Subscribe" button at all) renders for Agency B's client. If it does, file it — the exunit spex for 485 may be passing vacuously if no platform plan with a matching price exists in the test sandbox, so a live check with a real platform plan seeded is the only way to catch this.
- **429/486 — checkout session created against the agency's connected Stripe account.** Do NOT click Subscribe live — the platform's Stripe test account has Connect disabled and the call will fail against the real API (plan.md limitation). Verify instead with `mix test test/metric_flow/billing_test.exs` — look specifically for a test asserting `create_checkout_session/3` passes `stripe_account: <agency's stripe_account_id>` through to `StripeClient`.
- **487 — checkout blocked when agency has no connected Stripe account.** As Agency C's client, visit checkout. Confirm no "Subscribe" button renders (`data-role="subscribe-button"` absent) and "Billing is currently unavailable for this plan" shows instead.
- **430/488 — successful payment persists subscription_id, stripe_customer_id, and agency attribution.** The criterion_430 spex's own assertion (`html =~ "subscri"` etc. after visiting `?success=true&session_id=...`) is checked in code and found to be a near-tautology (matches the page's own static subtitle) — it does not actually verify persistence. Test the real mechanism instead: send a `customer.subscription.created` webhook (see curl recipe below) carrying Agency A's `stripe_account_id` and a `metadata.account_id` matching the client account from scenario 1's ID. After, query `billing_subscriptions` for that account: confirm `stripe_subscription_id`, `stripe_customer_id`, and `account_id` are populated, and that `account_id` resolves (via `Agencies.find_client_agency_account_id/1` or the subscription's `plan_id` → `plan.agency_account_id`) back to Agency A — this is how "agency_id" is actually captured, since `billing_subscriptions` has no literal `agency_id` column (confirmed in `lib/metric_flow/billing/subscription.ex`). Note this as informational only if it resolves correctly; it is not itself a bug.
- **431/489 — webhook for an agency customer is routed using the agency's stripe_account_id.** Same webhook as above; confirm response is 200/202 and the persisted subscription's `account_id` is the *client's* account (not the agency's own), matching `metadata.account_id` precedence over the bare agency fallback in `Billing.resolve_account/1`.
- **490 — webhook with unrecognized stripe_account_id is rejected, not guessed onto any agency.** POST a `customer.subscription.created` event with `"account": "acct_totally_unknown"` and no matching `billing_stripe_accounts` row. Confirm HTTP 400 and `{"error": "...unrecognized..."}` — matches `criterion_490` spex exactly, should be straightforward to reproduce live.
- **432/491 — agency customer subscription status syncs to past_due and canceled via webhooks.** Using the subscription created in the 430/488 scenario, send `customer.subscription.updated` (status `past_due`) and `customer.subscription.deleted` events with the same `stripe_subscription_id`, both carrying Agency A's `stripe_account_id`. Confirm the DB row's `status` updates to `:past_due` then `:cancelled`, and `account_id` is preserved (not nulled) per `resolve_update_account_id/2`'s fallback logic in `billing.ex`.
- **433/492 — existing agency customer subscription preserved (flagged) when agency Stripe disconnects.** Log in as Agency A's owner, visit `/app/agency/stripe-connect`, click `[data-role=disconnect-stripe]`. Confirm the client's subscription row from scenario 8 still exists afterward (query DB) rather than being deleted, and check what `BillingRepository.flag_agency_subscriptions_for_review/1` actually sets (read the repository function first) so you can assert on the real flag, not just "row still exists."
- **493 — new customer billing paused while agency Stripe is disconnected.** After the disconnect above, as a *second*, not-yet-subscribed client of Agency A, visit `/app/subscriptions/checkout`. Confirm no Subscribe button renders (same `billing_available?/1` check as criterion 487, now triggered by disconnection rather than never having connected).
- **434/494 — billing context immutable after subscription creation.** As the already-subscribed client from scenario 8 (status now `:cancelled` from scenario 10 — use a fresh subscribed client if you need an `:active` one for a clean assertion), visit `/app/subscriptions/checkout`. Confirm the only action offered is "Cancel Subscription" (`phx-click="cancel_subscription"`) and there is no control anywhere on the page to switch between agency/direct billing context in place.

### Webhook signing recipe (curl)

Stripe signs `t={timestamp},v1={hex_hmac_sha256("{timestamp}.{raw_body}", webhook_secret)}`. Read `STRIPE_WEBHOOK_SECRET` from `.env.dev` and compute the signature with `openssl`:

```bash
SECRET=$(grep STRIPE_WEBHOOK_SECRET .env.dev | cut -d= -f2)
TS=$(date +%s)
BODY='{"id":"evt_...","type":"customer.subscription.created","account":"acct_qa49connected","data":{"object":{...}}}'
SIG=$(printf '%s.%s' "$TS" "$BODY" | openssl dgst -sha256 -hmac "$SECRET" | sed 's/^.* //')
curl -s -X POST http://127.0.0.1:59302/billing/webhooks \
  -H "Content-Type: application/json" \
  -H "Stripe-Signature: t=$TS,v1=$SIG" \
  -d "$BODY"
```

All spex use a single platform `STRIPE_WEBHOOK_SECRET` regardless of the `account` field's presence (this dev environment has one registered endpoint — plan.md "Stripe CLI" section), so sign every test payload with it; the controller's `stripe_connect_webhook_secret` fallback is dead code in this environment unless that env var happens to be set (check `.env.dev` — if absent, don't test that fallback path).

## Result Path

No result.md — findings go through `create_issue` as discovered, session closes with `submit_qa_result` per the workflow doc.

## Results

All scenarios tested live against this worktree's own dev server (127.0.0.1:59302) after discovering and correcting for the per-worktree DATABASE_NAME env var (`metric_flow_dev_wc_bd0baac8`) — my first seeding pass and first several registration attempts had silently landed in the wrong (default) database. Also discovered and documented a separate framework quirk: Playwright's `browser_click` on this app's LiveView submit buttons intermittently never dispatches the underlying `submit` event to the server (confirmed via the app log showing every `validate` event but no `save`), while `document.getElementById(formId).requestSubmit()` via `browser_evaluate` works reliably every time — used that workaround throughout this pass.

**PASS** (13 of 14 criteria pairs):
- 427/482 — referral registration stores agency association (AGENCY_ID_FOR_ACCOUNT resolved correctly)
- 483 — invalid token registers without error or association (AGENCY_ID_FOR_ACCOUNT=nil)
- 428/484 — agency client sees agency's plan, not platform default
- 485 — agency with zero plans shows "No Plans Available", not the platform default (contrary to the brief's own suspicion, this works correctly)
- 429/486 — checkout session created with the agency's stripe_account_id header (direct call, stubbed plug)
- 487 — checkout blocked ("Billing is currently unavailable") when agency has no connected Stripe account
- 430/488 / 431/489 — subscription.created webhook persists stripe_subscription_id/stripe_customer_id/account_id, correctly attributed to the client via metadata.account_id, resolving back to the agency
- 490 — webhook with unrecognized stripe_account_id rejected 400
- 432/491 — status syncs past_due then cancelled via webhooks; account_id preserved throughout, never reassigned to the agency's own account
- 493 — new (not-yet-subscribed) client of a disconnected agency also sees "Billing is currently unavailable"
- 434/494 — already-subscribed client sees only "Cancel Subscription", no billing-context switch control

**FAIL** — 433/492 (issue `2697db6e`, high): subscriptions created through the real webhook flow never get `plan_id` set (`handle_subscription_event/2` for created/updated never populates it, and nothing else in the codebase resolves it from Stripe's price/product data — the only place `plan_id` is ever written is the `deleted` handler, which explicitly nils it out to downgrade to free). `BillingRepository.flag_agency_subscriptions_for_review/1` attributes subscriptions to an agency via a join on `plan_id`, so it silently flags zero real subscriptions on disconnect. Confirmed live: a genuine active webhook-created subscription for Agency A was not flagged after simulating disconnect (`FLAGGED_COUNT=0`). This same root cause also breaks `calculate_mrr/1` for any agency's real subscriptions (outside this story's own criteria, but worth the fix owner's awareness).

## Retest (2026-09-30, plan_id fix — commit bb29b13)

Retested issue `2697db6e` (433/492: subscriptions never get `plan_id` set, breaking disconnect-flagging). Confirmed fixed via direct execution against this checkout's own dev DB (`metric_flow_dev_wc_bd0baac8`):

- Re-created this checkout's `billing_stripe_accounts` row for Agency A (account 55, `acct_qa49connected`) — the original seed from the prior pass had been lost to a DB reset between attempts.
- Sent a fresh `customer.subscription.created` webhook (`sub_qa49_retest_1..4`) carrying `price_qa49_agency` and Agency A's connected account: `Billing.process_webhook_event/1` persisted `plan_id: 6` correctly (verified via `MetricFlow.Billing.BillingRepository.get_plan_by_stripe_price_id/1` resolving the price to Agency A's plan).
- Sent a `customer.subscription.updated` event for the existing `sub_qa49_test1` (account 60, previously `plan_id: nil` from before the fix): `plan_id` backfilled to `6` via the new `resolve_update_plan_id/2` (an uncommitted, in-progress follow-on to the original fix, present on disk at retest time — preserves `plan_id` on updates that don't carry a resolvable price, mirroring the existing `resolve_update_account_id/2` pattern).
- Called `BillingRepository.flag_agency_subscriptions_for_review(55)` directly: returned `{1, nil}` — the subscription was correctly flagged to `:past_due`, versus `{0, nil}` (silently flagging nothing) before the fix.
- `mix test test/metric_flow/billing_test.exs`: 10/10 passed. `mix spex` on story 49's own directory: 21/21 passed.

One transient issue during retest, not a story defect: an in-flight, uncommitted edit to `lib/metric_flow/billing.ex` on this shared worktree caused a momentary `CompileError` on first webhook attempt (another session mid-write); resolved itself on retry once the file settled.

**PASS** — all 14 criteria pairs now verified, issue `2697db6e` closed. `qa_complete` now satisfied.

## Setup Notes

The `resolve_account/1` connected-account path (`Billing.resolve_account/1` in `billing.ex`) prefers `metadata.account_id` over the agency's own account id as a fallback — so scenario 8/9's webhook payloads must include `"metadata": {"account_id": "<client_account_id>"}` inside `data.object` to attribute correctly to the *client*, not the agency. Omitting it will still succeed (falls back to the agency's own account id) but tests a different, less realistic path — do both if time allows, since criterion 431/489's own spex doesn't include metadata at all and would attribute to the agency's account, not a client's, which is a subtlety worth confirming live.
