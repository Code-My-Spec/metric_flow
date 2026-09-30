defmodule MetricFlowSpex.BackfillReturnsLessThan548DaysWhenSiteHasLessHistorySpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Backfill returns less than 548 days of data when the site itself has less history available",
       criterion: 999 do
    scenario "a property with a shorter history than 548 days completes its first sync" do
      given_ :user_logged_in_as_owner

      given_ "a property with less than 548 days of available history", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_search_console,
          provider_metadata: %{"site_url" => "https://example.com/"}
        )

        {:ok, context}
      end

      given_ :with_google_search_console_sync_stub

      when_ "the first sync runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the first sync still completes successfully with whatever history the site actually has", context do
        assert has_element?(
                 context.view,
                 "[data-role='sync-history-entry'][data-status='success'] [data-role='sync-provider']",
                 "Google Search Console"
               )

        assert has_element?(context.view, "[data-sync-type='initial']")

        {:ok, context}
      end
    end
  end
end
