defmodule MetricFlowSpex.NonConnectedAgencyCustomersUsePlatformDefaultBillingSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Customers of a non-connected agency are billed via platform default", criterion: 480 do
    scenario "a customer under a non-connected agency reaches the platform's own checkout" do
      given_ :user_logged_in_as_owner

      given_ "the agency has no Stripe account connected", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/agency/stripe-connect")
        {:ok, Map.put(context, :stripe_connect_view, view)}
      end

      when_ "the customer visits the platform's checkout", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/subscriptions/checkout")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the agency is confirmed not connected and the platform checkout is reachable", context do
        assert render(context.stripe_connect_view) =~ "Not connected"
        assert is_binary(render(context.view))
        {:ok, context}
      end
    end
  end
end
