# QA Story Brief — 1103: Stripe Webhook Handler: Subscription Lifecycle Sync (retest)

This is a retest after commit c15d5e6 fixed all 7 previously-filed issues
(missing account_id on persist, no route, no free-plan downgrade, single
webhook secret, thin audit log, connected-account attribution, no
persistence at all). Verify each fix against the running app rather than
trusting the resolution notes.

## Tool

curl

## Auth

No user/session auth. The endpoint is `POST https://dev.metric-flow.app/billing/webhooks`
(Cloudflare tunnel → the running dev server), secured only by the
`Stripe-Signature` header. Confirmed reachable: an unsigned POST already
returns `400 {"error":"Missing Stripe-Signature header"}` (route exists,
issue 2766738a's fix holds).

```bash
SECRET=$(grep STRIPE_WEBHOOK_SECRET .env.dev | cut -d= -f2)
PAYLOAD='<json body>'
TS=$(date +%s)
SIG=$(printf '%s.%s' "$TS" "$PAYLOAD" | openssl dgst -sha256 -hmac "$SECRET" | sed 's/^.* //')
curl -s -o /tmp/resp.json -w '%{http_code}\n' -X POST https://dev.metric-flow.app/billing/webhooks \
  -H 'Content-Type: application/json' \
  -H "Stripe-Signature: t=$TS,v1=$SIG" \
  -d "$PAYLOAD"
cat /tmp/resp.json
```

For an invalid signature, send `Stripe-Signature: t=$TS,v1=$(printf '0%.0s' {1..64})` instead.

## Seeds

Query/mutate Postgres directly without booting the full app:

```bash
MIX_ENV=dev mix run --no-start -e "Application.ensure_all_started(:postgrex); Application.ensure_all_started(:ecto); MetricFlow.Repo.start_link([]); <query here>"
```

Known state as of this pass:
- Account 1 (`johns10@gmail.com`, user id 1) already has subscription `sub_qa1103_seed` (status `active`, `plan_id: nil`).
- Accounts 3, 4, 5, 6 exist with no subscription row — free of the `Subscription` unique constraint on `account_id`.
- `billing_stripe_accounts` already has `acct_qa1103_connected -> agency_account_id: 1` — **do not reuse for the attribution scenario**: account 1 already owns a subscription, and `Subscription.changeset/2` has `unique_constraint([:account_id])`, so a second insert for account_id 1 will fail the DB constraint, not the attribution logic. Register a **new** `StripeAccount` pointed at an account with no existing subscription (e.g. account 3) instead.
- No `billing_plans` rows exist. Create one directly (bypassing Stripe provisioning, since this is only to observe the downgrade write) to test the cancellation-clears-plan behavior meaningfully:
  ```elixir
  {:ok, plan} = %MetricFlow.Billing.Plan{} |> MetricFlow.Billing.Plan.changeset(%{name: "QA Plan", price_cents: 1000, currency: "usd", billing_interval: :monthly}) |> MetricFlow.Repo.insert()
  MetricFlow.Repo.get_by(MetricFlow.Billing.Subscription, stripe_subscription_id: "sub_qa1103_seed") |> Ecto.Changeset.change(plan_id: plan.id) |> MetricFlow.Repo.update()
  ```
- All `evt_qa1103_*` IDs from the previous pass are permanently spent (`mark_event_processed/2` records them forever, and they're stuck in the DB from before the fix). Use a fresh prefix for every event this pass, e.g. `evt_qa1103c_<scenario>_$(date +%s)`, except the deliberate duplicate scenario, which reuses one within this run only.

## What To Test

- **Fresh `customer.subscription.created`, no prior row, WITH checkout metadata** (critical-fix retest) — POST for account 4 (no existing subscription) with `data.object.metadata.account_id: "4"` and a fresh `stripe_subscription_id`. Expect `200`, and a `billing_subscriptions` row created with `account_id: 4`. This is the realistic path: `create_checkout_session/3` now embeds `account_id` in Stripe subscription metadata, so a real checkout-originated event carries it.
- **Fresh `customer.subscription.created`, no prior row, WITHOUT any account context** (edge case) — same shape but no metadata and no top-level `account` field, fresh sub id. Expect the previously-critical silent-200 bug to be gone: confirm the response is **not** a bare `200` with no row — it should surface the missing-account_id failure (likely `500`) rather than silently succeeding. Verify no row was created either way.
- **Recognized event updates existing row** — POST `customer.subscription.updated` for `sub_qa1103_seed` changing status to `past_due`. Expect `200`, and DB status actually `past_due` afterward.
- **Payment failure marks past_due and notifies user** — POST `invoice.payment_failed` referencing `sub_qa1103_seed`. Expect `200`, DB status `past_due`, and a payment-failed email in the dev mailbox addressed to `johns10@gmail.com`.
- **Cancellation downgrades to free (plan cleared)** — First attach the QA plan to `sub_qa1103_seed` per Seeds. POST `customer.subscription.deleted` for `sub_qa1103_seed`. Expect `200`, DB `status: cancelled`, `cancelled_at` set, **and `plan_id` cleared back to `nil`** — confirming the account no longer has a paid plan attached.
- **Duplicate delivery is a no-op** — POST one fresh event twice (same `id`). First: `200 {"received":true}`. Second: `200 {"received":true,"duplicate":true}`, and confirm state wasn't reprocessed (e.g., no second email for a payment_failed duplicate).
- **Received event logged with required fields** — After a successful POST, query `processed_stripe_events` for that event. Confirm the row now has `event_type` and `status` populated (not just `stripe_event_id`/`inserted_at`), and that `status` becomes `processed` (not stuck at `processing`).
- **Processing failure logged, retry succeeds cleanly** — POST with a bad signature (expect `400`), then retry the identical payload with a correct signature (expect `200`).
- **Connected-account event attributed to the correct agency** — Register a fresh `StripeAccount` (`stripe_account_id: "acct_qa1103c_connected"`, `agency_account_id: 3` — account 3 has no existing subscription). POST `customer.subscription.updated` with top-level `"account": "acct_qa1103c_connected"` and a fresh sub id, no metadata. Expect `200`, and a `billing_subscriptions` row created with `account_id: 3` (the agency's account) — confirming attribution actually happens now, not just that the event is accepted.
- **Event with unrecognized account context is rejected** — POST with `"account": "acct_never_registered_..."`. Expect `400`.
- **Agency-specific vs platform secret** — Read-only check: `.env.dev` only defines `STRIPE_WEBHOOK_SECRET`, not `STRIPE_CONNECT_WEBHOOK_SECRET`, so the fallback branch in `verify_event/2` is unexercised in this environment (`Application.get_env(:metric_flow, :stripe_connect_webhook_secret)` resolves to `nil`, short-circuiting to the original failure). Confirm the platform secret still verifies every scenario above and note that a genuine second-secret test is blocked by missing dev config, not by the code.

## Result Path

`.code_my_spec/qa/1103/result.md` (evidence/notes only — findings and the pass/fail verdict go through `create_issue` and `submit_qa_result`, not this file).

## Setup Notes

`Subscription.changeset/2` has `unique_constraint([:account_id])` — one subscription per account. Any scenario that inserts a *new* subscription must target an account with no existing row (3, 4, 5, or 6), not account 1 (already has `sub_qa1103_seed`) or 15 (already has `sub_dev_client_beta`).
