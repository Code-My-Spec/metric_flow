defmodule MetricFlowSpex.SyncFetchesOrganicSearchDataViaExistingOauthSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Sync fetches organic search performance data from the Google Search Console API for the configured site, using the account's existing Google OAuth authorization",
       criterion: 994 do
    scenario "a customer already has a Google OAuth connection from Google Ads" do
      given_ :user_logged_in_as_owner

      given_ "the account already has a Google OAuth token from connecting Google Ads", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)

        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_search_console,
          provider_metadata: %{"site_url" => "https://example.com/"}
        )

        {:ok, context}
      end

      when_ "Search Console is synced", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "organic search data is fetched for the configured site using the existing Google connection",
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
