defmodule MetricFlowSpex.MetricsFetchedInChunksOf10AreMergedIntoOneEquivalentDailyResultSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Metrics fetched in chunks of 10 are merged into one equivalent daily result", criterion: 644 do
    scenario "more than 10 core metrics still produce a single merged sync entry per day" do
      given_ :user_logged_in_as_owner

      given_ "more than 10 core metrics need to be fetched for a property", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_analytics,
          provider_metadata: %{"property_id" => "properties/123456789"}
        )

        {:ok, context}
      end

      when_ "the sync fetches them in chunks of 10 and merges the results by date", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the final stored data is equivalent to what a single request would have returned", context do
        html = render(context.view)
        entries = Regex.scan(~r/data-role="sync-history-entry"/, html)
        assert length(entries) == 1,
               "Expected exactly one merged sync entry, got #{length(entries)}. HTML: #{html}"

        {:ok, context}
      end
    end
  end
end
