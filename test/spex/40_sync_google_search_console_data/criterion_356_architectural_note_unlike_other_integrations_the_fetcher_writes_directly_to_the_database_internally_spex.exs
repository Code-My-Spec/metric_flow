defmodule MetricFlowSpex.ArchitecturalNoteFetcherWritesDirectlySpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Architectural note: the fetcher writes directly to the database rather than through a separate formatter/index layer",
       criterion: 356 do
    scenario "a Search Console sync produces the same observable sync history entry shape as other providers" do
      given_ :user_logged_in_as_owner

      given_ "a Search Console integration exists alongside a Google Analytics integration", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_search_console,
          provider_metadata: %{"site_url" => "https://example.com/"}
        )

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

      then_ "both providers appear as ordinary sync history entries, with no architectural difference visible to the user",
            context do
        assert has_element?(
                 context.view,
                 "[data-role='sync-history-entry'][data-status='success'] [data-role='sync-provider']",
                 "Google Search Console"
               )

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
