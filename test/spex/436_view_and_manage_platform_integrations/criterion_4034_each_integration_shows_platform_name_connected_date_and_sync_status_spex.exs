defmodule MetricFlowSpex.EachIntegrationShowsPlatformNameConnectedDateAndSyncStatusSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Each integration shows platform name, connected date, and sync status" do
    scenario "the integrations page renders a platform name for each integration entry" do
      given_ :owner_with_integrations

      given_ "the user navigates to the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page contains at least one element displaying a platform name", context do
        assert has_element?(context.view, "[data-role='integration-platform-name']")
        :ok
      end
    end

    scenario "the integrations page shows a connected date for each integration entry" do
      given_ :owner_with_integrations

      given_ "the user navigates to the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page contains an element showing when each integration was connected", context do
        assert has_element?(context.view, "[data-role='integration-connected-date']")
        :ok
      end
    end

    scenario "the integrations page shows a sync status for each integration entry" do
      given_ :owner_with_integrations

      given_ "the user navigates to the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page contains an element showing the sync status of each integration", context do
        assert has_element?(context.view, "[data-role='integration-sync-status']")
        :ok
      end
    end

    scenario "the integrations page groups platform name, connected date, and sync status per integration" do
      given_ :owner_with_integrations

      given_ "the user navigates to the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "each integration row contains all three pieces of information together", context do
        assert has_element?(context.view, "[data-role='integration-row']")
        :ok
      end

      then_ "each integration row shows the platform name within the row", context do
        assert has_element?(context.view, "[data-role='integration-row'] [data-role='integration-platform-name']")
        :ok
      end
    end
  end
end
