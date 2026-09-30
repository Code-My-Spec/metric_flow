defmodule MetricFlowSpex.DataIsFetchedPerGa4PropertySelectedDuringOauthConnectionSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Data is fetched per GA4 property selected during OAuth connection", criterion: 292 do
    scenario "a sync fetches data for the property chosen at connection time" do
      given_ :user_logged_in_as_owner

      given_ "a GA4 integration exists for the property chosen during OAuth connection", context do
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

      then_ "the sync completes successfully for that property's Google Analytics integration", context do
        assert has_element?(
                 context.view,
                 "[data-role='sync-history-entry'][data-status='success'] [data-role='sync-provider']",
                 "Google Analytics"
               )

        {:ok, context}
      end
    end
  end
end
