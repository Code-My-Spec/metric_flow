defmodule MetricFlowSpex.SyncFetchesDataForTheOauthSelectedGa4PropertySpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Sync fetches data for the OAuth-selected GA4 property", criterion: 630 do
    scenario "data is fetched for the property chosen during OAuth connection" do
      given_ :user_logged_in_as_owner

      given_ "a client selected a specific GA4 property during OAuth connection", context do
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

      then_ "data is fetched for that selected property", context do
        assert has_element?(context.view, "[data-role='sync-history-entry'][data-status='success'] [data-role='sync-provider']", "Google Analytics")
        {:ok, context}
      end
    end
  end
end
