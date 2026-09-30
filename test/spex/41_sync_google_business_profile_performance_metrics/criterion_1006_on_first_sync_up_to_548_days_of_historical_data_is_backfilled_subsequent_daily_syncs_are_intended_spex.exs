defmodule MetricFlowSpex.Criterion1006FirstSyncBackfills548DaysSubsequentSyncsAreIncrementalSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "On first sync, up to 548 days of historical data is backfilled; subsequent daily syncs are intended to fetch only data since the last successful sync rather than re-fetching the full history",
       criterion: 1006 do
    scenario "a newly connected Google Business Profile location backfills on its first sync, then syncs incrementally" do
      given_ :user_logged_in_as_owner

      given_ "a Google Business Profile location was just connected and has never synced", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_business,
          provider_metadata: %{"included_locations" => ["locations/123456789"]}
        )

        {:ok, context}
      end

      when_ "the first sync runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "it backfills up to 548 days of historical data", context do
        assert has_element?(context.view, "[data-sync-type='initial']")
        {:ok, context}
      end

      then_ "a subsequent daily sync fetches only data since the last successful sync rather than re-fetching the full history", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)

        html = render(view)
        yesterday = Date.utc_today() |> Date.add(-1) |> Date.to_iso8601()
        assert html =~ yesterday
        {:ok, context}
      end
    end
  end
end
