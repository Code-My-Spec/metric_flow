defmodule MetricFlowSpex.StripeConnectionFieldsThroughLifecycleSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Agency schema carries Stripe connection fields through the lifecycle", criterion: 481 do
    scenario "connection state moves from not connected, to connected, to not connected again" do
      given_ :user_logged_in_as_owner

      given_ "the admin is on the Stripe Connect page while unconnected", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/agency/stripe-connect")
        assert render(view) =~ "Not connected"
        {:ok, Map.put(context, :view, view)}
      end

      given_ :owner_has_stripe_connect

      when_ "the admin reloads the page and then disconnects", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/agency/stripe-connect")
        connected_html = render(view)
        after_disconnect_html = view |> element("[data-role=disconnect-stripe]") |> render_click()
        {:ok, Map.merge(context, %{connected_html: connected_html, after_disconnect_html: after_disconnect_html})}
      end

      then_ "the stored state reflected connected, then reverted to not connected", context do
        assert context.connected_html =~ "Connected"
        assert context.after_disconnect_html =~ "Not connected"
        {:ok, context}
      end
    end
  end
end
