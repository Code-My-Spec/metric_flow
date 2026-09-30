defmodule MetricFlowSpex.FirstSyncAfterConnectingBackfillsAllAvailableHistoricalDataSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "First sync after connecting backfills all available historical data", criterion: 611 do
    scenario "a platform connected for the first time is backfilled on its first sync" do
      given_ :user_logged_in_as_owner

      given_ "a platform was just connected and has not synced before", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)
        {:ok, context}
      end

      when_ "the first sync runs for that integration", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the system backfills all historical data the platform makes available", context do
        assert has_element?(context.view, "[data-sync-type='initial']")
        {:ok, context}
      end
    end
  end
end
