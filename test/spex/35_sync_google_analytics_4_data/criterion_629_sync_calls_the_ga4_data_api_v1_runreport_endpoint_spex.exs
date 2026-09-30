defmodule MetricFlowSpex.SyncCallsTheGa4DataApiV1RunreportEndpointSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Sync calls the GA4 Data API v1 runReport endpoint", criterion: 629 do
    scenario "a synced GA4 property completes via the current Data API, not the deprecated Universal Analytics API" do
      given_ :user_logged_in_as_owner

      given_ "a client has a connected GA4 property", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_analytics,
          provider_metadata: %{"property_id" => "properties/123456789"}
        )

        {:ok, context}
      end

      given_ :with_google_analytics_sync_stub

      when_ "the sync runs for that property", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "it completes via the Google Analytics Data API v1 runReport endpoint", context do
        assert has_element?(context.view, "[data-role='sync-history-entry'][data-status='success'] [data-role='sync-provider']", "Google Analytics")
        {:ok, context}
      end
    end
  end
end
