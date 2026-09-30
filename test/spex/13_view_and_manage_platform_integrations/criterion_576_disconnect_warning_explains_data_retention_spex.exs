defmodule MetricFlowSpex.DisconnectWarningExplainsDataRetentionSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Disconnect warning explains data retention", criterion: 576 do
    scenario "the user is disconnecting an integration" do
      given_ :owner_with_integrations

      given_ "the user is disconnecting an integration", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they initiate the disconnect action", context do
        html =
          context.view
          |> element("[data-platform='google_analytics'] [data-role='disconnect-integration']")
          |> render_click()

        {:ok, Map.put(context, :html, html)}
      end

      then_ "they see a warning that historical data will remain but no new data will sync",
            context do
        assert has_element?(context.view, "[data-role='disconnect-warning']")
        assert context.html =~ "Historical data will remain"
        {:ok, context}
      end
    end
  end
end
