# QA Brief: Story 1101 — Agency Plan Management: Create Custom Subscription Plans

## Component
MetricFlowWeb.AgencyLive.Plans (`lib/metric_flow_web/live/agency_live/plans.ex`)
Route: `/app/agency/plans` (see router.ex agency live_session)

## Prior findings
Two issues from an earlier pass are resolved: missing billing tables migration
(b4c99209) and StripeClient lacking product/price creation (21f958fa). This
brief covers a fresh, full pass against all 9 gherkin rules / 15 criteria.

## Auth / setup
- Log in as qa@example.com / hello world! per plan.md.
- Need an agency-type account with no Stripe connected (to test the blocking
  rule) and, separately, one with Stripe connected (to test creation/rotation).
- Seed script: priv/repo/qa_seeds_1101.exs creates "QA Agency 1101" (team
  account, owned by qa@example.com) with no Stripe account initially.
- Existing DB already has agency accounts id=1 ("Desert First Cleaning") and
  id=3 ("My Test Agency") with StripeAccount rows carrying synthetic
  stripe_account_id values from prior story-1103 QA (acct_qa1103_connected,
  acct_qa1103c_connected) — these are NOT real Stripe Connect accounts and
  will fail real Stripe API calls (create_product/create_price hit
  api.stripe.com for real). Real Stripe Connect onboarding is required to
  fully exercise the create/rotate-price scenarios end-to-end.

## Scenarios to test
1. Agency admin creates a new plan (happy path, needs real Stripe Connect)
2. Plan name cannot be blank (client-side changeset validation, no Stripe needed)
3. Plan price must be positive (same)
4. Plan creation provisions a Stripe Product and Price (needs real Stripe Connect)
5. Plan creation blocked without a connected Stripe account (no Stripe needed)
6. Updating plan price rotates the Stripe Price (needs real Stripe Connect) —
   CODE REVIEW FLAG: `handle_event("update_plan", ...)` in plans.ex calls
   `Plan.changeset/2` + `Repo.update/1` directly — no call into
   `MetricFlow.Billing` or `StripeClient` at all. There is no
   `Billing.update_plan/2` function in lib/metric_flow/billing.ex. This looks
   like the rotation was never implemented; confirm via UI.
7. Deactivating a plan stops new signups but keeps existing subscribers
   (DB-level check via BillingRepository.list_plans/1 filtering active==true;
   can verify without Stripe)
8. Another agency's admin cannot see or select this plan (DB scoping, no
   Stripe needed — can seed plan rows directly)
9. Agency settings lists active plans with Stripe Price ID and status (no
   Stripe needed once any plan row exists)

## Tooling
- vibium MCP browser tools per plan.md Tools Registry.
- mix run --no-start seeds (MIX_ENV=dev, since MIX_ENV=dev_cli is the wrong env in this worktree).
