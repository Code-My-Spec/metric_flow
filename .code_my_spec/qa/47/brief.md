# Qa Story Brief - Story 47: Agency Stripe Connect

## Tool

web

## Auth

App URL for this pass: http://127.0.0.1:59302

Use the seeded users from .code_my_spec/qa/plan.md (base seeds already applied - verify by logging in rather than re-running):

- Owner/admin: qa@example.com / hello world! - member of 'QA Test Account' as owner. is_admin on this page is role in [:owner, :admin], so this user can connect/disconnect.
- Non-admin: qa-member@example.com / hello world! - member of 'QA Test Account' as read_only. Use for the non-admin path (criterion 470).

Login sequence (password form is below the fold, scroll into view first):

    browser_navigate(url: 'http://127.0.0.1:59302/users/log-in')
    browser_scroll_into_view(selector: '#login_form_password')
    browser_fill(selector: '#login_form_password_email', text: 'qa@example.com')
    browser_fill(selector: '#user_password', text: 'hello world!')
    browser_click(selector: "#login_form_password button[name='user[remember_me]']")
    browser_wait_for_url(pattern: '/')

Switch users mid-session with browser_delete_cookies() then repeat with the other email.

The route does not gate on account type - StripeConnect.mount/3 only reads active_account_id + role, and the router applies no agency-type check either - so the seeded 'QA Test Account' (type team) is a valid target for this feature despite the story calling it an agency.

## Seeds

Base seeds: `mix run priv/repo/qa_seeds.exs` (idempotent - only needed if login as qa@example.com fails).

This story needs additional, story-specific seed rows that don't exist in the base seed set: a `MetricFlow.Billing.StripeAccount` row for the connected/restricted states, and a `MetricFlow.Billing.Plan` + `MetricFlow.Billing.Subscription` pair for the disconnect-flags-subscriptions scenario (criterion 479). Run these with the server already up, using the `--no-start` pattern from plan.md. Look up the account id first:

    mix run --no-start -e "Application.ensure_all_started(:postgrex); Application.ensure_all_started(:ecto); MetricFlow.Repo.start_link([]); account = MetricFlow.Repo.get_by!(MetricFlow.Accounts.Account, name: \"QA Test Account\"); IO.puts(account.id)"

Do NOT seed the StripeAccount row until after you've captured the not-connected baseline screenshots/observations (step 1 below) - creating it changes what the page shows. Then, to move to the restricted state:

    mix run --no-start -e "Application.ensure_all_started(:postgrex); Application.ensure_all_started(:ecto); MetricFlow.Repo.start_link([]); alias MetricFlow.Billing.{StripeAccount}; alias MetricFlow.Repo; account_id = <ACCOUNT_ID>; %StripeAccount{} |> StripeAccount.changeset(%{stripe_account_id: \"acct_qa47_1\", agency_account_id: account_id, onboarding_status: :restricted, capabilities: %{}}) |> Repo.insert!()"

Then to move the same row to complete/connected (update in place rather than inserting a second row - `agency_account_id` is unique):

    mix run --no-start -e "Application.ensure_all_started(:postgrex); Application.ensure_all_started(:ecto); MetricFlow.Repo.start_link([]); alias MetricFlow.Billing.StripeAccount; alias MetricFlow.Repo; sa = Repo.get_by!(StripeAccount, stripe_account_id: \"acct_qa47_1\"); sa |> StripeAccount.changeset(%{onboarding_status: :complete, capabilities: %{\"card_payments\" => \"active\", \"transfers\" => \"active\"}}) |> Repo.update!()"

For criterion 479 (disconnect flags existing subscriptions), before testing disconnect, seed a plan + a customer subscription against the connected agency account (mirrors test/support/shared_givens.ex :owner_has_agency_plan and test/support/fixtures/metric_flow_spex_fixtures.ex agency_customer_subscription!/2 - use `BillingRepository.create_plan/1`, not `Billing.create_plan/1`, since the repository version stores the row directly with a supplied stripe_price_id and makes no real Stripe call):

    mix run --no-start -e "Application.ensure_all_started(:postgrex); Application.ensure_all_started(:ecto); MetricFlow.Repo.start_link([]); alias MetricFlow.Billing.{BillingRepository, Subscription}; alias MetricFlow.Accounts.Account; alias MetricFlow.Repo; account_id = <ACCOUNT_ID>; {:ok, plan} = BillingRepository.create_plan(%{name: \"QA47 Plan\", price_cents: 4999, currency: \"usd\", billing_interval: :monthly, agency_account_id: account_id, stripe_price_id: \"price_qa47_1\"}); customer = %Account{} |> Account.creation_changeset(%{name: \"QA47 Customer\", slug: \"qa47-customer\", type: \"client\", originator_user_id: (MetricFlow.Accounts.get_user_by_email(\"qa@example.com\") |> then(fn nil -> nil; u -> u.id end))}) |> Repo.insert!(); sub = Repo.insert!(%Subscription{stripe_subscription_id: \"sub_qa47_1\", stripe_customer_id: \"cus_qa47_1\", status: :active, account_id: customer.id, plan_id: plan.id, current_period_start: DateTime.utc_now() |> DateTime.truncate(:second), current_period_end: DateTime.utc_now() |> DateTime.add(30, :day) |> DateTime.truncate(:second)}); IO.puts(sub.id)"

These are fresh, unused ids (acct_qa47_1, price_qa47_1, sub_qa47_1, cus_qa47_1, slug qa47-customer) - not reused from any earlier attempt. If a prior attempt already used them, pick a new numeric suffix and note it in the result.

After disconnecting in the browser (step 6), verify the flag took effect by re-querying the subscription row directly (no UI surfaces subscription status):

    mix run --no-start -e "Application.ensure_all_started(:postgrex); Application.ensure_all_started(:ecto); MetricFlow.Repo.start_link([]); IO.inspect(MetricFlow.Repo.get!(MetricFlow.Billing.Subscription, <SUB_ID>).status)"

## What To Test

1. **Baseline, not connected** (criteria 413, 417, 419/480) - before seeding any StripeAccount row, log in as qa@example.com, navigate to `/app/agency/stripe-connect`. Expect: 'Not connected' badge, 'Connect Stripe Account' button (`[data-role=connect-stripe]`) visible. Then navigate to `/app/subscriptions/checkout` and confirm it renders (platform-default billing path is reachable while the agency isn't connected).

2. **Non-admin cannot connect** (criterion 470) - log out, log in as qa-member@example.com, navigate to `/app/agency/stripe-connect`. Expect: no `[data-role=connect-stripe]` element present anywhere on the page (read_only is not owner/admin).

3. **Connect click - real Stripe error path** (criteria 414, 471, 472) - log back in as qa@example.com, click 'Connect Stripe Account'. Per `.code_my_spec/qa/plan.md`'s known-limitation section, `Billing.create_connect_account/1` makes a real call to `api.stripe.com` and the platform's Stripe test account has Connect disabled, so this is expected to fail with a flash starting 'Failed to start Stripe onboarding: ...'. Record the exact error text. This confirms the error-handling path (matches the shape of criterion 472's assertion, though the live cause is 'Connect disabled' rather than a stubbed card_decline). The happy-path redirect-to-Stripe behavior (criteria 414, 471) cannot be verified live for the reason given in plan.md - note this as a known gap rather than a failure, unless `mix test test/metric_flow_web/live/agency_live/stripe_connect_test.exs test/metric_flow/billing_test.exs` also fails to cover it (spot check those files exist and pass).

4. **Restricted state** (criteria 417, 474) - seed the StripeAccount row as `onboarding_status: :restricted` (see Seeds). Reload `/app/agency/stripe-connect`. Expect: 'Restricted' badge, the incomplete-onboarding warning message, the account id shown, and a 'Resume Onboarding' button (`[data-role=connect-stripe]`, same role attribute as the initial connect button).

5. **Connected state** (criteria 415, 417, 473) - update the same StripeAccount row to `onboarding_status: :complete` with capabilities. Reload the page. Expect: 'Connected' badge, account id shown, capability badges rendered, 'Disconnect Stripe Account' button (`[data-role=disconnect-stripe]`) visible, connect/resume button gone.

6. **Disconnect** (criteria 418, 477, 479) - first seed the plan + customer subscription (see Seeds). On the connected page, click 'Disconnect Stripe Account' (it has a `data-confirm` - accept the browser confirm dialog). Expect: status flips to 'Not connected' immediately in the same view, flash 'Stripe account disconnected'. Then run the subscription-status query from Seeds and confirm the subscription's `status` is no longer `:active` (the code path calls `BillingRepository.flag_agency_subscriptions_for_review/1` on disconnect).

7. **Disconnect request to Stripe fails** (criterion 478) - read `lib/metric_flow/billing.ex` `disconnect_stripe_account/1` and `lib/metric_flow/billing/stripe_client.ex`. Confirm there is no Stripe API call anywhere in the disconnect path (only a local `Repo.delete`) before concluding this criterion is untestable as literally worded; if confirmed, this is a product gap (real Stripe Connect disconnection normally revokes/deauthorizes the account via the API), not a QA gap - file it rather than skipping it.

8. **refresh_status dead code** - `StripeConnect.handle_event("refresh_status", ...)` exists in the source but grep the HEEx template for `phx-click="refresh_status"` (or any `phx-click={"refresh_status"}`) - if nothing in the render fires it, it's unreachable from the UI. Confirm and file if so.

9. **Schema location note, not a bug** - the story text says connection state lives on the `Agency` schema with `stripe_account_id`/`stripe_connect_status`/`stripe_onboarded_at` fields; the actual implementation uses a separate `billing_stripe_accounts` table (`MetricFlow.Billing.StripeAccount`) joined by `agency_account_id`. Criteria 420 and 481's BDD specs assert on rendered page behavior, not schema shape, and behavior matches - do not file this as a finding, it's a documentation/story-wording mismatch at most.

## Result Path

No result.md - findings go through `create_issue` as discovered, and the pass is closed with one `submit_qa_result` call against task_id `b6c5df4e-3644-4a04-b265-fa9a8c504b07` (screenshots, if taken, go to `.code_my_spec/qa/47/screenshots/`).

## Setup Notes

Sequence steps 1-6 in order within a single session - each seed mutates state the next step's baseline depends on (not-connected must be observed before any StripeAccount row exists; restricted before complete; plan+subscription before disconnect). If a step must be re-run, re-check whether the ids above are still fresh per the plan's 'repros that consume themselves' guidance.
