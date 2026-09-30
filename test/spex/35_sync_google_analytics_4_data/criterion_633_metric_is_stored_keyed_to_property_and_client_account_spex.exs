defmodule MetricFlowSpex.MetricIsStoredKeyedToPropertyAndClientAccountSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Metric is stored keyed to property and client account", criterion: 633 do
    scenario "a synced metric value shows up under the syncing account's own sync history" do
      given_ :user_logged_in_as_owner

      given_ "the account has a connected GA4 property", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_analytics,
          provider_metadata: %{"property_id" => "properties/123456789"}
        )

        {:ok, context}
      end

      when_ "a synced metric value for a day is stored", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "it is keyed to the GA4 property and the client account, appearing in this account's own history", context do
        assert has_element?(context.view, "[data-role='sync-history-entry'][data-status='success'] [data-role='sync-provider']", "Google Analytics")
        {:ok, context}
      end
    end
  end
end
