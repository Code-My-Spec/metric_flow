defmodule MetricFlowSpex.CheckoutIsBlockedWhenTheAgencyHasNoConnectedStripeAccountSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Checkout is blocked when the agency has no connected Stripe account", criterion: 487 do
    scenario "a customer visits checkout while the agency has no connected Stripe account" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_agency_plan

      when_ "the customer navigates to checkout", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/subscriptions/checkout")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "checkout does not proceed, since the agency has no connected Stripe account to bill through", context do
        html = render(context.view)
        refute html =~ "subscribe-button"
        {:ok, context}
      end
    end
  end
end
