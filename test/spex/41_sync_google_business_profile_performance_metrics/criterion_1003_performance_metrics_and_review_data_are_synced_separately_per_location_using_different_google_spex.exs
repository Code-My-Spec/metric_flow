defmodule MetricFlowSpex.Criterion1003PerformanceAndReviewsSyncedSeparatelySpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Performance metrics and review data are synced separately per location, using different Google Business Profile APIs",
       criterion: 1003 do
    scenario "a location's performance metrics and reviews appear as separate sync history entries" do
      given_ :user_logged_in_as_owner
      given_ :with_google_business_sync_stub

      given_ "a client has a connected Google Business Profile location", context do
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

      then_ "performance metrics and reviews appear as separate, independent sync history entries", context do
        assert has_element?(
                 context.view,
                 "[data-role='sync-history-entry'] [data-role='sync-provider']",
                 "Google Business Profile"
               )

        assert has_element?(
                 context.view,
                 "[data-role='sync-history-entry'] [data-role='sync-provider']",
                 "Google Business Reviews"
               )

        {:ok, context}
      end
    end
  end
end
