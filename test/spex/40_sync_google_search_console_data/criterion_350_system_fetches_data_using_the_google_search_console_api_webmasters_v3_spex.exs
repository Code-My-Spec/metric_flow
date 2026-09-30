defmodule MetricFlowSpex.SystemFetchesDataUsingTheGoogleSearchConsoleApiSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "System fetches data via the Search Console API, authenticated via Google OAuth2, reusing the same token as GA4 and Google Ads",
       criterion: 350 do
    scenario "a Search Console integration syncs using the account's existing Google OAuth connection" do
      given_ :user_logged_in_as_owner

      given_ "a Search Console integration exists, connected via the same Google OAuth flow as GA4 and Google Ads",
            context do
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

      then_ "the sync completes successfully without requiring a separate connection or a different token",
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
