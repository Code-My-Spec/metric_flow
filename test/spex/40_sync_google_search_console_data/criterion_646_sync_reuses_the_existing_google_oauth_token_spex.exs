defmodule MetricFlowSpex.SyncReusesTheExistingGoogleOauthTokenSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Sync reuses the existing Google OAuth token", criterion: 646 do
    scenario "Search Console is synced using a token from an existing GA4 connection" do
      given_ :user_logged_in_as_owner

      given_ "the user already has a Google OAuth token from connecting GA4", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_analytics,
          provider_metadata: %{"property_id" => "properties/123456789"}
        )

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

      then_ "it reuses that same token rather than requiring a separate connection", context do
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
