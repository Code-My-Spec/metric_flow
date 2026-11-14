defmodule MetricFlowSpex.Story51.Criterion1048Spex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Jordan can distinguish daily Google Business Profile metrics for two locations",
    criterion: 1048 do
    scenario "two configured locations have daily call-click data" do
      given_(:user_logged_in_as_owner)

      given_ "Jordan connected two locations to Google Business Profile", context do
        # shortcut: OAuth is outside this metric-display criterion; replace with an OAuth-backed shared given when available.
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_business,
          provider_metadata: %{
            "included_locations" => [
              "accounts/123/locations/456",
              "accounts/123/locations/789"
            ]
          }
        )

        {:ok, context}
      end

      given_ "Google reports call clicks for both locations on the same day", context do
        MetricFlowTest.SyncStub.stub_google_business_success()
        {:ok, context}
      end

      when_ "Jordan syncs and opens the Google Business Profile dashboard", context do
        {:ok, history, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        history |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)

        {:ok, dashboard, _html} =
          live(context.owner_conn, "/app/integrations/google_business/dashboard")

        {:ok, Map.put(context, :dashboard, dashboard)}
      end

      then_ "Jordan sees a separate daily call-click value for each location", context do
        for location_id <- ["accounts/123/locations/456", "accounts/123/locations/789"] do
          assert has_element?(
                   context.dashboard,
                   "[data-role='daily-location-metric'][data-location-id='#{location_id}'][data-metric='call_clicks']"
                 )
        end

        {:ok, context}
      end
    end
  end
end
