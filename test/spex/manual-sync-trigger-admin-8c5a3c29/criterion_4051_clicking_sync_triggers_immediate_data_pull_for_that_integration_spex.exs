defmodule MetricFlowSpex.ClickingSyncTriggersImmediateDataPullForThatIntegrationSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Clicking sync triggers immediate data pull for that integration" do
    scenario "clicking Sync Now on a connected integration shows a flash confirming sync was started" do
      given_ :owner_with_integrations

      given_ "the user navigates to the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user clicks the Sync Now button on the connected integration", context do
        context.view
        |> element("[data-platform='google_analytics'] button[phx-click='sync']", "Sync Now")
        |> render_click()

        {:ok, context}
      end

      then_ "the user sees a flash message confirming sync was started", context do
        html = render(context.view)
        assert html =~ "Sync started for Google Analytics"
        :ok
      end
    end

    scenario "after clicking Sync Now the button becomes disabled to prevent duplicate syncs" do
      given_ :owner_with_integrations

      given_ "the user navigates to the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user clicks the Sync Now button on the connected integration", context do
        context.view
        |> element("[data-platform='google_analytics'] button[phx-click='sync']", "Sync Now")
        |> render_click()

        {:ok, context}
      end

      then_ "the Sync Now button is disabled so the user cannot trigger a duplicate sync", context do
        assert has_element?(context.view, "[data-platform='google_analytics'] button[phx-click='sync'][disabled]", "Sync Now")
        :ok
      end
    end
  end
end
