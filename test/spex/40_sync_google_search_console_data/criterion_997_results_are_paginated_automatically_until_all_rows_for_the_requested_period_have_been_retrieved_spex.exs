defmodule MetricFlowSpex.ResultsArePaginatedAutomaticallyUntilAllRowsRetrievedSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Results are paginated automatically until all rows for the requested period have been retrieved",
       criterion: 997 do
    scenario "a sync runs for a property whose period spans more rows than a single API page" do
      given_ :user_logged_in_as_owner

      given_ "a property whose sync period requires more than one page of API results", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_search_console,
          provider_metadata: %{"site_url" => "https://example.com/"}
        )

        {:ok, context}
      end

      given_ :with_google_search_console_sync_stub

      when_ "the sync runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "pagination continues automatically until every row for the period has been retrieved", context do
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
