defmodule MetricFlowSpex.DisconnectingStripeTakesEffectImmediatelySpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Disconnecting Stripe takes effect immediately" do
    scenario "admin disconnects and the page reflects not-connected without a reload" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_stripe_connect

      given_ "the admin is on the Stripe Connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/agency/stripe-connect")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the admin disconnects Stripe", context do
        html = context.view |> element("[data-role=disconnect-stripe]") |> render_click()
        {:ok, Map.put(context, :html, html)}
      end

      then_ "the page immediately shows not connected", context do
        assert context.html =~ "Not connected"
        refute context.html =~ "data-role=\"disconnect-stripe\""
        {:ok, context}
      end
    end
  end
end
