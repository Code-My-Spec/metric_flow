defmodule MetricFlowSpex.CheckoutSessionIsCreatedAgainstTheAgencysConnectedStripeAccountSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Checkout session is created against the agency's connected Stripe account", criterion: 486 do
    scenario "a customer starts checkout while the agency is Stripe-connected" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_agency_plan
      given_ :owner_has_stripe_connect

      when_ "the customer navigates to checkout", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/subscriptions/checkout")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "checkout is offered against the agency's plan, ready to route through its connected Stripe account",
            context do
        html = render(context.view)
        assert html =~ context.agency_plan.name
        assert html =~ "subscribe-button"
        {:ok, context}
      end
    end
  end
end
