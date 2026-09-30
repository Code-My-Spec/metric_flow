defmodule MetricFlowSpex.Criterion1004MetricsStoredDailyPerLocationPerMetricSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Metrics are stored daily, per location, per metric, so performance can be seen location by location as well as in aggregate",
       criterion: 1004 do
    scenario "a client with multiple Google Business Profile locations syncs each location's metrics" do
      given_ :user_logged_in_as_owner

      given_ "a client has a connected Google Business Profile with two locations configured", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_business,
          provider_metadata: %{"included_locations" => ["locations/111", "locations/222"]}
        )

        {:ok, context}
      end

      when_ "the sync runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "metrics are stored per location, per metric, per day", context do
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
