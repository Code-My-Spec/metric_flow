defmodule MetricFlowSpex.UsersCanCancelSubscriptionFromAccountSettingsSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  alias MetricFlow.Billing.BillingRepository

  spex "Users can cancel their subscription from account settings" do
    scenario "subscribed user sees cancel option in account settings" do
      given_(:user_logged_in_as_owner)

      given_ "the user has an active subscription and navigates to the checkout page", context do
        # Set up active subscription so cancel option is visible
        account_id = MetricFlowSpex.Fixtures.personal_account_id(context.owner_email)

        {:ok, _} =
          BillingRepository.upsert_subscription(%{
            stripe_subscription_id: "sub_cancel_test_#{System.unique_integer([:positive])}",
            stripe_customer_id: "cus_cancel_test_#{System.unique_integer([:positive])}",
            status: :active,
            account_id: account_id,
            current_period_start: DateTime.utc_now(),
            current_period_end: DateTime.add(DateTime.utc_now(), 30, :day)
          })

        {:ok, view, _html} = live(context.owner_conn, "/app/subscriptions/checkout")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows a cancel subscription option for subscribed users", context do
        html = render(context.view)
        assert html =~ "Cancel" or html =~ "cancel"
        {:ok, context}
      end
    end
  end
end
