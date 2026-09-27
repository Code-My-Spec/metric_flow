# QA Story Brief — 1103: Stripe Webhook Handler: Subscription Lifecycle Sync

## Tool

curl

## Auth

No user/session auth. The endpoint is `POST https://dev.metric-flow.app/billing/webhooks` (Cloudflare tunnel → the running dev server), secured only by the `Stripe-Signature` header.

Sign every payload yourself with the webhook secret from `.env.dev` (`STRIPE_WEBHOOK_SECRET`) — do not use `stripe trigger`, since scenarios need specific `id`/`account`/subscription fields that `stripe trigger` cannot set.

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

For an invalid signature, send `Stripe-Signature: t=$TS,v1=$(printf '0%.0s' {1..64})` instead of the computed value.

## Seeds

No LiveView/user seeds needed. To observe real persisted state (not just HTTP status), query Postgres directly without booting the full app (booting the full app starts the Cloudflare tunnel GenServer and can collide with the running server):

```bash
mix run --no-start -e "Application.ensure_all_started(:postgrex); Application.ensure_all_started(:ecto); MetricFlow.Repo.start_link([]); <query here>"
```

For scenarios that need a pre-existing subscription row (payment-failed, cancellation, duplicate-delivery follow-up), insert one directly via that pattern, e.g.:

```elixir
alias MetricFlow.Billing.BillingRepository
BillingRepository.upsert_subscription(%{stripe_subscription_id: "sub_qa_1103", stripe_customer_id: "cus_qa_1103", status: :active, account_id: <a real account id — look one up via MetricFlow.Repo.one(MetricFlow.Accounts.Account) or similar>})
```

Note: `Subscription.changeset/2` requires `account_id`. Look up an existing account id first (e.g. the QA seed account) rather than guessing one, or the insert itself will fail with the same defect scenario 3 below is testing.

Use fresh, never-before-used `evt_...` IDs for every scenario except the deliberate duplicate-delivery scenario (11), which reuses one within the same run. `mark_event_processed/1` records event IDs permanently, so a previously-used event ID is spent — pick a new one each pass.

## What To Test

- **Valid signature accepted** (AC: valid signature verified) — POST a `customer.subscription.created` event with a correctly computed signature. Expect `200 {"received": true}`.
- **Missing signature rejected** (AC: invalid/missing signature rejected) — POST the same shape with no `Stripe-Signature` header. Expect `400`.
- **Invalid signature rejected** — POST with a garbage `v1=` value. Expect `400`.
- **Recognized event updates local state** (AC: recognized event updates local subscription state) — Pre-insert a subscription row (see Seeds) with `status: :active`, then POST `customer.subscription.updated` for that `stripe_subscription_id` with `"status": "past_due"`. Expect `200`, **and** query the DB afterward to confirm `status` actually changed to `past_due`. This is the critical check: the controller test suite only asserts the HTTP status, never the persisted row, and `Billing.handle_subscription_event/1` ignores the return value of `BillingRepository.upsert_subscription/1` — if the insert/update fails validation (e.g. missing required `account_id`), the handler still returns `:ok` and the controller still returns 200. Test a **fresh subscription.created event with no pre-existing row** too, since that path never supplies `account_id` in the attrs — check whether a row is created at all.
- **Unrecognized event acknowledged and ignored** — POST `{"type": "some.unknown.event"}`. Expect `200 {"received": true, "ignored": true}`.
- **Payment failure marks past_due and notifies user** — Pre-insert a subscription linked to a real account/user (an account with `originator_user_id` set to a user with a known email), then POST `invoice.payment_failed` referencing that subscription's `stripe_subscription_id`. Expect `200`, subscription status `past_due` in the DB, and an email in the dev mailbox (`https://dev.metric-flow.app/dev/mailbox` or the app's `/dev/mailbox`) addressed to that user.
- **Cancellation at period end** — POST `customer.subscription.deleted` for an existing subscription. Expect `200`, DB status `cancelled`. Then check whether anything actually downgrades the account to a free plan — search for a "free" plan assignment triggered by cancellation. Current handler code only sets `status: :cancelled`; no plan reassignment is visible. Confirm whether the account's effective plan actually changes, or only the subscription row's status does.
- **Duplicate delivery is a no-op** — POST the same event (same `id`) twice. First: `200 {"received": true}`. Second: expect `200 {"received": true, "duplicate": true}` and confirm the underlying state was not changed/reprocessed a second time (e.g. no double email sent for a payment_failed duplicate).
- **Received event logged with required fields** — After any successful POST, query `processed_stripe_events` for that event's row. The AC requires event ID, type, processed status, and timestamp to be recorded. Check what's actually in the row — the schema (`ProcessedStripeEvent`) only has `stripe_event_id` and `inserted_at`; there is no `type` or `status` column. Confirm what's actually persisted vs. what the AC asks for.
- **Processing failure logged, retry succeeds cleanly** — POST with a bad signature first (expect 400), then retry the identical payload with a correctly computed signature (expect 200). Also check whether anything is written to the application/error log for the bad-signature attempt (the controller's signature-failure branches don't call `Logger.error`; only post-verification processing errors do) — note whether that matches the AC's intent of "webhook processing failures are captured... in an internal error log."
- **Connected-account event attributed to correct agency** — Insert a `StripeAccount` row (`stripe_account_id`, `agency_account_id`) via the DB pattern above, then POST a `customer.subscription.updated` event with a top-level `"account": "<that stripe_account_id>"`. Expect `200`. Then check whether the resulting subscription row is actually associated with that agency's account anywhere (`account_id` / agency linkage) — `handle_subscription_event/1` never reads `event["account"]`, so confirm whether attribution is real or the event is just accepted without being linked to the agency.
- **Event with unrecognized account context is rejected** — POST an event with `"account": "acct_never_registered_..."` (never inserted into `billing_stripe_accounts`). Expect `400`.
- **Agency-specific vs platform webhook secret** — Confirm (by reading `verify_event/2` in the controller and `StripeClient.verify_webhook_signature/3`) whether a different secret is actually used for connected-account events vs. direct/platform events, or whether one single `:stripe_webhook_secret` config value is used regardless of the event's `account` field. Report what you find — this doesn't need a separate HTTP scenario since it's answered directly from the single config lookup already exercised by every other scenario above.

## Result Path

`.code_my_spec/qa/1103/result.md` (evidence/notes only — findings and the pass/fail verdict go through `create_issue` and `submit_qa_result`, not this file).

## Setup Notes

This story's acceptance criteria describe a much larger surface (agency-specific secrets, connected-account attribution, free-plan downgrade, rich audit logging) than `MetricFlowWeb.BillingWebhookController` + `MetricFlow.Billing` currently implement. There is also a second, apparently dead module, `MetricFlow.Billing.WebhookProcessor`, with overlapping-but-different logic (it does try to extract `account_id` from event metadata) that the controller never calls — `Billing.process_webhook_event/1` is the only path actually wired to `/billing/webhooks`. Don't test `WebhookProcessor` directly; it's unreachable from the HTTP endpoint.

The existing BDD spex files under `test/spex/.../50_stripe_webhook_handler_.../` and the `stripe-webhook-handler-subscription-lifecycle-sync-91f6ce04/` directory assert HTTP status codes only — none of them query the database to confirm state actually changed. A 200 response does not mean the write succeeded; verify persisted rows directly per the scenarios above.

Avoid running plain `mix run -e` from this worktree more than necessary — it boots the full application (including the Cloudflare tunnel GenServer) and can collide with the actually-running dev server. Use `mix run --no-start -e "...Repo.start_link([])..."` for all DB inspection.
