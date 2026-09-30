defmodule MetricFlowSpex.CustomerWithAConfiguredSiteUrlIsSyncedSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Customer with a configured site URL is synced", criterion: 647 do
    scenario "a customer has a site URL configured" do
      given_ :user_logged_in_as_owner

      given_ "a customer has a site URL configured", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_search_console,
          provider_metadata: %{"site_url" => "https://example.com/"}
        )

        {:ok, context}
      end

      when_ "the sync runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "data is fetched for that site", context do
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
