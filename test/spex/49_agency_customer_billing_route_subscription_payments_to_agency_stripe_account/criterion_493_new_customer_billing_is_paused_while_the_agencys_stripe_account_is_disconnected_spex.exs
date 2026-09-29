defmodule MetricFlowSpex.NewCustomerBillingIsPausedWhileTheAgencysStripeAccountIsDisconnectedSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "New customer billing is paused while the agency's Stripe account is disconnected", criterion: 493 do
    scenario "a new customer tries to subscribe while the agency's Stripe account is disconnected" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_agency_plan

      when_ "a new customer visits checkout while the agency has no connected Stripe account", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/subscriptions/checkout")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "checkout is paused rather than allowing a new subscription to start", context do
        html = render(context.view)
        refute html =~ "subscribe-button"
        {:ok, context}
      end
    end
  end
end
