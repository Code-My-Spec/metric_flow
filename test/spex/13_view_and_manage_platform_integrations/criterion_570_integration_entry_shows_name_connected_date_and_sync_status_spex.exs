defmodule MetricFlowSpex.IntegrationEntryShowsNameConnectedDateAndSyncStatusSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Integration entry shows name, connected date, and sync status", criterion: 570 do
    scenario "the user views the integrations list for a connected integration" do
      given_ :owner_with_integrations

      given_ "the user views the integrations list", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the entry shows the platform name, the connected date, and the sync status", context do
        assert has_element?(
                 context.view,
                 "[data-role='integration-row'] [data-role='integration-platform-name']"
               )

        assert has_element?(
                 context.view,
                 "[data-role='integration-row'] [data-role='integration-connected-date']"
               )

        assert has_element?(
                 context.view,
                 "[data-role='integration-row'] [data-role='integration-sync-status']"
               )

        {:ok, context}
      end
    end
  end
end
