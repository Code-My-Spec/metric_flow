defmodule MetricFlowSpex.UiShowsSyncInProgressWithLoadingIndicatorSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "UI shows sync in progress with loading indicator" do
    scenario "before clicking Sync Now no Syncing badge is visible" do
      given_ :owner_with_integrations

      given_ "the user navigates to the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "no Syncing badge or loading indicator is shown on the page", context do
        html = render(context.view)
        refute html =~ "Syncing"
        refute html =~ "loading-spinner"
        :ok
      end
    end

    scenario "after clicking Sync Now the UI shows a Syncing badge for that integration" do
      given_ :owner_with_integrations

      given_ "the user navigates to the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user clicks the Sync Now button on the connected integration", context do
        context.view
        |> element("[data-platform='google_analytics'] button[phx-click='sync']", "Sync Now")
        |> render_click()

        {:ok, context}
      end

      then_ "the integration card shows a Syncing badge with a warning style", context do
        html = render(context.view)
        assert html =~ "Syncing"
        assert html =~ "badge-warning"
        :ok
      end
    end

    scenario "the loading spinner element is present when sync is in progress" do
      given_ :owner_with_integrations

      given_ "the user navigates to the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user clicks the Sync Now button to start a sync", context do
        context.view
        |> element("[data-platform='google_analytics'] button[phx-click='sync']", "Sync Now")
        |> render_click()

        {:ok, context}
      end

      then_ "the page renders a loading spinner element inside the Syncing badge", context do
        assert has_element?(context.view, "[data-role='integration-sync-status'] .loading-spinner")
        :ok
      end
    end
  end
end
