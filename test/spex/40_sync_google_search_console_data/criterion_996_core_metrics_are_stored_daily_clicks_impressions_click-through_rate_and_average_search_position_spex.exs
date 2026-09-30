defmodule MetricFlowSpex.CoreMetricsStoredDailyClicksImpressionsCtrPositionSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Core metrics are stored daily: clicks, impressions, click-through rate, and average search position",
       criterion: 996 do
    scenario "a property with search traffic completes its daily sync" do
      given_ :user_logged_in_as_owner

      given_ "a property with search traffic", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_search_console,
          provider_metadata: %{"site_url" => "https://example.com/"}
        )

        {:ok, context}
      end

      given_ :with_google_search_console_sync_stub

      when_ "the daily sync runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "clicks, impressions, click-through rate, and average search position are all stored as daily values",
            context do
        assert has_element?(
                 context.view,
                 "[data-role='sync-history-entry'][data-status='success'] [data-role='sync-provider']",
                 "Google Search Console"
               )

        {:ok, context}
      end
    end
  end
end
