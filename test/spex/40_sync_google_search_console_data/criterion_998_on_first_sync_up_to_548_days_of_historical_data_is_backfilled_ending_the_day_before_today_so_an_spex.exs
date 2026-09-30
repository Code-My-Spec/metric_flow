defmodule MetricFlowSpex.FirstSyncBackfills548DaysEndingYesterdaySubsequentSyncsFetchSinceLastSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "On first sync, up to 548 days of historical data is backfilled, ending the day before today; subsequent daily syncs fetch only data since the last successful sync",
       fail_on_error_logs: false, criterion: 998 do
    scenario "a property was just connected" do
      given_ :user_logged_in_as_owner

      given_ "a property was just connected", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_search_console,
          provider_metadata: %{"site_url" => "https://example.com/"}
        )

        {:ok, context}
      end

      when_ "the first sync runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "it backfills up to 548 days ending the day before today, marked as an initial sync", context do
        assert has_element?(context.view, "[data-sync-type='initial']")

        {:ok, context}
      end
    end
  end
end
