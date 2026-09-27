defmodule MetricFlowSpex.DisconnectRequestFailsSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Disconnect request to Stripe fails" do
    scenario "disconnecting an account that is already gone reports a failure" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_stripe_connect

      given_ "two Stripe Connect pages are open for the same agency", context do
        {:ok, view_a, _html} = live(context.owner_conn, "/app/agency/stripe-connect")
        {:ok, view_b, _html} = live(context.owner_conn, "/app/agency/stripe-connect")
        {:ok, Map.merge(context, %{view_a: view_a, view_b: view_b})}
      end

      when_ "one page disconnects first, then the other tries the same disconnect", context do
        context.view_a |> element("[data-role=disconnect-stripe]") |> render_click()
        html = context.view_b |> element("[data-role=disconnect-stripe]") |> render_click()
        {:ok, Map.put(context, :html, html)}
      end

      then_ "the second disconnect reports failure rather than succeeding silently", context do
        assert context.html =~ "Failed to disconnect"
        {:ok, context}
      end
    end
  end
end
