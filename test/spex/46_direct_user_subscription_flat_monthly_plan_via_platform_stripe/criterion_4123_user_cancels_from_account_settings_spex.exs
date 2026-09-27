defmodule MetricFlowSpex.UserCancelsFromAccountSettingsSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  alias MetricFlow.Billing.BillingRepository
  spex "User cancels from account settings" do
    scenario "a subscribed direct user cancels from account settings" do
      given_(:user_logged_in_as_owner)

      given_ "the user has an active subscription and is viewing account settings", context do
        account_id = MetricFlowSpex.Fixtures.personal_account_id(context.owner_email)

        {:ok, _subscription} =
          BillingRepository.upsert_subscription(%{
            stripe_subscription_id: "sub_cancel_flow_#{System.unique_integer([:positive])}",
            stripe_customer_id: "cus_cancel_flow_#{System.unique_integer([:positive])}",
            status: :active,
            account_id: account_id,
            current_period_start: DateTime.utc_now(),
            current_period_end: DateTime.add(DateTime.utc_now(), 30, :day)
          })

        {:ok, view, _html} = live(context.owner_conn, "/app/subscriptions/checkout")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they choose to cancel from account settings", context do
        html =
          context.view
          |> element("button", "Cancel Subscription")
          |> render_click()

        {:ok, Map.put(context, :html, html)}
      end

      then_ "the subscription is scheduled to cancel at period end via the Stripe API", context do
        assert context.html =~ "cancel" or context.html =~ "Cancel"
        refute context.html =~ "Failed to cancel"
        {:ok, context}
      end
    end
  end
end
