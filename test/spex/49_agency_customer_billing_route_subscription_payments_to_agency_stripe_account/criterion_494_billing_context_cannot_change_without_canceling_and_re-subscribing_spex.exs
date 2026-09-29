defmodule MetricFlowSpex.BillingContextCannotChangeWithoutCancelingAndReSubscribingSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Billing context cannot change without canceling and re-subscribing", criterion: 494 do
    scenario "a subscribed customer's checkout page offers no way to switch billing context in place" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_agency_plan
      given_ :owner_has_active_subscription

      when_ "the customer views their checkout page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/subscriptions/checkout")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the only offered action is cancellation, not switching to a different billing context in place",
            context do
        html = render(context.view)
        assert html =~ "cancel_subscription"
        refute html =~ "change-billing-context"
        {:ok, context}
      end
    end
  end
end
