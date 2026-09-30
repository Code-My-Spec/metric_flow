defmodule MetricFlowSpex.MissingCoreMetricForAPropertyDoesNotFailTheWholeSyncSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Missing core metric for a property does not fail the whole sync", criterion: 632 do
    scenario "a property missing one core metric still completes with the metrics it does have" do
      given_ :user_logged_in_as_owner

      given_ "a GA4 property does not have one of the core metrics configured (e.g. keyEvents)", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_analytics,
          provider_metadata: %{"property_id" => "properties/123456789"}
        )

        {:ok, context}
      end

      given_ :with_google_analytics_sync_stub

      when_ "the sync runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the available metrics are still stored and the sync does not fail because one metric is absent", context do
        assert has_element?(context.view, "[data-role='sync-history-entry'][data-status='success'] [data-role='sync-provider']", "Google Analytics")
        {:ok, context}
      end
    end
  end
end
