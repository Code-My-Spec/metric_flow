defmodule MetricFlowSpex.Ga4MetricIsMappedToItsCanonicalNameSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "GA4 metric is mapped to its canonical name", criterion: 640 do
    scenario "a GA4 metric like sessions syncs successfully under the shared taxonomy" do
      given_ :user_logged_in_as_owner

      given_ "GA4 reports a metric like sessions", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_analytics,
          provider_metadata: %{"property_id" => "properties/123456789"}
        )

        {:ok, context}
      end

      given_ :with_google_analytics_sync_stub

      when_ "it is stored", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "it is mapped to the canonical cross-platform metric name", context do
        assert has_element?(context.view, "[data-role='sync-history-entry'][data-status='success'] [data-role='sync-provider']", "Google Analytics")
        {:ok, context}
      end
    end
  end
end
