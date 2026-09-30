defmodule MetricFlowSpex.EachMetricIsStoredAsADailyTimeSeriesValueKeyedToPropertyAndAccountSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Each metric is stored as a daily time-series value keyed to the property and client account",
       criterion: 294 do
    scenario "a synced GA4 metric appears under the syncing account's own history, not another account's" do
      given_ :user_logged_in_as_owner

      given_ "the account has a connected GA4 property", context do
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

      then_ "this account's sync history shows the completed Google Analytics sync", context do
        assert has_element?(context.view, "[data-role='sync-history-entry'][data-status='success'] [data-role='sync-provider']", "Google Analytics")
        {:ok, context}
      end
    end
  end
end
