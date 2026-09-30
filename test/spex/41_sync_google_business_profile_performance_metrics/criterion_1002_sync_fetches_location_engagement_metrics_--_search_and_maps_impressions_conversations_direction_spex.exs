defmodule MetricFlowSpex.Criterion1002SyncFetchesLocationEngagementMetricsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Sync fetches location engagement metrics from the Google Business Profile Performance API for each configured location",
       criterion: 1002 do
    scenario "a client with a connected Google Business Profile location syncs its engagement metrics" do
      given_ :user_logged_in_as_owner

      given_ "a client has a connected Google Business Profile with a location configured", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_business,
          provider_metadata: %{"included_locations" => ["locations/123456789"]}
        )

        {:ok, context}
      end

      when_ "the sync runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "engagement metrics for that location are fetched from the Business Profile Performance API", context do
        assert has_element?(
                 context.view,
                 "[data-role='sync-history-entry'][data-status='success'] [data-role='sync-provider']",
                 "Google Business Profile"
               )

        {:ok, context}
      end
    end
  end
end
