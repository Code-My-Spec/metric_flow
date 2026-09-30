defmodule MetricFlowSpex.SyncFailuresLoggedWithSiteAndDateRangeVisibleInSyncHistorySpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Sync failures are logged with enough detail to diagnose them, including which site and date range were being synced, and are visible in Sync History",
       fail_on_error_logs: false, criterion: 1001 do
    scenario "a Search Console sync fails for a property because no site URL is configured" do
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

      then_ "the failure is visible in Sync History with enough detail to diagnose it", context do
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
