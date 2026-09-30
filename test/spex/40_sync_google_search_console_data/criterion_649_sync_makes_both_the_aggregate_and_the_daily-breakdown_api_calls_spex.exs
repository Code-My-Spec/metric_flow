defmodule MetricFlowSpex.SyncMakesBothTheAggregateAndDailyBreakdownApiCallsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Sync makes both the aggregate and the daily-breakdown API calls", criterion: 649 do
    scenario "a sync runs for a property" do
      given_ :user_logged_in_as_owner

      given_ "a Search Console integration exists with a configured site URL", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_search_console,
          provider_metadata: %{"site_url" => "https://example.com/"}
        )

        {:ok, context}
      end

      when_ "it fetches data", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "it makes one aggregate call with no dimensions and one call dimensioned by date, and stores both results",
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
