defmodule MetricFlowSpex.SyncFailureLogsFullContextAndAppearsInSyncStatusAndHistorySpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Sync failure logs full context and appears in Sync Status and History", criterion: 658 do
    scenario "a Search Console sync fails for a property" do
      given_ :user_logged_in_as_owner

      given_ "a Search Console sync fails for a property because no site URL is configured", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_search_console)
        {:ok, context}
      end

      when_ "the failure is recorded", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "it logs the siteUrl, customerName, and dateRange, and is surfaced in Sync Status and History",
            context do
        assert has_element?(
                 context.view,
                 "[data-role='sync-history-entry'][data-status='failed'] [data-role='sync-provider']",
                 "Google Search Console"
               )

        assert has_element?(context.view, "[data-role='sync-error']")

        {:ok, context}
      end
    end
  end
end
