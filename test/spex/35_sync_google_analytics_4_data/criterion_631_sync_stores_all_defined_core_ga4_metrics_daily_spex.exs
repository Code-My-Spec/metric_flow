defmodule MetricFlowSpex.SyncStoresAllDefinedCoreGa4MetricsDailySpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Sync stores all defined core GA4 metrics daily", criterion: 631 do
    scenario "a property with normal traffic has all core metrics synced as daily values" do
      given_ :user_logged_in_as_owner

      given_ "a GA4 property with normal traffic", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_analytics,
          provider_metadata: %{"property_id" => "properties/123456789"}
        )

        {:ok, context}
      end

      given_ :with_google_analytics_sync_stub

      when_ "the daily sync runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "all of the defined core metrics are synced as daily values", context do
        assert has_element?(context.view, "[data-role='sync-history-entry'][data-status='success'] [data-role='sync-provider']", "Google Analytics")
        {:ok, context}
      end
    end
  end
end
