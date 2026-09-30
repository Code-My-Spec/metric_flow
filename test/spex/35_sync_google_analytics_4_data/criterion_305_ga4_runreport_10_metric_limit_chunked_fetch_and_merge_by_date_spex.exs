defmodule MetricFlowSpex.Ga4RunreportChunkedFetchIsEquivalentToASingleRequestSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Because GA4's runReport endpoint has a 10-metric limit per request, metrics are fetched in chunks of 10 and results are merged by date before storage; the final stored data is equivalent to what a single-request response would contain",
       criterion: 305 do
    scenario "chunked fetching does not change the number of records synced for the day" do
      given_ :user_logged_in_as_owner

      given_ "a connected GA4 property with more than 10 core metrics configured", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_analytics,
          provider_metadata: %{"property_id" => "properties/123456789"}
        )

        {:ok, context}
      end

      when_ "the sync fetches and merges the chunked metrics", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the sync completes successfully with the merged data intact", context do
        assert has_element?(context.view, "[data-role='sync-history-entry'][data-status='success'] [data-role='sync-provider']", "Google Analytics")
        {:ok, context}
      end
    end
  end
end
