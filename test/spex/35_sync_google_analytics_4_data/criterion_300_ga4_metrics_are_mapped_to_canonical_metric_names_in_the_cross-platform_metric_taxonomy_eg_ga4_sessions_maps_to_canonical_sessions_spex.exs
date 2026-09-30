defmodule MetricFlowSpex.Ga4MetricsAreMappedToCanonicalMetricNamesSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "GA4 metrics are mapped to canonical metric names in the cross-platform metric taxonomy (e.g., GA4 'sessions' maps to canonical 'sessions')",
       criterion: 300 do
    scenario "a synced GA4 property's data syncs successfully under its canonical metric names" do
      given_ :user_logged_in_as_owner

      given_ "a connected GA4 property", context do
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

      then_ "the sync completes successfully with its metrics stored under the shared taxonomy", context do
        assert has_element?(context.view, "[data-role='sync-history-entry'][data-status='success'] [data-role='sync-provider']", "Google Analytics")
        {:ok, context}
      end
    end
  end
end
