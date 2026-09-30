defmodule MetricFlowSpex.SyncInProgressShowsALoadingIndicatorSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Sync in progress shows a loading indicator", criterion: 583 do
    scenario "while a manual sync is running the UI shows a loading indicator" do
      given_ :owner_with_integrations

      given_ "a manual sync has been triggered for an integration", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")

        view
        |> element("[data-platform='google_analytics'] button[phx-click='sync']", "Sync Now")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the UI shows a loading indicator for that integration", context do
        assert has_element?(context.view, "[data-role='integration-sync-status'] .loading-spinner")

        html = render(context.view)
        assert html =~ "Syncing"

        {:ok, context}
      end
    end
  end
end
