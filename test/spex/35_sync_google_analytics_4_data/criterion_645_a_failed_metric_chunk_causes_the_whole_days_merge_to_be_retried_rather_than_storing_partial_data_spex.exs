defmodule MetricFlowSpex.AFailedMetricChunkCausesTheWholeDaysMergeToBeRetriedSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "A failed metric chunk causes the whole day's merge to be retried rather than storing partial data",
       criterion: 645 do
    scenario "a partially failed chunked fetch does not leave a partial-day record" do
      given_ :user_logged_in_as_owner

      given_ "one chunk of a multi-chunk metric fetch fails while the other chunk succeeds", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_analytics,
          provider_metadata: %{"property_id" => "properties/123456789"}
        )

        {:ok, context}
      end

      when_ "the sync processes that day", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync, with_recursion: true)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "no partial-day record is stored, and the whole day's fetch is retried as a unit", context do
        html = render(context.view)
        entries = Regex.scan(~r/data-role="sync-history-entry"/, html)
        assert length(entries) == 1,
               "Expected exactly one sync entry for the day (no partial-day duplicate), got #{length(entries)}. HTML: #{html}"

        {:ok, context}
      end
    end
  end
end
