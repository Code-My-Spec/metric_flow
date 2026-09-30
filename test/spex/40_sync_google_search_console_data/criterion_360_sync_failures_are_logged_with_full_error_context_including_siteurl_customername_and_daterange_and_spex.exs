defmodule MetricFlowSpex.SyncFailuresLoggedWithFullContextSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Sync failures are logged with full error context including siteUrl, customerName, and dateRange and surfaced in Sync Status and History",
       criterion: 360 do
    scenario "a Search Console sync fails because no site URL is configured" do
      given_ :user_logged_in_as_owner

      given_ "a Search Console integration exists with no site URL configured", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_search_console)
        {:ok, context}
      end

      when_ "the sync runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the failed sync's error detail is visible on its sync history entry", context do
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
