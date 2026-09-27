defmodule MetricFlowSpex.DashboardReflectsConnectionStatusSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Dashboard reflects connection status" do
    scenario "not-connected agency sees the not-connected badge" do
      given_ :user_logged_in_as_owner

      when_ "the admin views the Stripe Connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/agency/stripe-connect")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the not-connected status is displayed", context do
        html = render(context.view)
        assert html =~ "Not connected"
        {:ok, context}
      end
    end

    scenario "connected agency sees the connected badge" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_stripe_connect

      when_ "the admin views the Stripe Connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/agency/stripe-connect")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the connected status is displayed", context do
        html = render(context.view)
        assert html =~ "Connected"
        {:ok, context}
      end
    end
  end
end
