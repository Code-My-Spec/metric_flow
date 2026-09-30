# Qa Story Brief - Story 51: Agency Admin Customer Subscription Management Dashboard

## Tool

web

## Auth

App URL for this pass: http://127.0.0.1:59302

Base seed users (qa@example.com / hello world!, qa-member@example.com / hello world!) are already in place -- confirmed working during story 47's pass this session. Login sequence:

    browser_navigate(url: 'http://127.0.0.1:59302/users/log-in')
    browser_scroll_into_view(selector: '#login_form_password')
    browser_fill(selector: '#password_email', text: 'qa@example.com')
    browser_fill(selector: '#user_password', text: 'hello world!')
    browser_click(selector: "#login_form_password button[name='user[remember_me]']")
    browser_wait_for_url(pattern: '/', timeout: 15000)

qa@example.com is owner of 'QA Test Account' (id 21) -- switch to it via /app/accounts if a different account is active (session state carries over between stories in this run).

## Seeds

Base seeds already applied (verified in story 47's pass). This story needs Plan + client-Account + Subscription rows under 'QA Test Account' (agency_account_id 21), plus a second agency's data to test cross-agency isolation (criterion 446/509), using 'QA Agency 1101' (id 31) which already has existing plans/subscriptions from earlier QA passes this session -- do not reseed under 31, just read what's there.

Run with the server already up, `--no-start` pattern:

    DATABASE_NAME=metric_flow_dev_wc_bd0baac8 MIX_ENV=dev mix run --no-start -e "Application.ensure_all_started(:postgrex); Application.ensure_all_started(:ecto); MetricFlow.Repo.start_link([])" <script.exs>

Seed at least 2 active + 1 past_due + 1 cancelled subscription under a fresh Plan on agency_account_id 21, with distinct client Account names/stripe_customer_ids (unused suffixes, not reused from prior sessions) so pagination/search/MRR/status-badge criteria are all exercisable from one seed pass. Use `MetricFlow.Billing.BillingRepository.create_plan/1` for the plan (direct DB insert, no Stripe call) and raw `Repo.insert!` for Account + Subscription rows, mirroring the pattern used in story 47's brief.

## What To Test

1. **View customer list** (criteria 443, 505) - navigate to `/app/agency/subscriptions` as qa@example.com on 'QA Test Account'. Expect a table with columns Customer, Plan, Status, Start Date, Period End, Actions, listing the seeded subscriptions with correct plan name and formatted dates.
2. **Summary stats from local data** (criteria 444, 506) - confirm the stats row shows Active Subscribers count matching the seeded active-status rows, MRR as a dollar-formatted sum of active subscriptions' plan price_cents (verify the arithmetic against what you seeded), and a Past Due count. Read `lib/metric_flow/billing/billing_repository.ex` `calculate_mrr/1` and `count_active_agency_subscriptions/1` first so you know the expected numbers before seeding, then confirm the rendered figures match exactly -- these are computed from local DB rows only (no Stripe call).
3. **Status badges** (criteria 448, 512) - confirm each seeded row shows the right badge: active -> `badge-success` "Active", past_due -> `badge-warning` "Past due", cancelled -> `badge-ghost` "Cancelled", trialing (if seeded) -> `badge-info` "Trialing".
4. **Cancel a subscription** (criteria 445, 507) - click Cancel on an active row (accept the `data-confirm` dialog). `Billing.cancel_subscription/1` calls the real Stripe API (`StripeClient.cancel_subscription/1`) against the seeded subscription's fake `stripe_subscription_id`, which does not exist on Stripe -- per `.code_my_spec/qa/plan.md`'s known-limitation section this is expected to fail with a real Stripe error (e.g. "No such subscription"), shown via `put_flash(:error, "Failed to cancel: ...")`. Record the exact flash text and confirm the subscription's local status is unchanged (still `:active`) after the failed call -- this is the correct behavior, matching how story 47's disconnect failure path behaved. This confirms the code *attempts* the real cancel-at-period-end call; note the happy path (actual successful cancellation) cannot be verified live for the same platform reason and should instead be spot-checked against `mix test test/metric_flow_web/live/agency_live/subscriptions_test.exs test/metric_flow/billing_test.exs`.
5. **Cancel-already-cancelled is a no-op** (criterion 508) - the Cancel button only renders `:if={sub.status == :active}` (see source), so a cancelled row has no Cancel button in the UI at all -- confirm this directly (no button present on a `:cancelled` row) and treat that as satisfying the criterion at the UI layer; also grep `Billing.cancel_subscription/1` and `BillingRepository.get_subscription_by_account_id/1` to confirm the query only matches non-cancelled-or-still-in-period subscriptions, so a direct re-invocation on an already-cancelled account would hit the `{:error, :no_subscription}` branch (no-op, not a crash) -- note this as a code-read finding since it isn't reachable via the UI.
6. **Cross-agency isolation** (criteria 446, 509) - while active account is 'QA Test Account' (21), confirm none of 'QA Agency 1101' (31)'s subscriptions/customers appear in the list or are reachable by ID. Then switch active account to 'QA Agency 1101' and confirm the reverse -- account 21's seeded rows do not appear there either.
7. **Pagination** (criteria 447, 510) - the page size is 20 (`@per_page`). Seeding significantly more than 20 rows just for this is expensive; instead, read `load_data/2` and the `Next`/`Previous` button `:if` conditions in the template (`length(@subscriptions) == @per_page` for Next, `@page > 0` for Previous) to confirm the pagination logic is correct, and if practical seed slightly over 20 rows in one batch to see Next appear and click through one page. If seeding 20+ rows is too costly for this pass, downgrade to a code-read confirmation and note the live-render check as a gap, not a failure.
8. **Search by name or email** (criteria 447, 511) - type part of one seeded client Account's name (or its `stripe_customer_id`) into the search box, confirm the list filters (via `phx-debounce="300"` on `phx-change="search"`) to just matching rows, then clear and confirm the full list returns. Note: the search implementation (`maybe_search/2` in billing_repository.ex) matches `stripe_customer_id` or the client account's `name` field via ILIKE -- it does not search a literal "email" column (client Accounts don't have one), so the story's "search by name or email" wording is really "search by name or Stripe customer id"; do not file this as a bug, just note the actual matched fields in your scenario observation.
9. **Non-admin access** - log in as qa-member@example.com (read_only role) and confirm whether the Cancel button/action is restricted for a non-admin viewing the same account (the source has no `is_admin` gate visible in the Subscriptions LiveView unlike StripeConnect -- confirm this directly; if a read_only member CAN see the Cancel button and it would attempt a real cancel, file that as a genuine authorization gap since it isn't listed as an acceptance criterion for this story but is a plausible security concern worth flagging).

## Result Path

No result.md - findings go through `create_issue` as discovered, and the pass is closed with one `submit_qa_result` call against task_id `676d682d-ff20-4c00-8aff-6e279ccc16fa` (screenshots, if taken, go to `.code_my_spec/qa/51/screenshots/`).

## Setup Notes

Sequence steps in order within one session since step 4 mutates the seeded active subscription's ability to be re-tested (though since the cancel is expected to *fail* against Stripe, the local row should stay `:active` and remain reusable for later scenarios -- verify this rather than assuming it, per plan.md's "repros that consume themselves" guidance). If a Cancel click unexpectedly succeeds and flips the row to `:cancelled`, that itself is a notable finding (means Stripe accepted a fake subscription id, which would be surprising) -- investigate rather than just re-seeding over it.
