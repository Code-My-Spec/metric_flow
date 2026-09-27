defmodule MetricFlowSpex.UserViewsPlanAndBillingStatusSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  alias MetricFlow.Billing.BillingRepository
  spex "User views plan and billing status" do
    scenario "a subscribed direct user visits account settings and sees plan and billing status" do
      given_(:user_logged_in_as_owner)

      given_ "the user has an active subscription", context do
        account_id = MetricFlowSpex.Fixtures.personal_account_id(context.owner_email)

        {:ok, _subscription} =
          BillingRepository.upsert_subscription(%{
            stripe_subscription_id: "sub_view_#{System.unique_integer([:positive])}",
            stripe_customer_id: "cus_view_#{System.unique_integer([:positive])}",
            status: :active,
            account_id: account_id,
            current_period_start: DateTime.utc_now(),
            current_period_end: DateTime.add(DateTime.utc_now(), 30, :day)
          })

        {:ok, context}
      end

      when_ "they visit account settings", context do
        {:ok, view, html} = live(context.owner_conn, "/app/subscriptions/checkout")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "they see their current plan and billing status", context do
        assert context.html =~ "Current Subscription"
        assert context.html =~ "Active"
        {:ok, context}
      end
    end
  end
end
