defmodule MetricFlowSpex.Ga4OnlyMetricsAreStoredWithAPlatformSpecificLabelSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "GA4-specific metrics that have no canonical equivalent are stored as platform-specific metrics labeled 'Google Analytics: [metric name]'",
       criterion: 301 do
    scenario "a GA4-only metric with no canonical equivalent still syncs without failing" do
      given_ :user_logged_in_as_owner

      given_ "a connected GA4 property reports a metric with no canonical cross-platform equivalent", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_analytics,
          provider_metadata: %{"property_id" => "properties/123456789"}
        )

        {:ok, context}
      end

      when_ "the sync runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the sync completes successfully and does not drop the platform-specific metric", context do
        assert has_element?(context.view, "[data-role='sync-history-entry'][data-status='success'] [data-role='sync-provider']", "Google Analytics")
        {:ok, context}
      end
    end
  end
end
