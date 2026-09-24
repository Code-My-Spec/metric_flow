defmodule MetricFlowTest.BillingFixtures do
  @moduledoc """
  Subscriptions, for tests that have to get past the paywall.

  `MetricFlowWeb.Hooks.RequireSubscriptionHook` halts a mount and redirects to
  checkout unless the active account has a live subscription or is an agency,
  so any test of a paywalled screen — correlations, chat, insights, reports —
  needs one of these in setup. Kept separate from the account fixtures rather
  than folded into them: a test that wants to *see* the paywall needs an
  account without a subscription, and a fixture that always attached one would
  make that test impossible to write.
  """

  alias MetricFlow.Billing.BillingRepository

  @doc """
  An active subscription on `account_id`, covering the current period.

  One per account — `billing_subscriptions` has a unique constraint on
  `account_id` — so calling this twice for one account replaces the first.
  """
  def active_subscription_fixture(account_id, attrs \\ %{}) do
    now = DateTime.utc_now()

    {:ok, subscription} =
      BillingRepository.upsert_subscription(
        Map.merge(
          %{
            stripe_subscription_id: "sub_test_#{System.unique_integer([:positive])}",
            stripe_customer_id: "cus_test_#{System.unique_integer([:positive])}",
            status: :active,
            account_id: account_id,
            current_period_start: now,
            current_period_end: DateTime.add(now, 30, :day)
          },
          attrs
        )
      )

    subscription
  end
end
