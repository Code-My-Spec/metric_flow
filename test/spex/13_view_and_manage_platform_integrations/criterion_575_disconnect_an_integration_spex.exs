defmodule MetricFlowSpex.DisconnectAnIntegrationSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Disconnect an integration", criterion: 575 do
    scenario "a connected integration is disconnected" do
      given_ :owner_with_integrations

      given_ "the user is on the integrations page with a connected integration", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user disconnects it", context do
        context.view
        |> element("[data-platform='google_analytics'] [data-role='disconnect-integration']")
        |> render_click()

        html =
          context.view
          |> element("[data-role='confirm-disconnect']")
          |> render_click()

        {:ok, Map.put(context, :html, html)}
      end

      then_ "the integration is marked disconnected and stops syncing new data", context do
        assert has_element?(
                 context.view,
                 "[data-platform='google_analytics'][data-status='available']"
               )

        refute has_element?(
                 context.view,
                 "[data-platform='google_analytics'][data-status='connected']"
               )

        {:ok, context}
      end
    end
  end
end
