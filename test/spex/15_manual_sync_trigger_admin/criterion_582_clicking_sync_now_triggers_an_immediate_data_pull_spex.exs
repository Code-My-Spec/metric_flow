defmodule MetricFlowSpex.ClickingSyncNowTriggersAnImmediateDataPullSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Clicking Sync Now triggers an immediate data pull", criterion: 582 do
    scenario "clicking Sync Now on a connected, healthy integration starts an immediate pull" do
      given_ :owner_with_integrations

      given_ "a connected, healthy integration", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the admin clicks Sync Now", context do
        context.view
        |> element("[data-platform='google_analytics'] button[phx-click='sync']", "Sync Now")
        |> render_click()

        {:ok, context}
      end

      then_ "an immediate data pull for that integration starts right away", context do
        html = render(context.view)

        assert html =~ "Sync started for Google Analytics",
               "Expected confirmation that sync started immediately, got: #{html}"

        assert has_element?(
                 context.view,
                 "[data-platform='google_analytics'] button[phx-click='sync'][disabled]"
               ),
               "Expected the integration to show as actively syncing right after clicking"

        {:ok, context}
      end
    end
  end
end
