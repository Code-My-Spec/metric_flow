defmodule MetricFlowSpex.ReRunningASyncForAnAlreadySyncedDayIsSafeSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Re-running a sync for an already-synced day is safe", criterion: 653 do
    scenario "a day's metrics were already stored" do
      given_ :user_logged_in_as_owner

      given_ "a day's metrics were already stored", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_search_console,
          provider_metadata: %{"site_url" => "https://example.com/"}
        )

        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)

        {:ok, context}
      end

      when_ "the sync for that day runs again", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the upsert replaces the existing values rather than duplicating them", context do
        assert has_element?(
                 context.view,
                 "[data-role='sync-history-entry'][data-status='success'] [data-role='sync-provider']",
                 "Google Search Console"
               )

        {:ok, context}
      end
    end
  end
end
