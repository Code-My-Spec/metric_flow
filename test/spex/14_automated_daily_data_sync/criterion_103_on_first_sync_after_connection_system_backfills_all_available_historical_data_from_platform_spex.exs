defmodule MetricFlowSpex.FirstSyncBackfillsHistoricalDataSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "On first sync after connection, system backfills all available historical data from platform",
       criterion: 103 do
    scenario "a newly connected integration's first sync is marked as an initial backfill" do
      given_ :user_logged_in_as_owner

      given_ "the account has a newly connected integration with no prior sync history", context do
        integration = MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)
        {:ok, Map.put(context, :integration, integration)}
      end

      when_ "the first sync runs for that integration", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the sync history marks it as an initial backfill covering all available historical data", context do
        assert has_element?(context.view, "[data-sync-type='initial']")
        {:ok, context}
      end
    end
  end
end
