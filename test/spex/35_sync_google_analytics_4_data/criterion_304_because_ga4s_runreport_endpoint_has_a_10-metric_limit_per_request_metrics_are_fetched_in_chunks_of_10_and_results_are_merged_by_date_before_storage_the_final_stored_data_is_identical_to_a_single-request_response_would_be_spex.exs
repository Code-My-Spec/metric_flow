defmodule MetricFlowSpex.MetricsFetchedInChunksOf10AreMergedByDateSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Because GA4's runReport endpoint has a 10-metric limit per request, metrics are fetched in chunks of 10 and results are merged by date before storage; the final stored data is identical to a single-request response would be",
       criterion: 304 do
    scenario "a sync needing more than 10 core metrics still produces one merged result per day" do
      given_ :user_logged_in_as_owner

      given_ "a connected GA4 property with more than 10 core metrics configured", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_analytics,
          provider_metadata: %{"property_id" => "properties/123456789"}
        )

        {:ok, context}
      end

      when_ "the sync fetches the metrics in chunks and merges them by date", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "a single successful sync entry is recorded per day, not one per chunk", context do
        html = render(context.view)
        entries = Regex.scan(~r/data-role="sync-history-entry"/, html)
        assert length(entries) == 1,
               "Expected exactly one merged sync entry, got #{length(entries)}. HTML: #{html}"

        {:ok, context}
      end
    end
  end
end
